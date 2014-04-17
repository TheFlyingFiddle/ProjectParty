module spriter.renderer;

import game, math, graphics, spriter.loader, spriter.types;

void addSprite(Renderer* renderer, ref SpriteInstance sprite, float2 position, Color color = Color.white)
{
	//This is stupid.
	auto object = SpriteManager.lookup(sprite.id);
	auto anim = object.entities[sprite.entityIndex].animations[sprite.animationIndex];
	auto mainIndex = anim.mainlines.line(sprite.time);
	foreach(o; anim.mainlines[mainIndex].objectRefs)
	{
		SpatialInfo spatial =  anim.timelines[o.timeline].
			info(o.key, anim.looptype == 1, 
				  sprite.time, anim.length);

		//This is stupid.
		auto frame = Frame(Game.content.
								 loadTexture(object.foulders[spatial.foulder].
												 files[spatial.file].name));

		renderer.addFrame(frame, 
							   position + spatial.pos, 
							   color, 
								spatial.scale, 
								spatial.origin * float2(frame.srcRect.z, frame.srcRect.w),
								spatial.rotation);
	}
}

auto line(MainlineKey[] lines, float currentTime)
{
	foreach(i; 1 .. lines.length)
	{
		if(lines[i].time > currentTime)
			return i - 1;
	}

	return lines.length - 1;
}

SpatialInfo info(Timeline timeline, int key, bool looping, float currentTime, float totalTime)
{
	if(key == timeline.keys.length - 1) 
	{
		if(looping)
		{
			float linearTime = (currentTime - timeline.keys[$ - 1].time) /
				(totalTime   - timeline.keys[$ - 1].time);

			float time = curveTime(timeline.keys[$ - 1], linearTime);
			return linear(timeline.keys[$ - 1].info, 
							  timeline.keys[0].info,
							  timeline.keys[$ - 1].spin, 
							  time);

		} else {
			return timeline.keys[$ - 1].info;
		}
	} 
	else 
	{
		float linearTime = (currentTime - timeline.keys[key].time) / 
			(timeline.keys[key + 1].time - timeline.keys[key].time);

		float time = curveTime(timeline.keys[key], linearTime);
		return linear(timeline.keys[key].info, 
						  timeline.keys[key + 1].info, 
						  timeline.keys[key].spin, time);
	}
}

float curveTime(TKey)(ref TKey key0, float t)
{
	final switch(key0.curveType)
	{
		case CurveType.instant:
			return 0;
			break;
		case CurveType.linear:
			return t;
			break;
		case CurveType.quadratic:
			return quadratic(0.0, key0.curve0, 1.0, t);
			break;
		case CurveType.cubic:
			return cubic(0.0, key0.curve0, key0.curve1, 1.0, t);
	}
}

float linear(float a, float b, float t)
{
	return (b - a) * t + a;
}

float quadratic(float a, float b, float c, float t)
{
	return linear(linear(a,b,t), linear(b,c,t), t);
}

float cubic(float a, float b, float c, float d, float t)
{
   return linear(quadratic(a,b,c,t), quadratic(b,c,d,t), t);
}

float rotationLinear(float rot0, float rot1, int spin, float t)
{
	if (spin == 0)
		return rot0;

	if(spin > 0) 
	{
		if(rot1 - rot0 < 0)
			rot1 += TAU;
	} 
	else 
	{
		if(rot1 - rot0 > 0)
			rot1 -= TAU;
	}

	return linear(rot0, rot1, t);
}

SpatialInfo linear(SpatialInfo info0, SpatialInfo info1, int spin, float t)
{
	SpatialInfo result;
	result.pos.x			= linear(info0.pos.x, info1.pos.x, t);
	result.pos.y			= linear(info0.pos.y, info1.pos.y, t);
	result.scale.x			= linear(info0.scale.x, info1.scale.x, t);
	result.scale.y			= linear(info0.scale.y, info1.scale.y, t);
	result.rotation		= rotationLinear(info0.rotation, info1.rotation, spin, t);
	result.origin			= info0.origin;
	result.file				= info0.file;
	result.foulder			= info0.foulder;

	return result;
}