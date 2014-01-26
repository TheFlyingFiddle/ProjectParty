module content.reloading;

import content;

struct ReloadHandler
{
	FileExtention extention;
	void function(string path) reload;
}

struct ContentReloader
{
	import collections.list, std.algorithm;
	static List!string loadedResources;
	static List!ReloadHandler reloadFunctions;

	static void init(A)(ref A allocator, size_t maxResources, size_t maxLoaders)
	{
		loadedResources = List!string(allocator, maxResources);
		reloadFunctions = List!ReloadHandler(allocator, maxLoaders);
		
		spawn(&listenOnDirectory, thisTid, resourceDir);
	}


	static void registerReloader(FileExtention[] extentions, void function(string path) reload)
	{
		foreach(ext; extentions) 
			registerReloader(ext, reload);
	}

	static void registerReloader(FileExtention extention, void function(string path) reload)
	{
		reloadFunctions ~= ReloadHandler(extention, reload);
	}
	
	static void registerResource(string filePath)
	{
		loadedResources ~= filePath;
	}

	static void unregisterResource(string filePath)
	{
		loadedResources.remove(filePath);
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
				if(loadedResources.canFind!(x => x == fileChanged.filePath))
				{
					auto fileExt = getFileExt(fileChanged.filePath);
					if(fileExt == FileExtention.unknown)
					{
						import logging;
						warn("File extention for file" ~ fileChanged.filePath ~ " is unkown");
						return;
					}

					auto reloadHandler = reloadFunctions.find!(x => x.extention == fileExt)[0];
					reloadHandler.reload(fileChanged.filePath);
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
			if(ReadDirectoryChangesW(handle, buffer.ptr, buffer.length, true,
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