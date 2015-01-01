module collision;

import math.vector;

alias Polygon = float2[];


float2 farthestPointInDir(Polygon p, float2 d)
{
	float max_     = -float.max;
	int	  vertIdx  = 0;
	foreach(i;  0 .. p.length)
	{
		float prod = dot(p[i], d);
		if(max_ < prod) 
		{
			max_ = prod;
			vertIdx = i;
		}
	}
	return p[vertIdx];
}

float2 trippleDot(float2 a, float2 b, float2 c)
{
	return b * c.dot(a) - a * c.dot(b); 
}


unittest
{
	Polygon a = [ float2(4, 5), float2(9,9), float2(4, 11) ];
	Polygon b = [ float2(7, 3), float2(10, 2), float2(12, 7), float2(5, 7) ];

	auto dir = float2(1, 0);

	import std.stdio;
	writeln("Result: ", support(a, b, dir));
	writeln("Result: ", support(a, b, -dir));
	writeln("Result: ", support(a, b, float2(0, 1)));
	
	Simplex s;
	writeln("Result GJK: ", gjk(a, b, s));
	writeln("Result GJK Simplex: ", s);

	float2 norm;
	float  pen;
	writeln("Result EPK: ", epa(a, b, norm, pen));
	writeln("Result EPK Norm: ", norm);
	writeln("Result EPK Pen: ", pen);

	import physics_engine;

	writeln("CC: ", );

	int dummy;

}

float2 support(Polygon a, Polygon b, float2 d)
{
	float2 p1 = a.farthestPointInDir(d);
	float2 p2 = b.farthestPointInDir(-d);

	return p1 - p2;
}

bool containsOrigin(ref Simplex simplex, ref float2 d,)
{
	float2 a  = simplex.a;
	float2 ao = -a;

	if(simplex.length == 3)
	{
		float2 b = simplex.b;
		float2 c = simplex.c;

		float2 ab = b - a;
		float2 ac = c - a;

		float2 abPerp = trippleDot(ac, ab, ab);
		float2 acPerp = trippleDot(ab, ac, ac);

		if(abPerp.dot(ao) > 0)
		{
			simplex.removeC();
			d = abPerp;
		}
		else if(acPerp.dot(ao) > 0)
		{
			simplex.removeB();
			d = acPerp;
		}
		else 
		{
			return true;
		}
	}
	else 
	{
		float2 b = simplex.b;
		float2 ab = b - a;
		float2 abPerp = trippleDot(ab, ao, ab);

		d = abPerp;
	}

	return false;
}

struct Simplex
{
	float2[3] data;
	int		  length;

	float2 a() { return data[length - 1]; }
	float2 b() { return data[length - 2]; }
	float2 c() { return data[length - 3]; }
	
	void add(float2 v)
	{
		assert(length <= 2);
		data[length++] = v;
	}

	void removeB()
	{
		import std.algorithm;
		swap(data[length - 1], data[length - 2]);
		swap(data[length - 2], data[length - 3]);
		length--;
	}

	void removeC()
	{
		import std.algorithm;
		swap(data[length - 1], data[length - 3]);
		length--;
	}

	Winding winding()
	{
		import physics_engine;
		return cross2D(b - a, c - a) >= 0 ? Winding.Clockwise : Winding.CounterClockWise;
	}

}


bool gjk(Polygon a, Polygon b, ref Simplex simplex)
{
	float2 dir = float2(0, 1);
	simplex.add(support(a, b, dir));

	dir = -dir;

	while(true)
	{
		simplex.add(support(a, b, dir));
		if(simplex.a.dot(dir) <= 0)
		{
			return false;
		}
		else if(simplex.containsOrigin(dir)) 
		{
			return true;
		}
	}

	return false;
}


struct Edge
{
	float2 normal;
	float  distance;
	int index;
}

Edge findClosestEdge(Polygon p, Winding w)
{
	Edge edge;
	edge.distance = float.max;

	foreach(i; 0 .. p.length)
	{
		int j = (i + 1) % p.length;

		float2 a = p[i];
		float2 b = p[j];

		float2 e = b - a;
		float2 oa = a;

		float2 n;
		if(w == Winding.Clockwise)
		{
			n = float2(e.y, -e.x).normalized;
		}
		else 
		{
			n = float2(-e.y, e.x).normalized;
		}
		
		float d = n.dot(a);
		if(d < edge.distance)
		{
			edge.distance = d;
			edge.normal   = n;
			edge.index = j;
		}
	}

	return edge;
}

