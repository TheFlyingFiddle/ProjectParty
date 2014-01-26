module util.file_watcher;

import core.sys.windows.windows;
import std.string;
import std.stdio;
import std.c.string;
import std.concurrency;

alias extern(Windows) VOID function(DWORD, DWORD, LPVOID) nothrow LPOVERLAPPED_COMPLETION_ROUTINE;

extern(Windows) export BOOL ReadDirectoryChangesW(
												  HANDLE hDirectory,
												  LPVOID lpBuffer,
												  DWORD nBufferLength,
												  BOOL bWatchSubtree,
												  DWORD dwNotifyFilter,
												  LPDWORD lpBytesReturned,
												  OVERLAPPED* lpOverlapped,
												  LPOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine
												  );

struct FILE_NOTIFY_INFORMATION{
	DWORD NextEntryOffset;
	DWORD Action;
	DWORD FileNameLength;
	WCHAR FileName;
} 
alias PFILE_NOTIFY_INFORMATION = FILE_NOTIFY_INFORMATION*;

extern(Windows) VOID notificationCompletion(DWORD a, DWORD b, LPVOID buf) nothrow
{
	scope(failure) return;
	writeln("Called");
}

void listenOnDir(Tid id, string dir)
{
	auto cstr = dir.toStringz;
	HANDLE handle = CreateFileA(cstr, FILE_LIST_DIRECTORY, 
								FILE_SHARE_READ | FILE_SHARE_DELETE | FILE_SHARE_WRITE,
								null, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OVERLAPPED, null);
	ubyte[] buf = new ubyte[1024];
	uint bytesReturned;
	OVERLAPPED over;
	while(true) {
		ReadDirectoryChangesW(handle, buf.ptr, buf.length, true, 
							  FILE_NOTIFY_CHANGE_LAST_WRITE
				| FILE_NOTIFY_CHANGE_FILE_NAME
				| FILE_NOTIFY_CHANGE_CREATION,
							  &bytesReturned, null, 
							  &notificationCompletion);
		ubyte[] buffer = new ubyte[bytesReturned];
		foreach(i;0..bytesReturned) {
			buffer[i] = buf[i];
		}

		send(id, cast(shared(void)*)buffer.ptr);
	}
}