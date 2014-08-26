module util.exception;

bool tryParse(T)(const(char)[] input, ref T t)
{
	import std.conv;
	try
	{
		t = input.to!T;
		return true;
	}	
	catch
	{
		return false;
	}
}