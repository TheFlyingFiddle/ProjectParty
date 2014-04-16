module game.time;

import std.datetime;

struct Time
{
	package static Duration _delta, _total;

	static @property float delta()
	{
		return _delta.fracSec.msecs / 1000.0f;
	}

	static @property float total()
	{
		return _total.seconds + _total.fracSec.msecs / 1000.0f;
	}
}