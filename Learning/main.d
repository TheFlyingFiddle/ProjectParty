import std.stdio;
import std.socket;

import std.conv, std.socket, std.stdio;
import std.datetime;
import lobby;
import core.thread;
import allocation;
import logging;


void writeLogger(string chan, Verbosity v, string msg, string file, size_t line) nothrow
{

	import std.stdio;
	scope(failure) return; //Needed since writeln can potentially throw.
	//writeln(chan, "   ", msg, "       ", file, "(", line, ")");
}


int main()
{
	logger = &writeLogger;

	Lobby lobby = Lobby(GCAllocator.it, 100, 1337);

	while(true)
	{
		Thread.sleep(16.msecs);
		lobby.update();
	}
	return 0;
}
