module content.reloading;

import content.common;
import logging;

auto logChnl = LogChannel("RESOURCE");

struct ReloadHandler
{
	AssetType assetType;
	FileExtention extention;
	void function(const(char)[] path) reload;
}

struct ContentReloader
{
	import collections.list, std.algorithm;
	static List!string loadedResources;
	static List!ReloadHandler reloadFunctions;
	static void delegate(AssetType type, const(char)[] path) onReload;

	static void init(A)(ref A allocator, size_t maxResources, size_t maxLoaders)
	{
		loadedResources = List!string(allocator, maxResources);
		reloadFunctions = List!ReloadHandler(allocator, maxLoaders);
		
		spawn(&listenOnDirectory, thisTid, resourceDir);
	}

	static void shutdown()
	{
		//Not much to do here...
	}

	static void registerReloader(AssetType type, FileExtention[] extentions, void function(const(char)[] path) reload)
	{
		foreach(ext; extentions) 
			registerReloader(type, ext, reload);
	}

	static void registerReloader(AssetType type, FileExtention extention, void function(const(char)[] path) reload)
	{
		reloadFunctions ~= ReloadHandler(type, extention, reload);
	}

	static void registerResource(const(char)[] filePath)
	{
		loadedResources ~= filePath.idup;
	}

	static void unregisterResource(const(char)[] filePath)
	{
		loadedResources.remove!(x => x == filePath);
	}
	
	static void processReloadRequests()
	{
		import std.concurrency, std.datetime;

		bool received = true;
		while(received)
		{
			received = receiveTimeout(0.msecs,
			(FileChangedEvent fileChanged)
			{
				import logging;
				auto logChannel = LogChannel("RELOADING");
				logChannel.info("File Changed", fileChanged.filePath);
				foreach(r; loadedResources) logChannel.info("Loaded: ", r);
				
				if(loadedResources.canFind!(x => x == fileChanged.filePath))
				{
					auto fileExt = getFileExt(fileChanged.filePath);
					if(fileExt == FileExtention.unknown)
					{
						logChnl.warn("File extention for file" ~ fileChanged.filePath ~ " is unkown");
						return;
					}

					auto reloadHandler = reloadFunctions.find!(x => x.extention == fileExt)[0];
					reloadHandler.reload(fileChanged.filePath);

					if(onReload)
						onReload(reloadHandler.assetType, fileChanged.filePath);
				}	
			});
		}
	}

}

enum FileExtention
{
	bmp,
	dds,
	jpg,
	jp2,
	png,
	psd,
	tiff,
	vert,
	frag,
	fnt,
	lua,
	unknown
}

FileExtention getFileExt(string filePath)
{
	import std.path, std.traits;
	auto sExt = filePath.extension()[1 .. $];
	foreach(fileExt; __traits(allMembers, FileExtention))
	{
		if(fileExt == sExt) {
			mixin("return FileExtention." ~ fileExt ~ ";");
		}
	}

	return FileExtention.unknown;
}


struct FileChangedEvent
{
	FileChangeAction action;
	string filePath;
}


