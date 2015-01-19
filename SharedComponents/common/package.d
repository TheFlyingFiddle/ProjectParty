module common;

public import framework;
public import allocation;
public import math.vector;
public import math.matrix;
public import graphics.color;
public import collections.list;

public import common.bindings;
public import common.components;
public import common.content;

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

enum EntityGroups
{
	bullet = 0x01,
	enemy  = 0x02,
	player = 0x04
}

RegionAllocator scratch_region;
ScopeStack tempAllocator()
{
	return ScopeStack(scratch_region);
}