module graphics.emitter;

import std.random, math, graphics, content.sdl, std.algorithm, 
	   collections;

enum DELTA = 0.001f;

struct ParticleEffect
{
	float2 position;
}

struct ParticleCommon
{
	Color  startColor, endColor, colorVariance;
	float2 startSize, endSize,  sizeVariance;
	float  speed, speedVariance;
	float  rotationSpeed, rotationVariance;
	float  lifeTime, lifeTimeVariance;
	float  startAlpha, endAlpha;

	this(T)(ref T config)
	{	
		startColor			= Color(config.startColor);
		endColor			= Color(config.endColor);
		colorVariance		= Color(config.colorVariance);
		startSize			= config.startSize;
		endSize				= config.endSize;
		sizeVariance		= config.sizeVariance;
		speed				= config.speed;
		speedVariance		= config.speedVariance;
		rotationSpeed		= config.rotationSpeed;
		rotationVariance	= config.rotationVariance;
		lifeTime			= config.lifeTime;
		lifeTimeVariance	= config.lifeTimeVariance;
		startAlpha			= config.startAlpha;
		endAlpha			= config.endAlpha;
	}


	Particle makeParticle(float2 pos, float angle, ref float4 coords)
	{
		Particle particle;
		particle.startColor.r	= uniform(max(0.0f, startColor.r - colorVariance.r), min(1f, startColor.r + colorVariance.r) + DELTA);
		particle.startColor.g	= uniform(max(0.0f, startColor.g - colorVariance.g), min(1f, startColor.g + colorVariance.g) + DELTA);
		particle.startColor.b	= uniform(max(0.0f, startColor.b - colorVariance.b), min(1f, startColor.b + colorVariance.b) + DELTA);
		particle.startColor.a	= uniform(max(0.0f, startColor.a - colorVariance.a), min(1f, startColor.a + colorVariance.a) + DELTA);
	

		
		particle.endColor		= endColor;
		particle.center			= pos;
		particle.velocity		= Polar!float(angle, uniform(speed - speedVariance, speed + speedVariance + DELTA)).toCartesian;
		particle.lifeTime		= uniform(lifeTime - lifeTimeVariance, lifeTime + lifeTimeVariance + DELTA);
		particle.rotationSpeed	= uniform(rotationSpeed - rotationVariance, rotationSpeed + rotationVariance + DELTA);
		particle.coords			= coords;
		
		float2 size				= float2(uniform(-sizeVariance.x, sizeVariance.x + DELTA), uniform(-sizeVariance.y, sizeVariance.y + DELTA));
		particle.startSize		= float2(startSize.x + size.x, startSize.y + size.y);
		particle.endSize		= float2(endSize.x + size.x, endSize.y + size.y);

		particle.startAlpha		= startAlpha;
		particle.endAlpha		= endAlpha;

		return particle;

	}

}

struct EmitterConfig 
{
	@Optional(0xFFFFFFFFu) uint  startColor;
	@Optional(0xFFFFFFFFu) uint  endColor;
	@Optional(0u)		   uint  colorVariance;
	
	@Optional(float2(50,50)) float2 startSize;
	@Optional(float2(50,50)) float2 endSize;
	@Optional(float2.zero) float2 sizeVariance;

	@Optional(0f) float  speed;
	@Optional(0f) float  speedVariance;
	@Optional(0f) float  rotationSpeed;
	@Optional(0f) float  rotationVariance;
	@Optional(1f) float  lifeTime;
	@Optional(0f) float  lifeTimeVariance;

	@Optional(1f) float  startAlpha;
	@Optional(0f) float  endAlpha;

	@Optional(EmitterType.cone) EmitterType type;
	@Optional(0f) float angle;
	@Optional(0f) float width;
	@Optional(0f) float line; 

	float time;
	List!EmitterPoint points;
}

enum EmitterType
{
	cone
}

struct EmitterPoint
{
	float time;
	int   count;
	string particle;
}

struct ConeEmitter
{
	enum type = EmitterType.cone;
	float elapsed;

	ParticleCommon common;
	float angle;
	float width; 
	float line;

	float time;
	float multiplier;
	List!EmitterPoint points;


	this(ref EmitterConfig config, ParticleSystem sys)
	{	
		common    = ParticleCommon(config);
		width	  = config.width;
		angle	  = config.angle;
		elapsed	  = 0.0f;
		line	  = config.line;
		time	  = config.time;
		points	  = config.points;
		multiplier = uniform(0.5f, 2.5f);
	}


	void update(float delta, ParticleSystem system, ref ParticleEffect effect)
	{
		float oldElapsed = elapsed;
		elapsed += delta * multiplier;
	
		foreach(point; points)
		{
			if(oldElapsed < point.time &&
			   elapsed	  >= point.time)
			{

				float4 coords = system.atlas.frame(point.particle).coords;
				foreach(i; 0 .. point.count)
				{
					float rnd = uniform(-0.5f, 0.5f);
					float a = angle + width * rnd;
					auto polar = Polar!float(angle + TAU / 4, rnd * line);
	

					auto particle = common.makeParticle(effect.position + polar.toCartesian, a, coords);
					system.addParticle(particle);
				}
			}
		}

		if(elapsed > time)
		{
			elapsed -= time;
		}
	}
}