version(Windows)
{
	import core.sys.windows.windows;
	import std.concurrency;
	alias extern(Windows) VOID function(DWORD, DWORD, LPVOID) nothrow LPOVERLAPPED_COMPLETION_ROUTINE;
	extern(Windows) export 
	BOOL ReadDirectoryChangesW(
						HANDLE hDirectory,
						LPVOID lpBuffer,
						DWORD nBufferLength,
						BOOL bWatchSubtree,
						DWORD dwNotifyFilter,
						LPDWORD lpBytesReturned,
						OVERLAPPED* lpOverlapped,
						LPOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine);

	struct FILE_NOTIFY_INFORMATION{
		DWORD NextEntryOffset;
		DWORD Action;
		DWORD FileNameLength;
		WCHAR FileName;
	} 
	alias PFILE_NOTIFY_INFORMATION = FILE_NOTIFY_INFORMATION*;

	enum FileChangeAction
	{
		Modified       = FILE_ACTION_MODIFIED,
		Created        = FILE_ACTION_ADDED,
		Deleted        = FILE_ACTION_REMOVED, 
		RenamedOldName = FILE_ACTION_RENAMED_OLD_NAME,
		RenamedNewName = FILE_ACTION_RENAMED_NEW_NAME
	}

	void listenOnDirectory(Tid sendID, string absDirPath)
	{
		import std.string;
		auto cstr = absDirPath.toStringz();
		auto handle = CreateFileA(cstr, FILE_LIST_DIRECTORY,
								  FILE_SHARE_READ  |
								  FILE_SHARE_WRITE |
								  FILE_SHARE_DELETE,
								  null, OPEN_EXISTING,
								  FILE_FLAG_BACKUP_SEMANTICS |
								  FILE_FLAG_OVERLAPPED, null);
		
		ubyte[] buffer = new ubyte[1024];
		uint bytesReturned;

		while(true)
		{
			if(ReadDirectoryChangesW(handle, buffer.ptr, cast(uint)buffer.length, true,
									 FILE_NOTIFY_CHANGE_LAST_WRITE |
									 FILE_NOTIFY_CHANGE_FILE_NAME  |
									 FILE_NOTIFY_CHANGE_CREATION,
									 &bytesReturned, null, null))
			{
				sendChanges(sendID, cast(FILE_NOTIFY_INFORMATION*)buffer.ptr);
			} 
			else 
			{
				import logging;
				auto chan = LogChannel("File Watcher");
				chan.error("ReadDirectoryChangesW failed!");
				assert(0, "Error");
			}
		}
	}

	private void sendChanges(Tid tid, FILE_NOTIFY_INFORMATION* info)
	{
		import std.conv;

		FileChangedEvent event;
		event.action   = cast(FileChangeAction)info.Action;
		event.filePath = (&info.FileName)[0 .. info.FileNameLength / WCHAR.sizeof].to!string;
		
		send(tid, event);

		if(info.NextEntryOffset != 0)
			sendChanges(tid, cast(FILE_NOTIFY_INFORMATION*)(cast(size_t)info + info.NextEntryOffset));
	}
}

struct ResourceTable(Resource, alias obliterator)
{
	import std.algorithm;
	enum noResource = 0x0;

	private Resource[] resources;
	private uint[]     ids;

	this(A)(ref A allocator, size_t capacity)
	{
		this.resources = allocator.allocate!(Resource[])(capacity);
		this.ids       = allocator.allocate!(uint[])(capacity);
		this.ids[]     = noResource;
	}

	uint add(Resource resource, const(char)[] path)
	{	
		auto id = resourceHash(path);

		auto index = ids.countUntil!(x => x == id);
		if(index != -1) return cast(uint)index;

		ContentReloader.registerResource(path);

		index = ids.countUntil!(x => x == noResource);
		assert(index != -1, "Out of space for resources!");

		resources[index] = resource;
		ids[index]       = id;
		return cast(uint)index;
	}

	bool remove(const(char)[] path)
	{
		auto id = resourceHash(path);
		auto index = ids.countUntil!(x => x == id);	
		if(index == -1) 
		{
			logChnl.warn("Trying to unload a resource that is not loaded! " ~ path);
			return false;
		}

		ContentReloader.unregisterResource(path);
		obliterator(resources[index]);
		resources[index] = Resource.init;
		ids[index]		 = noResource;
		return true;
	}

	uint replace(Resource resource, const(char)[] path)
	{
		auto id    = resourceHash(path);
		auto index = ids.countUntil!(x => x == id);
		if(index == -1) {
			return cast(uint)index;
		}

		obliterator(resources[index]);
		resources[index] = resource;
		return cast(uint)index;
	}

	uint indexOf(const(char)[] path)
	{
		auto id = resourceHash(path);
		return cast(uint)ids.countUntil!(x => x == id);
	}

	ref Resource opIndex(uint index)
	{
		return resources[index];
	}

	int opApply(int delegate(ref Resource resource) dg)
	{
		int result;
		foreach(i, ref r; resources)
		{
			if(ids[i] == noResource)
				continue;

			result = dg(r);
			if(result) break;
		}

		return result;
	}

	private static uint resourceHash(const(char)[] path)
	{
		import util.hash, std.path;
		auto name = baseName(stripExtension(path));
		uint hash = bytesHash(name.ptr, name.length);
		return hash;
	}
}