module spacial.shape;

import math.vector, math.matrix;

struct Ray
{
	float2 origin;
	float2 direction;
}

struct Line
{
	float2 start, end;
}

struct Polygon
{
	float2[] points;
}


enum Orientation2D
{
	clockWize,
	counterClockWize,
	colinear	
}

struct Triangle
{
	float2 a, b, c;

	float orientation()
	{
		float u1 = a.x - c.x;
		float u2 = a.y - c.y;
		float v1 = b.x - c.x;
		float v2 = b.y - c.y;
		return u1 * v2 - u2 * v1;
	}

	float incircle(float2 d)
	{
		Matrix3 matr;
		float* mat = cast(float*)&matr;

		float adx = a.x - d.x,
			  ady = a.y - d.y,
			  bdx = b.x - d.x,
			  bdy = b.y - d.y,
			  cdx = c.x - d.x,
			  cdy = c.y - d.y;

		mat[0] = adx; mat[3] = ady; mat[6] = (adx * adx) + (ady * ady);
		mat[1] = bdx; mat[4] = bdy; mat[7] = (bdx * bdx) + (bdy * bdy);
		mat[2] = cdx; mat[5] = cdy; mat[8] = (cdx * cdx) + (cdy * cdy);

		return matr.determinant();
	}

	float area()
	{
		return (a.x - b.x) * (b.y - c.y) - (b.x - c.x) * (a.y - b.y);
	}

	bool pointInTriangle(float2 p)
	{
		float area2 =  1 / (this.area * 2);
		float s     = area2 * (a.y * c.x - a.x * c.y + (c.y - a.y) * p.x + (a.x - c.x) * p.y);
		float t		= area2 * (a.x * b.y - a.y * b.x + (a.y - b.y) * p.x + (b.x - a.x) * p.y);

		return s > 0 && t > 0 && 1 - s - t > 0;
	}
}

struct NGon(size_t N)
{
	float2 origin;
	float radius;
}

alias Circle  = NGon!50;
alias Hexagon = NGon!6; 
