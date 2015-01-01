module namespace;

public import framework;
public import allocation;
public import math.vector;
public import math.matrix;
public import graphics.color;
public import collections.list;

struct Constants
{
	float playerSpeedMultiplier;
	float gravity;
	float jump;
	float maxFallSpeed;
	float worldScale;
}

Constants constants;

void loadConstants()
{
	import content.sdl;
	constants = fromSDLFile!Constants(Mallocator.it, "constants.sdl");
}

RegionAllocator scratch_region;