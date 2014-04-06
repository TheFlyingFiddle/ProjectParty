module spriter;

/*
struct ScmlObject
{
	string[] foulders; //Base...
	Entity[] entities;
	string[] activeCharacterMap;

	int currentEntity;
	int currentAnimation;
	float currentTime;
}

struct Entity
{
	string name; // <--- Lol live data with name...
	CharacterMap[] charMaps;
	Animation[]    animations;
}

struct CharacterMap
{
	string name;
	MapInstruction[] maps;
}

struct MapInstruction
{
	int foulder, file;
	int targetFolder = -1, targetFile = -1;
}


enum LoopType
{
	noLooping = 0,
	looping   = 1
}

struct Animation
{
	string name;
	int length;
	int loopType = LoopType.looping;
	MainlineKey[] mainlineKeys;
	Timeline[] timelines;
}

struct MainlineKey
{
	int time=0;
	Ref[] boneRefs;
	Ref[] objectRefs;
}

enum CurveType
{
	instant,
	linear,
	quadratic,
	cubic
}

class TimelineKey
{
	int time = 0;
	int currType = CurveType.linear;
	
	float c0, c1;
}

class SpatialTimelineKey : TimelineKey
{
	SpatialInfo info;
	void paint();
}


struct SpatialInfo
{
	float2 pos = float2.zero;
	float2 scale = float2(1,1);
	float rotation = 0;
	float alpha = 1;
	int spin    = 1;
}

class BoneTimelineKey : SpatialTimelineKey
{
	int length = 200;
	int width  = 10;
}

class SpriteTimelineKey : SpatialTimelineKey
{
	int foulder, file;
	bool useDefaultPivot;
	float pivot_x = 0;
	float pivot_y = 1;
} 
*/