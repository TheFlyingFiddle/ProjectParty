module util.strings;

import util.hash;
import std.conv;
import std.exception;


static char[] c_buffer;

static this()
{
	import std.c.stdlib;
	c_buffer = (cast(char*)malloc(1024))[0 .. 1024];
}

char* toCString(const char[] str) 
{
	c_buffer[0 .. str.length] = str[];
	c_buffer[str.length] = '\0';
	return c_buffer.ptr;
}

const (char)[] text(Args...)(char[] buffer, Args args) 
{
	import std.format, collections.list;
	template staticFormatString(size_t u)
	{
		static if(u == 1) enum staticFormatString = "%s";
		else enum staticFormatString = staticFormatString!(u - 1) ~ "%s";
	}

	auto appender = List!(char)(buffer);
	formattedWrite(&appender, staticFormatString!(Args.length), args);

	return appender.array;
}

const (char)[] text1024(Args...)(Args args)
{
	return text(c_buffer, args);
}

const (char)[] format(Args...)(char[] buffer, string s, Args args) 
{
	import std.format, collections.list;

	List!char appender = List!char(buffer);
	formattedWrite(&appender, s, args);

	return appender.array;
}