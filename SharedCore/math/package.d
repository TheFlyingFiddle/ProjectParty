module math;

public import math.vector;
public import math.polar;
public import math.matrix;
public import math.traits;


enum double TAU = 6.2831853071;

static T clamp(T)(T value, T min, T max)
{
	if (value < min)
		return min;
	else if (value > max)
		return max;
	else
		return value;
}