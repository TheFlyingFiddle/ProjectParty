module filewatcher;

version(Windows)
{
	import core.sys.windows.windows;
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

	struct FileWatcher
	{
		private HANDLE handle;
		this(string directory)
		{
			import std.string;
			auto c_dir = directory.toStringz();
			handle = CreateFileA(c_dir, FILE_LIST_DIRECTORY,
								 FILE_SHARE_READ  |
								 FILE_SHARE_WRITE |
								 FILE_SHARE_DELETE,
								 null, OPEN_EXISTING,
								 FILE_FLAG_BACKUP_SEMANTICS |
								 FILE_FLAG_OVERLAPPED, null);
		}

		void waitForFileChanges()
		{
			ubyte[1024] buffer;
			uint bytesReturned;
			if(ReadDirectoryChangesW(handle, buffer.ptr, 1024, true,
								     FILE_NOTIFY_CHANGE_LAST_WRITE | 
									 FILE_NOTIFY_CHANGE_SIZE	   | 
									 FILE_NOTIFY_CHANGE_ATTRIBUTES |
									 FILE_NOTIFY_CHANGE_FILE_NAME  |
									 FILE_NOTIFY_CHANGE_CREATION,
									 &bytesReturned, null, null))
		    {
				return;
			}
			else 
			{
				import std.exception;
				enforce(false, "Something went wrong while listening to directory!");
			}
		}
	}
} else {

	struct FileWatcher
	{
		this(string directory) { }
		void waitForFileChanges()
		{
			import core.thread;
			Thread.sleep(5.seconds);
		}
	}
}

