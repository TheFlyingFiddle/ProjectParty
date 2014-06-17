module content.content;

import std.traits, 
	allocation, 
	collections,
	util.hash,
	std.path,
	content.textureatlas,
	std.algorithm;

alias RTable = Table!(uint, UntypedHandle, SortStrategy.sorted);
struct UntypedHandle
{
	private uint hash;
	private	void* item;
}

struct ContentHandle(T)
{
	private uint hash;
	private T* item;

	ref T asset()
	{
		return *item;
	}

	auto ref opDispatch(string s)()
	{
		assert(hash != uint.max);
		mixin("return item." ~ s ~ ";");
	}

	auto ref opDispatch(string s, Args...)(Args args)
	{
		assert(hash != uint.max);
		mixin("return item." ~ s ~ "(args);");
	}

	static if(hasElaborateDestructor!(T))
		private void obliterate()
		{
			item.__dtor();
			item = null;
			hash = uint.max;
		}
}

struct FileLoader
{
	uint typeHash;
	string extension;

	void* function(IAllocator, string, bool) load; 
	void  function(IAllocator, void*) unload;
}

FileLoader makeLoader(Loader, string ext)()
{
	import std.traits;
	alias T = ReturnType!(Loader.load);
	alias BaseT = typeof(*T);
	static assert(is(ParameterTypeTuple!(Loader.unload)[1] == T), "Wrong item type for unloader!");

	FileLoader loader;
	loader.typeHash  = cHash!BaseT;
	loader.extension = ext;
	loader.load		 = (aloc, path, async) => cast(void*)Loader.load(aloc, path, async);
	loader.unload	 = (aloc, item) => Loader.unload(aloc, cast(T)item);
	return loader;
}

struct ContentLoader
{
	List!FileLoader fileLoaders;
	IAllocator allocator;
	string resourceFolder;
	RTable items;

	this(A)(ref A allocator, IAllocator itemAllocator, 
			size_t maxResources, string resourceFolder)
	{
		items = RTable(allocator, maxResources);
		this.allocator = itemAllocator;
		this.resourceFolder = resourceFolder;
		
		//We will not have more the 100 file formats.
		this.fileLoaders   = List!(FileLoader)(allocator, 100);
	}

	void addFileLoader(FileLoader fileLoader)
	{
		this.fileLoaders ~= fileLoader;
	}

	private void addItem(T)(uint hash, T* item)
	{
		items[hash] = UntypedHandle(cHash!T, item);
	}

	private void addItem(uint hash, uint typeHash, void* item)
	{
		items[hash] = UntypedHandle(typeHash, item);
	}

	private ContentHandle!T getItem(T)(uint hash)
	{
		return cast(ContentHandle!T )items[hash];
	}

	private UntypedHandle getItem(string path)
	{
		return items[bytesHash(path)];
	}
	
	bool isLoaded(string path)
	{
		auto hash = bytesHash(path);
		auto item = hash in items;
		return item !is null;
	}

	ContentHandle!(T) loadItem(T)(string path)
	{
		auto hash = bytesHash(path);
		auto item = hash in items;
		if(item) 
		{
			//TypeChecking yay
			assert(item.hash == cHash!T);
			return cast(ContentHandle!T)*item;
		}

		import util.strings;
		
		auto index = fileLoaders.countUntil!(x => x.typeHash == cHash!T);
		assert(index != -1, "Can't load the type specified!");

		auto loader = fileLoaders[index];
		auto file = text1024(resourceFolder, dirSeparator, hash,  loader.extension);
		T* loaded   = cast(T*)loader.load(allocator, cast(string)file, false);

		items[hash] = UntypedHandle(cHash!T, loaded);
		return ContentHandle!(T)(cHash!T, loaded);
	}

