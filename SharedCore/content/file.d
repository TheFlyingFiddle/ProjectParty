module content.file;

import util.hash;

enum fileCacheName = "FileCache.sdl";
enum fileMapName   = "Map.sdl";

struct FileMap
{
	FileItem[] items;
}

struct FileItem
{
	string name;
	HashID   hash;
}
