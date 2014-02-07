module math.vector;

import std.string : format;
import std.traits : isFloatingPoint, CommonType, isNumeric;

alias float2 = Vector!(2, float);
alias int2   = Vector!(2, int);
alias uint2  = Vector!(2, uint);

alias float3 = Vector!(3, float);
alias int3   = Vector!(3, int);
alias uint3  = Vector!(3, uint);

alias float4 = Vector!(4, float);
alias int4   = Vector!(4, int);
alias uint4  = Vector!(4, uint);

struct Vector(size_t size, T) 
{
	private T[size] data;

	this(U)(U u) if (isNumeric!U)
	{
		foreach(i; staticIota!(0, size))
			this.data[i] = cast(T)u;
	}

	this(U...)(U u) 
		if(U.length == size)
		{
			foreach(i, elem; u) 
				this.data[i] = cast(T)elem;
		}

	this(U)(auto ref Vector!(size, U) other)
	{
		foreach(i; staticIota!(0, size)) 
			this.data[i] = cast(T)other.data[i];
	}

	this(size_t N, U, V...)(auto ref Vector!(N, U) other, V v)
		if(is(U : T) && N + V.length == size && N < size)
		{
			foreach(i; staticIota!(0, N)) 
				this.data[i] = other.data[i];
			foreach(i; staticIota!(N, size))
				this.data[i] = v[i];
		}


	ref Vector!(size, T) opAssign(U)(auto ref Vector2!(size, U) other)
		if(is(U : T))
		{
			foreach(i; staticIota!(0, size))
				this.data[i] = other.data[i];
		}

	Vector!(size, T) opUnary(string s)() if(s == "+" || s == "-")
	{
		Vector!(size, T) res;
		foreach(i; staticIota!(0, size))
			mixin(format("res.data[%s] = %sdata[%s];", i, s, i));
		return res;
	}

	Vector!(size, T) opBinary(string s, U)(auto ref Vector!(size, U) vec) 
		if(is(U : T) && (s == "+" || s == "-" || s == "*"))
		{
			Vector!(size, T) res;
			foreach(i; staticIota!(0, size))
				mixin(format("res.data[%s] = this.data[%s] %s vec.data[%s];", i, i, s, i));
			return res;
		}

	Vector!(size, T) opBinary(string op, U)(U u)
		if(isNumeric!U && is(U : T) && (op == "+" || op == "-" || op == "/" || op == "*"))
		{
			Vector!(size, T) res;
			foreach(i; staticIota!(0, size))
				mixin(format("res.data[%s] = this.data[%s] %s u;", i, i, op));
			return res;
		}

	ref Vector!(size, T) opOpAssign(string op, U)(auto ref Vector!(size, U) vec)
		if(is(U : T) && op == "+" || op == "-" || op == "*")
		{
			foreach(i; staticIota!(0, size)) 
				mixin(format("this.data[%s] %s= vec.data[%s];", i, op, i));

			return this;
		}

	ref Vector!(size, T) opOpAssign(string op, U)(U u)
		if(is(U : T) && op == "+" || op == "-" || op == "*" || op == "/")
		{
			foreach(i; staticIota!(0, size)) 
				mixin(format("this.data[%s] %s= u;", i, op));

			return this;
		}

	ref T opDispatch(string s, U)(U t) @property
		if(s.length == 1 && is(U : T))
		{
			enum offset = swizzleTable[s[0]];
			data[offset] = t;
			return data[offset];
		}

	void opDispatch(string s, Vec)(ref Vec vec)
		if(is(Vec v == Vector!Args, Args...)
		   && s.length == Args[0] 
			&& is(Args[1] : T))
		{
			foreach(i; staticIota!(0, s.length)) {
				enum offset = swizzleTable[s[i]];
				data[offset] = vec.data[i];
			}
		}

	auto ref opDispatch(string s)()
		if(s.length == 1LU)
		{
			enum offset = swizzleTable[s[0]];
			return data[offset];
		}

