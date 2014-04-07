module spriter.types;

import math;

struct SpriterObject
{
	Foulder[] foulders;
	Entity[] entities;
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

struct SpriteObjectID
{
	uint index;
}



struct SpriteInstance
{
	float time;
	float speedMultiplier;
	int animationIndex;
	int entityIndex;
	SpriteObjectID id;

	void update(float delta)
	{
		import loader;
		auto object = SpriteManager.lookup(id);
		time += delta * speedMultiplier;
		if(time > object.entities[entityIndex].animations[animationIndex].length && 
			object.entities[entityIndex].animations[animationIndex].looptype == LoopType.looping) {
				time -= object.entities[entityIndex].animations[animationIndex].length;
			}
	}
}