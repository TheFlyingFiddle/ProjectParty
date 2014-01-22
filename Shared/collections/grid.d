module collections.grid;

import math.vector : uint2;

struct Grid(T)
{
	T* buffer;
	uint height, width;

	this(Allocator)(ref Allocator allocator, uint width, uint height)
	{
		this.buffer = allocator.allocate!(T[])(height * width).ptr;
		this.width  = width;
		this.height = height;
	}

	ref T opIndex(uint2 cell)
	{
		assert(cell.x < width && cell.y < height);
		return buffer[cell.y * width + cell.x];
	}

	int opApply(int delegate(ref T) dg)
	{
		int result;
		foreach(i; 0 .. width * height)
		{
			result = dg(buffer[i]);
			if(result) break;
		}
		return result;
	}

	int opApply(int delegate(uint2, ref T) dg)
	{
		int result;
		foreach(row; 0 .. height)
		{
			foreach(column; 0 .. width)
			{
				result = dg(uint2(column, row), buffer[row * width + column]);
				if(result) break;
			}
		}

		return result;
	}

	void fill(T value)
	{
		buffer[0 .. width * height] = value;
	}


	@disable this(this);
}