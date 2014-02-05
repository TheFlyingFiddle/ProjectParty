module logging;

public import logging.tcp;

enum Verbosity { info, warn, error }

alias logger_t = void function(string, Verbosity, const(char)[], string, size_t) nothrow;
logger_t logger = &voidLogger;

void voidLogger(string, Verbosity, const(char)[], string, size_t) nothrow { }


mixin template Make(string channel)
{
	static string m()
	{
		string s;
		foreach(name; __traits(allMembers, Verbosity))
		{
			s ~= "
				void " ~ name~ "(string file = __FILE__, size_t line = __LINE__,  T...)(T t) nothrow
				{
				makeMsg!(T)(" ~ channel ~ ", Verbosity." ~ name ~ ", file, line, t);
				}

				void " ~ name ~ "f(string file = __FILE__, size_t line = __LINE__, T...)(string f, T...) nothrow 
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

	nothrow this(string name)
	{ 
		this.name = name; 
	}
}

private void makeMsg(T...)(string channel, Verbosity verbosity, string file, size_t line,  T t) nothrow
{
	template staticFormatString(size_t u)
	{
		static if(u == 1) enum staticFormatString = "%s";
		else enum staticFormatString = staticFormatString!(u - 1) ~ "%s";
	}
	
	import std.format, collections.list;
	scope(failure) return;

	//char[1024] buffer = void;
	//auto list = List!(char)(buffer);
	//auto appender = &list;
	//
	//formattedWrite(appender, staticFormatString!(T.length), t);
	//logger(channel, verbosity, appender.array, file, line);
}

private void makeFormatMsg(T...)(string channel, string f, Verbosity verbosity, const(char)[] file, size_t line, T t) nothrow
{
	import std.format, collections.list;
	scope(failure) return; //We were unable to log what to do?

	import std.array;
	//char[1024] buffer = void;
	//auto list = List!(char)(buffer);
	//auto appender = &list;
	//formattedWrite(appender, f, t);
	//
	//logger(channel, verbosity, appender.array, file, line);
}
