module binpacking;

import std.algorithm;
import std.math;
import log;


struct RectSize
{
	int width;
	int height;
};

struct Rect
{
	int x;
	int y;
	int width;
	int height;
};

bool IsContainedIn(ref Rect a, ref Rect b)
{
	return a.x >= b.x && a.y >= b.y 
		&& a.x+a.width <= b.x+b.width 
		&& a.y+a.height <= b.y+b.height;
}


enum FreeRectChoiceHeuristic
{
	RectBestShortSideFit, ///< -BSSF: Positions the rectangle against the short side of a free rectangle into which it fits the best.
	RectBestLongSideFit, ///< -BLSF: Positions the rectangle against the long side of a free rectangle into which it fits the best.
	RectBestAreaFit, ///< -BAF: Positions the rectangle into the smallest free rect into which it fits.
	RectBottomLeftRule, ///< -BL: Does the Tetris placement.
	RectContactPointRule ///< -CP: Choosest the placement where the rectangle touches other rects as much as possible.
};


/** MaxRectsBinPack implements the MAXRECTS data structure and different bin packing algorithms that 
use this structure. */
struct MaxRectsBinPack
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

	Rect Insert(int width, int height, FreeRectChoiceHeuristic method)
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