module content.content;

import std.traits, 
	allocation, 
	collections,
	util.hash,
	std.path,
	content.textureatlas,
	std.algorithm;

private alias RTable = Table!(uint, Handle, SortStrategy.sorted);

struct Handle
{
	private uint hashID;
	private uint typeHash;
	private	void* item;
}

struct ContentHandle(T)
{
	private Handle* handle;
	this(Handle* handle)
	{
		this.handle = handle;
	}

	ref T asset()
	{
		assert(handle.typeHash == cHash!T);
		auto item = cast(T*)(handle.item);
		return *item;
	}

	auto ref opDispatch(string s)()
	{
		assert(handle.typeHash == cHash!T);
		auto item = cast(T*)(handle.item);
		mixin("return item." ~ s ~ ";");
	}

	auto ref opDispatch(string s, Args...)(Args args)
	{
		assert(handle.typeHash == cHash!T);
		auto item = cast(T*)(handle.item);
		mixin("return item." ~ s ~ "(args);");
	}

	static if(hasElaborateDestructor!(T))
		private void obliterate()
		{
			item.__dtor();
			item = null;
			typeHash = uint.max;
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
	Handle[] items;

	this(A)(ref A allocator, IAllocator itemAllocator, 
			size_t maxResources, string resourceFolder)
	{
		items = allocator.allocate!(Handle[])(maxResources);
		items[] = Handle.init;

		this.allocator = itemAllocator;
		this.resourceFolder = resourceFolder;
		
		//We will not have more the 100 file formats.
		this.fileLoaders   = List!(FileLoader)(allocator, 100);
	}

	void addFileLoader(FileLoader fileLoader)
	{
		this.fileLoaders ~= fileLoader;
	}

	private uint indexOf(uint hash)
	{
		auto index = items.countUntil!(x => x.hashID == hash);
		return index;
	}

	private uint addItem(T)(uint hash, T* item)
	{
		return addItem(hash, cHash!T, cast(void*)item);
	}

	private uint addItem(uint hash, uint typeHash, void* item)
	{
		foreach(i, ref handle; items)
		{
			if(handle.item is null) {
				items[i] = Handle(hash, typeHash, item);
				return i;
			}
		}

		assert(0, "Resources full!");
	}

	private ContentHandle!T getItem(T)(uint hash)
	{
		ContentHandle!T handle  = ContentHandle!T(&items[indexOf(hash)]);
		return handle;
	}

	private Handle getItem(string path)
	{
		return items[indexOf(bytesHash(path))];
	}
	
	bool isLoaded(string path)
	{
		return isLoaded(bytesHash(path));
	}

	bool isLoaded(uint hash)
	{
		return indexOf(hash) != -1;
	}

	ContentHandle!(T) load(T)(string path)
	{
		auto hash = bytesHash(path);
		if(isLoaded(path)) 
		{
			auto item = items[indexOf(hash)];
			assert(item.typeHash == cHash!T);
			return getItem!T(hash);
		}

		import util.strings;
		
		auto index = fileLoaders.countUntil!(x => x.typeHash == cHash!T);
		assert(index != -1, "Can't load the type specified!");

		auto loader = fileLoaders[index];
		auto file = text1024(resourceFolder, dirSeparator, hash,  loader.extension);
		T* loaded   = cast(T*)loader.load(allocator, cast(string)file, false);
	
		auto itemIndex = addItem(hash, cHash!T, loaded);
		return ContentHandle!(T)(&items[itemIndex]);
	}


	bool unload(T)(ContentHandle!(T) cHandle)
	{
		auto handle = cHandle.handle;
		if(handle.item is null) return false;
		return unloadItem(handle.hashID);
	}

	private bool unloadItem(uint hash)
	{
		auto index  = indexOf(hash);
		auto item   = items[index];

		auto loader = fileLoaders.find!(x => x.typeHash == item.typeHash)[0];
		loader.unload(allocator, item.item);
		items[index] = Handle.init;

		return true;
	}

	private void change(uint hash, void* item)
	{
		auto handle = items[indexOf(hash)];
		auto fileLoader = fileLoaders.find!(x => x.typeHash == handle.typeHash)[0];
		fileLoader.unload(allocator, handle.item);
		items[indexOf(hash)].item = item;
	}	

	@disable this(this);
}

struct ContentConfig
{
	size_t maxResources;
	string resourceFolder;
}

struct AsyncContentLoader
{
	enum maxNameSize = 25; //Assumes 11bytes for hash and 14bytes for extension

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
	
	ContentHandle!(T) load(T)(string path)
	{
		return loader.load!T(path);
	}

	void unload(T)(ContentHandle!T handle)
	{
		loader.unload(handle);
	}

	void reload(uint hash)
	{
		import util.strings;
		auto index = loader.indexOf(hash);
		if(index != -1)
		{
			auto item       = loader.items[index];
			auto fileLoader = loader.fileLoaders.find!(x => x.typeHash == item.typeHash)[0];

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
		loader.change(hash, item);
	}

	void asyncLoad(T)(string path)
	{
		if(loader.isLoaded(path)) return;

		import std.algorithm, util.strings;
		import concurency.threadpool;
		import concurency.task;

		auto fileLoader = loader.fileLoaders.find!(x => x.typeHash == cHash!T)[0];
		auto buffer = Mallocator.it.allocate!(char[])(loader.resourceFolder.length + maxNameSize);
		auto absPath = text(buffer, loader.resourceFolder, dirSeparator, bytesHash(path), fileLoader.extension);
		
		auto adder = &addAsyncItem!T;
		taskpool.doTask!(asyncLoadFile)(cast(string)absPath, bytesHash(path), fileLoader, adder);			   
		numRequests++;
	}

	void asyncLoad(string path)
	{
		import std.path, util.strings;
		string ext = path.extension;
		uint hash = bytesHash(path[0 .. $ - ext.length]);
		if(loader.isLoaded(hash)) return;


		auto fileLoader = loader.fileLoaders.find!(x => x.extension == ext)[0];
		auto buffer = Mallocator.it.allocate!(char[])(loader.resourceFolder.length + maxNameSize);
		auto absPath = text(buffer, loader.resourceFolder, dirSeparator, hash, ext);
		auto adder = &addAsyncItem!void;
		taskpool.doTask!(asyncLoadFile)(cast(string)absPath, hash, fileLoader, adder);
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
	Mallocator.it.deallocate(cast(void[])path);
}