	bool unloadItem(T)(ContentHandle!(T) handle)
	{
		foreach(key, value; items)
		{
			if(value.item is handle.item)
			{
				auto index = fileLoaders.countUntil!(x => x.typeHash == cHash!T);
				auto loader = fileLoaders[index];
				loader.unload(allocator, cast(void*)handle.item);
				items.remove(key);
				return true;
			}
		}

		return false;
	}

	private bool unloadItem(uint hash)
	{
		auto item   = items[hash];
		auto loader = fileLoaders.find!(x => x.typeHash == item.hash)[0];
		loader.unload(allocator, item.item);
		return true;
	}

	@disable this(this);
}

template untype(alias fun)
{
	void untype(void* item)
	{
		alias type = ParameterTypeTuple!fun[0];
		fun(cast(type)item);
	}
}

struct ContentConfig
{
	size_t maxResources;
	string resourceFolder;
}

struct AsyncContentLoader
{
	import concurency.task;

	private ContentLoader loader;
	private int numRequests;	

	this(A)(ref A allocator, ContentConfig config)
	{
		this(allocator, config.maxResources, config.resourceFolder);
	}

	this(A)(ref A allocator, size_t numResources, string resourceFolder)
	{
		import content : createStandardLoader;
		loader = createStandardLoader(allocator, Mallocator.cit, numResources, resourceFolder);
		numRequests = 0;
	}
	
	ContentHandle!(T) loadItem(T)(string path)
	{
		return loader.loadItem(path);
	}

	void unloadItem(T)(ContentHandle!T handle)
	{
		loader.unloadItem(handle);
	}

	void reload(uint hash)
	{
		import util.strings;
		auto item = hash in loader.items;
		if(item)
		{
			import std.stdio;
			writeln(hash);
			writeln(item.hash);
			writeln(loader.fileLoaders);

			auto fileLoader = loader.fileLoaders.find!(x => x.typeHash == item.hash)[0];

			enum maxNameSize = 25; //Assumes 11bytes for hash and 14bytes for extension

			auto buffer = Mallocator.it.allocate!(char[])(loader.resourceFolder.length + maxNameSize);
			auto absPath = text(buffer, loader.resourceFolder, dirSeparator, hash, fileLoader.extension);

			taskpool.doTask!(asyncLoadFile)(cast(string)absPath, hash, fileLoader, &addReloadedAsyncFile);
			numRequests++;
		}
	}


	private void addReloadedAsyncFile(uint hash, void* item)
	{
		numRequests--;
		auto storedType = loader.items[hash].hash;
		
		loader.unloadItem(hash);
		loader.addItem(hash, storedType, item);
	}

	void asyncLoadItem(T)(string path)
	{
		import std.algorithm, util.strings;
		auto fileLoader = loader.fileLoaders.find!(x => x.typeHash == cHash!T)[0];
		import concurency.threadpool;

		enum maxNameSize = 25; //Assumes 11bytes for hash and 14bytes for extension

		auto buffer = Mallocator.it.allocate!(char[])(loader.resourceFolder.length + maxNameSize);
		auto absPath = text(buffer, loader.resourceFolder,
						 dirSeparator, bytesHash(path), fileLoader.extension);

		
		import concurency.task;
		auto adder = &addAsyncItem!T;
		taskpool.doTask!(asyncLoadFile)(cast(string)absPath, bytesHash(path), fileLoader, adder);			   
		numRequests++;
	}

	private void addAsyncItem(T)(uint hash, void* item)
	{
		numRequests--;
		loader.addItem(hash, cast(T*)item);
	}

	bool isLoaded(string path)
	{
		return loader.isLoaded(path);
	}	

	bool areAllLoaded()
	{
		return numRequests == 0;
	}

	ContentHandle!T item(T)(string path)
	{
		return loader.getItem!T(bytesHash(path));
	}
}

void asyncLoadFile(string path, uint hash, FileLoader loader, void delegate(uint, void*) adder) 
{
	import concurency.task;
	auto item = loader.load(Mallocator.cit, path, true);
	auto t = task(adder, hash, item);
	doTaskOnMain(t);
}