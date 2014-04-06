module state;

import game;
import std.json;
import std.file;
import std.stdio;
import math;
import graphics;

struct SpriterObject
{
	Foulder[] foulders;
	Entity[] entities;

	int currentEntity;
	int currentAnimation;

	float currentTime = 0;
}

struct File 
{
	string name;
	int height, width;
	float2 origin;
}

struct Foulder
{
	string name;
	File[] files;
}

struct Entity
{
	string name;
	Animation[] animations;
}

struct Ref
{
	int timeline;
	int key;
	int z_index;
}

struct MainlineKey
{
	float time = 0;
	Ref[] objectRefs;
}

struct Timeline
{
	string name;
	int objectType;
	TimelineKey[] keys;
}

enum CurveType
{
	instant,
	linear,
	quadratic,
	cubic
}

struct TimelineKey
{
	float time  = 0;
	float curve0 = 0, curve1 = 0;
	int curveType = CurveType.linear;
	int spin		  = 1;

	SpatialInfo info;
}	

struct SpatialInfo
{
	float2 pos = float2.zero;
	float2 scale = float2(1,1);
	float2 origin = float2(float.nan, float.nan);
	float rotation = 0;
	float alpha = 1;

	int foulder;
	int file;
}

enum LoopType 
{
	noLooping,
	looping
}

struct Animation
{
	float length;
	int looptype = LoopType.looping;
	string name;

	MainlineKey[] mainlines;
	Timeline[] timelines;

}

auto readFile(JSONValue[string] file)
{
	File f;
	foreach(k, v; file) switch(k)
	{
		case "height"  : f.height	 = cast(int)v.integer;   break;
		case "width"   : f.width	 = cast(int)v.integer;   break;
		case "name"    : f.name		 = v.str;				    break;
		case "pivot_x" : f.origin.x = cast(float)v.floatOrInt; break;
		case "pivot_y" : f.origin.y = v.floatOrInt; break;

	   default: break;
	}
	return f;
}

auto readFiles(JSONValue[] files)
{
	File[] f;
	foreach(v; files)
		f ~= readFile(v.object);

	return f;
}

auto readFoulder(JSONValue[string] foulder)
{
	Foulder f;
	foreach(k, v; foulder) switch(k)
	{
		case "file": f.files = readFiles(v.array); break;
		case "name": f.name = v.str; break;
		default: break;
	}

	return f;
}

auto readObjectRef(JSONValue[string] ref_)
{
	Ref r;
	foreach(k, v; ref_) switch(k)
	{
		case "key":			r.key			= cast(int)v.integer; break;
		case "timeline":	r.timeline	= cast(int)v.integer; break;
		case "z_index":	r.z_index	= cast(int)v.integer; break;
		default: break;
	}
	return r;
}

auto readObjectRefs(JSONValue[] refs)
{	
	Ref[] r;
	foreach(v; refs) r ~= readObjectRef(v.object);
	return r;
}

auto readMainKey(JSONValue[string] key)
{
	MainlineKey m;
	foreach(k, v; key)
	{
		switch(k)
		{
			case "time": m.time = cast(int)v.integer / 1000f; break;
			case "object_ref": m.objectRefs = readObjectRefs(v.array);	break;
			default: break;
		}
	}

	return m;
}

auto readMainlines(JSONValue[string] mainline)
{
	MainlineKey[] m;
	foreach(v; mainline["key"].array) 
	{
		m ~= readMainKey(v.object);
	}
	return m;
}

float floatOrInt(JSONValue value)
{
	return value.type == JSON_TYPE.FLOAT ? value.floating : value.integer;
}

auto readSpatial(JSONValue[string] spatial)
{
	SpatialInfo info;
	foreach(k, v; spatial) 
	{		
		switch(k)
		{
			case "file"	 :	info.file		= cast(int)v.integer;	  break;
			case "folder": info.foulder	= cast(int)v.integer;     break;
			case "a"		 : info.alpha     = v.floatOrInt;  break;
			case "x"		 : info.pos.x     = v.floatOrInt;  break;
			case "y"     : info.pos.y     = v.floatOrInt;  break;
			case "scale_x": info.scale.x  = v.floatOrInt;  break;
			case "scale_y": info.scale.y  = v.floatOrInt;  break;
			case "pivot_x": info.origin.x = v.floatOrInt;  break;
			case "pivot_y": info.origin.y = v.floatOrInt;  break;
			case "angle":   info.rotation = v.floatOrInt / 360 * TAU;

			default: break;
		}
	}

	return info;
}

