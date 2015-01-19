module math.polar;


import std.math;
import math.vector;

alias Polarf = Polar!(float);

struct Polar(T)
{
	T angle;
	T magnitude;
}

Polar!(T) toPolar(T)(Vector!(2, T) other) 
{
	return Polar!(T)(atan2(other.y, other.x), other.magnitude);
}

Vector!(2, T) toCartesian(T)(Polar!(T) polar)
{
	return Vector!(2,T)(cos(polar.angle) * polar.magnitude,
						sin(polar.angle) * polar.magnitude);
}