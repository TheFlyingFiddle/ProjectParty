module particles.updaters;

import math.vector, graphics.color;
import particles.system;
import particles.bindings;

void eulerUpdater(ref ParticleSystem s, float dt)
{
	//From the world global variables and whatever can be extracted.
	//auto world = s.variables!(World*, "world");

	auto posVar = s.particles.variable!(PosVar); 
	auto velVar = s.particles.variable!(VelVar); 

	foreach(i; 0 .. s.particles.alive)
	{
		posVar[i] += velVar[i] * dt;	
	}
}

void colorUpdater(ref ParticleSystem s, float dt)
{
	auto sColorVar =  s.particles.variable!(StartColorVar);
	auto eColorVar =  s.particles.variable!(EndColorVar);
	auto colorVar  =  s.particles.variable!(ColorVar);
	auto timeVar   =  s.particles.variable!(LifeTimeVar);

	foreach(i; 0 .. s.particles.alive)
	{
		colorVar[i] = Color.interpolate(sColorVar[i], 
											  eColorVar[i],
											  timeVar[i].relative);
	}
}

void timeUpdater(ref ParticleSystem s, float dt)
{
	auto timeVar = s.particles.variable!(LifeTimeVar);

	foreach_reverse(i; 0 .. s.particles.alive)
	{
		timeVar[i].elapsed += dt;
		if(timeVar[i].elapsed >= timeVar[i].end)
		{
			s.particles.kill(i);
		}
	}
}