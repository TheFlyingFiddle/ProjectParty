module async_content_loading;
import concurency.threadpool; //There is a global threadpool.
import collections.list;

struct LoadFile
{
	char[] filePath;
}

struct FileLoaded
{
	char[] filePath;
	void[] data;
}

void loadFileAsync(Queue)(Queue* queue, const(char)[] path)
{
	queue.send(LoadFile(cast(char[])path));		
}

void handleLoadFile(LoadFile loadFile, Outbox* outbox)
{
	import std.stdio, allocation;

	FileLoaded fileLoaded;
	auto file = File(cast(string)loadFile.filePath);
	auto buffer = cast(ubyte[])Mallocator.it.allocateRaw(cast(uint)file.size, 8);
	assert(file.rawRead(buffer).length == buffer.length);

	outbox.send(FileLoaded(loadFile.filePath, buffer));
}

void threadpoolFunc(Inbox* inbox, Outbox* outbox)
{
	inbox.receive(
	(LoadFile file)
	{
		writeln("Weee");
		handleLoadFile(file, outbox);
	});
}

import allocation, std.stdio;
struct Store
{
	struct Item
	{	
		char[] file;
		void[] data;
	}

	List!Item items; 

	this(A)(ref A allocator, size_t size)
	{
		items = List!Item(allocator, size);
	}

	void addItem(char[] file, void[] data)
	{
		items ~= Item(file, data);
	}
	
	bool isLoaded(const(char)[] file)
	{
		import std.algorithm;
		auto index = items.countUntil!(x => x.file == file);
		return index != -1;
	}

	void[] getData(const(char)[] file)
	{	
		import std.algorithm;
		auto index = items.countUntil!(x => x.file == file);
		return items[index].data;
	}
}

unittest
{
	auto storage = Store(Mallocator.it, 10);
	auto pool = ThreadPool(Mallocator.it, 4, 1024, 1024, 1024, &threadpoolFunc);
	pool.start();


	void writeFile(FileLoaded file)
	{
		storage.addItem(file.filePath, file.data);
	}

	void fetchResultsFromWorkers()
	{
		pool.outbox.receive(&writeFile);
	}

	bool processFrame()
	{
		if(storage.isLoaded("Game.sdl"))
		{
			auto data = storage.getData("Game.sdl");
			writeln(cast(char[])data);
			return true;
		} 
		else 
		{
			writeln("Waiting for file to load: Game.sdl");
			return false;
		}
	}

	writeln("Send file load message");
	loadFileAsync(pool.inbox, "Game.sdl");
		
	while(true) 
	{
		fetchResultsFromWorkers();
		if(processFrame()) break;
	}

	writeln("We are done!");
	pool.stop();
}

struct LoadRepoFile
{
	char[] file;
	int id;
}

struct RepoFileLoaded
{
	int id;
	void[] data;
}

unittest
{
	import std.stdio;
	auto pool = ThreadPool(Mallocator.it, 4, 1024, 1024, 1024, &threadpoolFunc2);
	pool.start();

	Repo repo = Repo(Mallocator.it, &pool);

	repo.loadAsync("Game.sdl");
	while(!repo.areAllLoaded()) 
	{
		fetchAllResults(&pool, &repo);
		writeln("So bored this guy sucks");
	}

	writeln("Writing file");
	writeln(cast(char[])repo.items[0].data);
}

struct Repo
{
	private int numRequests;
	private List!(Item) items;
	private int requests;
	private ThreadPool* pool;

	struct Item 
	{ 
		int id;
		void[] data;
	}

	this(A)(ref A allocator, ThreadPool* pool)
	{
		this.numRequests = this.requests = 0;
		this.items = List!Item(allocator, 10);
		this.pool = pool;
	}

	void asyncDone(int id, void[] data)
	{
		items ~= Item(id, data);
		numRequests--;
	}
		
	int loadAsync(string file)
	{
		pool.send(LoadRepoFile(cast(char[])file, requests));	
		numRequests++;
		return requests++;
	}

	void load(string file)
	{
		//Load the stuff with the things.
	}

	bool isLoaded(int id)
	{
		import std.algorithm;
		auto index = items.countUntil!(x => x.id == id);
		return index != -1;
	}

	bool areAllLoaded()
	{
		return numRequests == 0;
	}
}

struct AsyncAction(S, R, alias action)
{
	int numRequests = 0;

	void asyncDo(S s)
	{
		numRequests++;
		pool.inbox.send(s);
	}

	R do_(S s)
	{
		return action(s);
	}

	void poolProcessor(S s)
	{
		R r = action(s);
		pool.outbox.send(r);
	}

	void fetcher(R r)
	{
		numRequests--;
	}

	bool isAllActions()
	{
		return numRequests == 0;
	}
}

TPFunc constructTPFunc(AsyncStuff...)(AsyncStuff stuff)
{
	
}

RFunc constructRFunc(AsyncStuff...)()
{

}

void threadpoolFunc2(Inbox* inbox, Outbox* outbox)
{
	inbox.receive(
				  (LoadRepoFile file)
				  {
					  handleLoadRepoFile(file, outbox);
				  });
}

void handleLoadRepoFile(LoadRepoFile loadFile, Outbox* outbox)
{
	import std.stdio, allocation;

	FileLoaded fileLoaded;
	auto file = File(cast(string)loadFile.file);
	auto buffer = cast(ubyte[])Mallocator.it.allocateRaw(cast(uint)file.size, 8);
	assert(file.rawRead(buffer).length == buffer.length);

	outbox.send(RepoFileLoaded(loadFile.id, buffer));
}

void fetchAllResults(ThreadPool* pool, Repo* repo)
{
	pool.outbox.receive((RepoFileLoaded loaded)
	{
		repo.asyncDone(loaded.id, loaded.data);
	});
}