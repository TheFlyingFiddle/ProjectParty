module content.textureatlas;

import 
	allocation, 
	util.hash,
	std.path,
	graphics,
	content.texture;

struct TextureAtlasLoader
{
	static TextureAtlas* load(IAllocator allocator, string path, bool async) 
	{
		import std.stdio, util.strings;

		auto file = File(path, "rb");
		auto data = allocator.allocateRaw(cast(uint)file.size + TextureAtlas.sizeof, 8);
		file.rawRead(data[TextureAtlas.sizeof .. $]);

		auto texPath = text1024(path[0 .. $ - path.extension.length], ".png", "\0");
		Texture2D texture = loadTexture(texPath.ptr, 0, false, async);

		TextureAtlas* atlas = cast(TextureAtlas*)data;
		atlas._texture = texture;
		atlas.rects = cast(SourceRect[])(data[TextureAtlas.sizeof  .. $]);
		return atlas;
	}

	static void unload(IAllocator allocator, TextureAtlas* item)
	{
		//We destroy the texture here!
		item._texture.obliterate();
		auto data = cast(void*)item;
		allocator.deallocate(data[0 .. TextureAtlas.sizeof + item.rects.length * SourceRect.sizeof]);
	}
}
