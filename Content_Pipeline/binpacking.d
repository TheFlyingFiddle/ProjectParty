module binpacking;

import std.algorithm;
import std.math;
import log;

struct Rect
{
	int x;
	int y;
	int width;
	int height;
};


struct RectPacker
{
	int binWidth;
	int binHeight;

	int y, x, lineH;

	this(int width, int height)
	{
		Init(width, height);
	}

	void Init(int width, int height)
	{
		binWidth = width;
		binHeight = height;
	}

	Rect Insert(int width, int height)
	{
		Rect newNode;

		if(height > lineH)
			lineH = height;
		
		if(x + width >= binWidth)
		{
			x = 0;
			y += lineH;
			lineH = 0;
		}

		if(y + height >= binWidth) 
		{
			return Rect.init;
		}	

		newNode = Rect(x, y, width, height);
		x += width;

		return newNode;
	}
}