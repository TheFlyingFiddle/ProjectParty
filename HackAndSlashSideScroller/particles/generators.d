module particles.generators;

import std.random;
import particles.system;
import particles.bindings;

import math;
import graphics.color;


public:
void circlePosGen(ref ParticleSystem s, float dt, size_t start, size_t count)
{
	posGen!(circlePosGen_)(s, dt, start, count);
}

void boxPosGen(ref ParticleSystem s, float dt, size_t start, size_t count)
{
	posGen!(boxPosGen_)(s, dt, start, count);
}

void circleVelGen(ref ParticleSystem s, float dt, size_t start, size_t count)
{
	auto interval = s.variable!(CircleSpeed);
	auto velVar = s.particles.variable!(VelVar)(start, count);
	
	foreach(ref velocity; velVar)
	{
		velocity = Polarf(uniform(0.0, TAU), uniform(interval.min, interval.max)).toCartesian;
	}
}

void coneVelGen(ref ParticleSystem s, float dt, size_t start, size_t count)
{
	auto speedInterval = s.variable!(ConeSpeed);
	auto angleInterval = s.variable!(ConeAngle);

	auto velVar  = s.particles.variable!(VelVar)(start, count);
	foreach(ref velocity; velVar)
	{
		velocity = Polarf(uniform(angleInterval.min, angleInterval.max), 
						  uniform(speedInterval.min, speedInterval.max)).toCartesian;
	}
}

void basicVelGen(ref ParticleSystem s, float dt, size_t start, size_t count)
{
	auto vel = s.variable!(Velocity);

	auto velVar  = s.particles.variable!(VelVar)(start, count);
	foreach(ref velocity; velVar)
	{
		velocity = float2(uniform(vel.min.x, vel.max.x), 
						  uniform(vel.min.y, vel.max.y));
	}
}

void basicColorGen(ref ParticleSystem s, float dt, size_t start, size_t count)
{
	auto sColor   = s.variable!(StartColor);
	auto eColor   = s.variable!(EndColor);

	auto startColor  = s.particles.variable!(StartColorVar)(start, count);
	auto endColor    = s.particles.variable!(EndColorVar)(start, count);
	auto color	     = s.particles.variable!(ColorVar)(start, count);

	foreach(i; 0 .. count)
	{
		startColor[i] = uniformColor(sColor.min, sColor.max);
		endColor[i]   = uniformColor(eColor.min, eColor.max);
		color[i]	  = startColor[i];
	}
}

T safeUniform(T)(T from, T to)
{
	if(from == to) return from;
	if(to > from)
		return uniform(from, to);
	else 
		return uniform(to, from);
}

Color uniformColor(Color c0, Color c1)
{
	int r = safeUniform(c0.rbits, c1.rbits);
	int g = safeUniform(c0.gbits, c1.gbits);
	int b = safeUniform(c0.bbits, c1.bbits);
	int a = safeUniform(c0.abits, c1.abits);

	return Color(r, g, b, a);
}

void basicTimeGen(ref ParticleSystem s, float dt, size_t start, size_t count)
{
	auto lifeTime = s.variable!(LifeTime);
	auto life		  = s.particles.variable!(LifeTimeVar)(start, count);

	foreach(ref lt; life)
	{
		lt = LifeSpan(0, uniform(lifeTime.min, lifeTime.max));
	}
}


package void circlePosGen_(ref ParticleSystem s, float dt, float2 pos, float2[] partPos)
{
	auto r   = s.variable!(CirclePosRadius);
	foreach(ref position; partPos)
	{
		float2 offset = Polarf(uniform(0.0, TAU), r).toCartesian;
		position = pos + offset;
	}
}

package void boxPosGen_(ref ParticleSystem s, float dt, float2 pos, float2[] partPos)
{
	auto offset = s.variable!(BoxPosOffset);
	float2 min  = pos - offset;
	float2 max  = pos + offset;
	
	foreach(ref position; partPos)
	{
		position = float2(uniform(min.x, max.x), uniform(min.y, max.y));
	}
}

package void posGen(alias gen)(ref ParticleSystem s, float dt, size_t start,
			   size_t count)
{
	auto origin	 = s.variable!(Origin);
	auto partVar = s.particles.variable!(PosVar)(start, count);
	
	gen(s, dt, origin, partVar);
}