auto readTKey(JSONValue[string] tKey)
{
	TimelineKey t;
	foreach(k, v; tKey) switch(k)
	{
		case "object": t.info		= readSpatial(v.object);		 break;
		case "spin"  : t.spin		= cast(int)v.integer;			 break;
		case "time"  : t.time      = cast(int)v.integer / 1000f;	 break;
		case "c0"	 : t.curve0    = v.floatOrInt();					 break;
		case "c1"    : t.curve1    = v.floatOrInt();					 break;
		case "curve_type" : 
			writeln("CurveType ", v.type);
			switch(v.str)
			{
				case "instant":
					t.curveType = CurveType.instant;
					break;
				case "linear":
					t.curveType = CurveType.linear;
					break;
				case "quadratic":
					t.curveType = CurveType.quadratic;
					break;
				case "cubic":
					t.curveType = CurveType.cubic;
					break;
				default: assert(0, "Invalid curve type");
			}
		break;

		default: break;
	}

	return t;
}


auto readTKeys(JSONValue[] keys)
{
	TimelineKey[] t;
	foreach(v; keys) t ~= readTKey(v.object);
	return t;
}


auto readTimeline(JSONValue[string] timelines)
{
	Timeline t;
	foreach(k, v; timelines) switch(k)
	{
		case "name": t.name = v.str; break;
		case "key":  t.keys = readTKeys(v.array);	break;
		default: break;
	}
	return t;
}

auto readTimelines(JSONValue[] timelines)
{
	Timeline[] t;
	foreach(v; timelines) t ~= readTimeline(v.object);
	return t;
}


auto readAnimation(JSONValue[string] animation)
{
	Animation a;
	foreach(k,v; animation) 
	{
		switch(k)
		{
			case "length":   a.length = v.integer / 1000f; break;
			case "mainline": a.mainlines = readMainlines(v.object); break;
			case "timeline": a.timelines = readTimelines(v.array); break;
			case "name":	  a.name      = v.str;	 
			default: break;
		}
	}

	return a;
}

auto readAnimations(JSONValue[] animations)
{
	Animation[] a;
	foreach(v; animations)	a ~= readAnimation(v.object);
	return a;
}

auto readEntity(JSONValue[string] entity)
{
	Entity e;
	foreach(k, v; entity) 
	{
		switch(k)
		{
			case "name":		 e.name = v.str; break;
			case "animation":  e.animations = readAnimations(v.array);	break;
			default: break;
		}
	}
	return e;
}

auto readEntities(JSONValue[] entities)
{
	Entity[] e;
	foreach(v; entities) e ~= readEntity(v.object);
	return e;
}

class TestState : IGameState
{
	SpriterObject object;

	this()
	{
		auto file = "../resources/elements/textures/test0.scon";
		auto json = parseJSON(readText(file));

		object = SpriterObject();
		foreach(k, v; json.object)
		{
			if(k == "folder")
			{
				foreach(f; v.array)	
					object.foulders ~= readFoulder(f.object);
			} 
			else if(k == "entity")
			{
				object.entities = readEntities(v.array);
			}
		}

		foreach(entity; object.entities)
		foreach(animation; entity.animations)
		foreach(timeline; animation.timelines)
		foreach(ref key; timeline.keys)
		{
			if(std.math.isNaN(key.info.origin.x) != 0)
			{
				float2 origin = object.foulders[key.info.foulder].files[key.info.file].origin;
				key.info.origin = origin;
			}
		}

	}

	void enter()  { }
	void exit()   { }
	void update() 
	{ 
		object.currentTime += Time.delta * 0.3;
		if(object.currentTime > object.entities[0].animations[0].length &&
			object.entities[0].animations[0].looptype == LoopType.looping)
			object.currentTime = 0;
			
	}

	void render() 
	{ 
			gl.clear(ClearFlags.color);

		 foreach(e; object.entities)
		 {
			 foreach(a; e.animations)
			 {

				auto mainline = a.mainlines.line(object.currentTime);

				 foreach(o; mainline.objectRefs)
				 {
					 SpatialInfo spatial =  a.timelines[o.timeline].info(o.key, a.looptype == 1, object.currentTime, a.length);
					 writeln("Loading: ", object.foulders[spatial.foulder].files[spatial.file].name);

					 auto frame   =  
						 Frame(Game.content.loadTexture(
								 object.foulders[spatial.foulder].files[spatial.file].name));
			
					 foreach(i; 4 .. 14)
					 {

						 Game.renderer.addFrame(frame, 
														float2(100, 40) * i + spatial.pos, 
														Color.white, 
														spatial.scale, 
														spatial.origin * float2(frame.srcRect.z, frame.srcRect.w),
														spatial.rotation);
					 }
				 }
			 }
		 }
	}
}

auto line(MainlineKey[] lines, float currentTime)
{
	int index = -1;
	foreach(i; 1 .. lines.length)
	{
		if(lines[i].time > currentTime)
		{
			index = i;
			return lines[index - 1];
		}
	}
	
	return lines[$ - 1];
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

float curveTime(ref TimelineKey key0, float t)
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