enum TOLERANCE = 0.01f;

enum Winding
{
	Clockwise,
	CounterClockWise
}

bool epa(Polygon a, 
		 Polygon b, 
		 out float2 normal, 
		 out float penetration)
{
	import collections.list;

	float2[64] source = void;
	List!float2 polygon = List!float2(source[]);

	Simplex simplex;
		


	if(gjk(a, b, simplex))
	{
		polygon ~= simplex.data[];		
		while(true)
		{
			Edge e = findClosestEdge(polygon.array, simplex.winding);
			float2 p = support(a, b, e.normal);

			float d = p.dot(e.normal);
			if(d - e.distance < TOLERANCE)
			{
				normal = e.normal;
				penetration = d;
				return true;
			}
			else 
			{
				polygon.insert(e.index, p);
			}
		}

	}

	return false;
}


struct ContactEdge
{
	float2 v0, v1;

	float2 side()
	{
		return (v1 - v0);
	}

	float2 sideNormal()
	{
		return side.normalized;
	}

	float2 normal()
	{
		float2 s = side;
		return float2(-s.y, s.x);
	}
}

ContactEdge getBestEdge(Polygon a, float2 n)
{
	int c = a.length;
	float max_ = -float.max;
	foreach(i; 0 .. a.length)
	{
		float proj = n.dot(a[i]);
		if(proj > max_)
		{
			max_ = proj;
			c    = i;
		}
	}

	float2 v  = a[c];
	float2 v0 = a[(c - 1) == 0 ? c - 1 : a.length - 1];
	float2 v1 = a[(c + 1) % a.length];

	float2 right = (v - v0).normalized;
	float2 left  = (v - v1).normalized;

	if(right.dot(n) <= left.dot(n))
	{
		return ContactEdge(v0, v);
	}
	else 
	{
		return ContactEdge(v, v1);
	}
}

int clip(float2 v0, float2 v1, float2 n, float o, ref float2[2] cliped)
{
	int count = 0;
	float d0 = n.dot(v0) - o;
	float d1 = n.dot(v1) - o;

	if(d0 >= 0.0) cliped[count++] = v0;
	if(d1 >= 0.0) cliped[count++] = v1;

	if(d0 * d1 < 0.0) 
	{
		assert(count != 2);

		float2 e = v1 - v0;
		float u  = d0 / (d0 - d1);

		e *= u;
		e += v0;

		cliped[count++] = e;
	}

	return count;
}

import physics_engine, std.math;
bool colides(Mainfold* m, Polygon a, Polygon b)
{
	float2	  normal;
	float	  pen;
	float2[2] contacts;
	int		  contactCount = 0;


	float2[2] clipedPoints;
	if(epa(a, b, normal, pen))
	{
		ContactEdge e0 = getBestEdge(a, normal);
		ContactEdge e1 = getBestEdge(b, -normal);
	
		ContactEdge ref_, inc;
		bool flip = false;
		if(abs(e0.side.dot(normal)) <= abs(e1.side.dot(normal)))
		{
			ref_ = e0;
			inc  = e1;
		}
		else
		{
			ref_ = e1;
			inc  = e0;
			flip = true;
		}

		float2 refSideNorm = ref_.sideNormal;
		float o0 = refSideNorm.dot(ref_.v0);
		float o1 = refSideNorm.dot(ref_.v1);

		if(clip(inc.v0, inc.v1, refSideNorm, o0, clipedPoints) < 2) return false;
		if(clip(clipedPoints[0], clipedPoints[1], -refSideNorm, -o1, clipedPoints) < 2) return false;

		float2 refNorm = float2(-refSideNorm.y, refSideNorm.x);
		if(flip) refNorm = -refNorm;

		float max_ = refNorm.dot(ref_.v0);
		if(refNorm.dot(clipedPoints[0]) - max_ >= 0)
		{
			contacts[contactCount++] = clipedPoints[0];
		}

		if(refNorm.dot(clipedPoints[1]) - max_ >= 0)
		{
			contacts[contactCount++] = clipedPoints[1];
		}


		m.normal = normal;
		m.penetration = pen;
		m.contacts    = contacts;
		m.contactCount = contactCount;

		return true;		
	}

	return false;
}