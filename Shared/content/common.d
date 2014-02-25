module content.common;

import content.sdl : Optional;

string resourceDir = "..\\resources";

enum AssetType
{
	texture = 0, 
	font = 1,
	script = 2,
	textureAtlas = 3
}

struct Asset
{
	AssetType type;
	string path;
	@Optional("") string name;
}