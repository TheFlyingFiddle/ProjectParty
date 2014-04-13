module content.textureatlas;

import content.common, content.reloading;
import util.strings;
import graphics.texture;
import derelict.freeimage.freeimage;
import graphics.enums;
import std.traits;
import util.hash;
import std.algorithm;
import logging;
import graphics.textureatlas;
import collections.table;

private LogChannel logChnl = LogChannel("RESOURCES.TEXTURE_ATLAS");

struct TextureAtlasID
{
	import math, graphics;

	private uint index;

	@property ref TextureAtlas atlas()
	{
		return TextureAtlasManager.lookup(this);
	}

	ref float4 opIndex(string index)
	{
		return atlas[index];
	}

	auto ref opDispatch(string s, Args...)(Args args)
	{
		mixin("return atlas()." ~ s ~ "(args);");
	}

}

package: 

struct TextureAtlasManager
{
	alias Table = ResourceTable!(TextureAtlas, graphics.textureatlas.obliterate); 
	private static Table resources;
	static init(A)(ref A allocator, uint capacity)
	{
		resources = Table(allocator, capacity);

		import content.reloading;
		FileExtention[1] exts = [ FileExtention.txt ];
		ContentReloader.registerReloader(AssetType.atlas, exts, &auto_reload);
	}

	static void shutdown()
	{
		foreach(ref resource; resources)
			resource.obliterate();
	}

	static void auto_reload(const(char)[] path)
	{
		reload(path);
	}

	static TextureAtlasID load(const(char)[] path)
	{
		auto index = resources.indexOf(path);
		if(index != -1)
			return TextureAtlasID(index);


		import std.path;
		auto atlas = loadTextureAtlas(buildPath(resourceDir, path));
		index = resources.add(atlas, path);
		return TextureAtlasID(index);

	}

	static void unload(const(char)[] path)
	{
		resources.remove(path);
	}

	static TextureAtlasID reload(const(char)[] path)
	{
		auto index = resources.indexOf(path);
		if (index == -1) {
			logChnl.warn("Trying to reload non-loaded atlas: " ~ path);
			return load(path);
		}

		import std.path;
		auto tex = loadTextureAtlas(buildPath(resourceDir, path));
		resources.replace(tex, path);

		return TextureAtlasID(index);
	}

	static bool isLoaded(const(char)[] path)
	{
		import std.algorithm;
		return resources.indexOf(path) != -1;
	}	

	static ref TextureAtlas lookup(TextureAtlasID id)
	{
		return resources[id.index];
	}
}


private TextureAtlas loadTextureAtlas(const(char)[] path)
{
	import std.stdio, std.algorithm, allocation, 
		   math, std.conv, std.path, std.string,
		   content.texture;



	auto texPath = setExtension(path, ".png");
	auto texture = TextureManager.load(texPath);

	auto file = File(cast(string)path);
	auto num  = file.byLine().count;
	Table!(uint, float4) rects = Table!(uint, float4)(GC.it, num);
	
	file = File(cast(string)path);
	foreach(line; file.byLine())
	{
		auto ranges = line.findSplit(" = ");
		auto name = ranges[0];

		auto x = ranges[2].parse!uint;
		ranges[2].munch(" ");
		auto y = ranges[2].parse!uint;
		ranges[2].munch(" ");
		auto w = ranges[2].parse!uint;
		ranges[2].munch(" ");
		auto h = ranges[2].parse!uint;

		auto hs = bytesHash(name.ptr, name.length, 0);
		rects[hs] = float4(x, texture.height - y - h, w, h);
	}

	return TextureAtlas(texture, rects);
}