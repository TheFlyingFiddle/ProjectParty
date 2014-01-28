module logging;

public import logging.tcp;

enum Verbosity { info, warn, error }

alias logger_t = void function(string, Verbosity, string, string, size_t) nothrow;
logger_t logger = &voidLogger;

void voidLogger(string, Verbosity, string, string, size_t) nothrow { }


mixin template Make(string channel)
{
	static string m()
	{
		string s;
		foreach(name; __traits(allMembers, Verbosity))
		{
			s ~= "
				void " ~ name~ "(string file = __FILE__, size_t line = __LINE__,  T...)(T t) 
				{
				makeMsg!(T)(" ~ channel ~ ", Verbosity." ~ name ~ ", file, line, t);
				}

				void " ~ name ~ "f(string file = __FILE__, size_t line = __LINE__, T...)(string f, T...)
				{
				makeFormatMsg!(T)(" ~ channel ~ ", f, Verbosity." ~ name ~ ", file, line, t);
				}";
		}
		return s;
	}

	mixin(m());
}

struct LogChannel
{
	string name;
	mixin Make!("name");

	this(string name) { this.name = name; }
	this(LogChannel base, string name)
	{
		this.name = base.name ~ "." ~ name;
	}
}

private void makeMsg(T...)(string channel, Verbosity verbosity, string file, size_t line,  T t)
{
	import std.conv;
	string msg = text(t); //Note to self improve this to use an allocator instead.
	logger(channel, verbosity, msg, file, line);
}

private void makeFormatMsg(T...)(string channel, string f, Verbosity verbosity, string file, size_t line, T t)
{
	import std.format;
	auto appender = std.array.Appender!string;
	formattedWrite(appender, f, t);
	logger(channel, verbosity, appender.data, file, line);
}
