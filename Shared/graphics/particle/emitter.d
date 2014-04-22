module graphics.particle.emitter;

import std.random, math, graphics, content.sdl, std.algorithm, 
	collections;

enum DELTA = 0.001f;

struct ParticleEffectConfig
{
	List!EmitterConfig emitters;
	float time;
	@Optional(1.0f) float particleMultiplier;
	bool looping;
	bool playing;
}

struct ParticleEffect
{
	ulong id;
	float2 position;
	float time;
	float elapsed;
	float particleMultiplier;
	bool playing;
	bool looping;

	this(ref ParticleEffectConfig config, ulong effectID, float2 pos)
	{
		id = effectID;
		position = pos;
		time = config.time;
		elapsed = 0f;
		particleMultiplier = config.particleMultiplier;
		playing = config.playing;
		looping = config.looping;
	}
}

struct ParticleCommon
{
	Color  startColor, endColor, colorVariance;
	float2 startSize, endSize,  sizeVariance;
	float  speed, speedVariance;
	float  rotationSpeed, rotationVariance;
	float  lifeTime, lifeTimeVariance;
	float  startAlpha, endAlpha;

	this(T)(ref T config, float2 scale = float2.one)
	{	
		startColor			= Color(config.startColor);
		endColor			= Color(config.endColor);
		colorVariance		= Color(config.colorVariance);
		startSize			= config.startSize * scale;
		endSize				= config.endSize * scale;
		sizeVariance		= config.sizeVariance * scale;
		speed				= config.speed * scale.x;
		speedVariance		= config.speedVariance * scale.x;
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

	ParticleCommon common;
	float angle;
	float width; 
	float line;

	List!EmitterPoint points;

	this(ref EmitterConfig config, ParticleSystem sys, float2 scale)
	{	
		common    = ParticleCommon(config, scale);
		width	  = config.width;
		angle	  = config.angle;
		line	  = config.line*scale.x;
		points	  = config.points;
	}


	void update(ParticleSystem system, ref ParticleEffect effect, float delta)
	{
		float oldElapsed = effect.elapsed - delta;
		foreach(point; points)
		{
			if(oldElapsed < point.time &&
			   effect.elapsed >= point.time)
			{

				float4 coords = system.atlas.frame(point.particle).coords;
				auto numParticles = cast(size_t)(point.count * effect.particleMultiplier);
				foreach(i; 0 .. numParticles)
				{
					float rnd = uniform(-0.5f, 0.5f);
					float a = angle + width * rnd;
					auto polar = Polar!float(angle + TAU / 4, rnd * line);


					auto particle = common.makeParticle(effect.position + polar.toCartesian, a, coords);
					system.addParticle(particle);
				}
			}
		}
	}
}