module log;

public import log.remote;

enum Verbosity { info = 0, warn = 1, error = 2 }

alias logger_t = void function(string, Verbosity, const(char)[]) nothrow;
__gshared logger_t logger = &writelnLogger;

void writelnLogger(string channel, Verbosity verbosity, const(char)[] msg) nothrow 
{
	try
	{
		import std.stdio;
		writeln(channel, " ", msg);
	}
	catch(Error e)
	{
		throw e;
	}
	catch { }
}

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

void logCondInfo(string file = __FILE__, size_t line = __LINE__, T...)(bool cond, T t) if(T.length > 0)
{
	if(cond)
		logInfo!(file, line, T)(t);
}

void logCondWarn(string file = __FILE__, size_t line = __LINE__, T...)(bool cond, T t) if(T.length > 0)
{
	if(cond)
		logWarn!(file, line, T)(t);
}


void logCondErr(string file = __FILE__, size_t line = __LINE__, T...)(bool cond, T t) if(T.length > 0)
{
	if(cond)
		logErr!(file, line, T)(t);
}

void logInfo(string file = __FILE__, size_t line = __LINE__, T...)(T t) if(T.length > 0)
{
	makeMsg("Default", Verbosity.info, file, line, t);
}

void logWarn(string file = __FILE__, size_t line = __LINE__,T...)(T t) if(T.length > 0)
{
	makeMsg("Default", Verbosity.warn, file, line, t);
}

void logErr(string file = __FILE__, size_t line = __LINE__,T...)(T t) if(T.length > 0)
{
	makeMsg("Default", Verbosity.error, file,line, t);
}

private void makeMsg(T...)(string channel, Verbosity verbosity, string file, size_t line,  T t) nothrow
{
	template staticFormatString(size_t u)
	{
		static if(u == 1) enum staticFormatString = "%s\t%s(%s)";

		else enum staticFormatString = "%s" ~ staticFormatString!(u - 1) ;
	}

	import std.format, collections.list;
	scope(failure) return;



	char[8192] buffer = void;
	auto list = List!(char)(buffer);
	auto appender = &list;

	formattedWrite(appender, staticFormatString!(T.length), t, file, line);
	logger(channel, verbosity, appender.array);
}

private void makeFormatMsg(T...)(string channel, string f, Verbosity verbosity, const(char)[] file, size_t line, T t) nothrow
{
	import std.format, collections.list;
	scope(failure) return; //We were unable to log what to do?

	import std.array;
	char[8192] buffer = void;
	auto list = List!(char)(buffer);
	auto appender = &list;
	formattedWrite(appender, f, t);
	formattedWrite(appender, "\t%s(%s)", file, line);

	logger(channel, verbosity, appender.array);
}
