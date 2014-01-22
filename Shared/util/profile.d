module util.profile;

import std.datetime;
import logging;

auto chan = LogChannel("PROFILE");

struct StackProfile
{
	StopWatch sw;
	string s;
	this(string s)
	{
		this.s = s;
		sw.start();
	}

	~this()
	{
		sw.stop();
		chan.info("Running time for ", s, "was ", sw.peek.msecs);
	}
}