	Vector!(s.length, T) opDispatch(string s)()
		if(s.length > 1)
		{	
			Vector!(s.length, T) res;
			foreach(i; staticIota!(0, s.length)) {
				enum offset = swizzleTable[s[i]];
				res.data[i] = data[offset];
			}

			return res;
		}

	private enum swizzleTable = genTable();
	static size_t[char] genTable()
	{
		size_t[char] table;
		static if(size >= 2) {
			table['x'] = 0;
			table['y'] = 1;
		} static if(size >= 3) {
			table['z'] = 2;
		} static if(size >= 4) {
			table['w'] = 3;
		} 

		//What to do if 5d .. Nd vector? :O 
		return table;
	}


	static Vector!(size, T) zero()
	{
		return Vector!(size,T)(cast(T)0);
	}

}

auto magnitude(size_t N, T)(auto ref Vector!(N,T) vec)
{
	import std.math;
	return sqrt(cast(float)dot(vec, vec));
}

Vector!(N, T) normalized(size_t N, T)(auto ref Vector!(N,T) vec)
{
	return vec / vec.magnitude();
}

void normalize(size_t N, T)(ref Vector!(N,T) vec)
{
	auto m = vec.magnitude();
	foreach(i; staticIota!(0, size))
		this.data[i] /= m;
}

auto dot(size_t N, T, U)(auto ref Vector!(N, T) vec0, 
						 auto ref Vector!(N, U) vec1)
{
	static if(is(T : U)) 
		alias RT = T;
	else static if(is(U : T))
		alias RT = U;

	RT res = 0;
	foreach(i; staticIota!(0, N))
		res += vec0.data[i] * vec1.data[i];
	return res;
}

auto distance(size_t N, T, U)(auto ref Vector!(N, T) vec0,
							  auto ref Vector!(N, U) vec1)
{
	import std.math;
	return sqrt(distanceSquared(vec0, vec1));
}

auto distanceSquared(size_t N, T, U)(auto ref Vector!(N, T) vec0, 
									 auto ref Vector!(N, U) vec1)
{
	static if(is(T : U)) 
		alias RT = T;
	else static if(is(U : T))
		alias RT = U;

	RT res = 0;
	foreach(i; staticIota!(0, N)) {
		RT tmp = vec0.data[i] - vec1.data[i];
		res += tmp * tmp;
	}

	return res;
}

auto cross(T, U)(auto ref Vector!(3, T) vec0,
				 auto ref Vector!(3, U) vec1)
{
	static if(is(T : U)) 
		alias RT = T;
	else static if(is(U : T))
		alias RT = U;

	Vector!(3, RT) res;
	res.x = vec0.y * vec1.z - vec0.z * vec1.y;
	res.y = vec0.z * vec1.x - vec0.x * vec1.z;
	res.z = vec0.x * vec1.y - vec1.y * vec2.x;

	return res;
}

auto rotate(T)(auto ref Vector!(2, T) toRotate, auto float angle)
{
	import std.math;
	auto s = sin(angle), 
		 c = cos(angle);

	Vector!(2, T) result;
	result.x = c * toRotate.x - s * toRotate.y;
	result.y = s * toRotate.x + c * toRotate.y;

	return result;
}

template staticIota(size_t s, size_t e)
{
	import std.typetuple : TypeTuple;
	static if(s < e)
		alias staticIota = TypeTuple!(s, staticIota!(s + 1, e));
	else 
		alias staticIota = TypeTuple!();
}

unittest
{
	float2 a = float2(1), b = float2(2);

	a.x = 2;
	a.y = 3;
	assert(a.opDispatch!("x") == 2 && a.y == 3);

	b.opDispatch!("xy")(a);
	assert(b.x == 2 && b.y == 3);

	auto aa = a.yy;
	b += a.yy;
	assert(b.x == 5 && b.y == 6);

	float3 c;
	c.x = 1;
	c.y = 2;
	c.z = 3;

	float4 f;
	f.x = 1;
	f.y = 2;
	f.z = 3;
	f.w = 4;
}