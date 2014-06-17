module content.font;

import allocation, graphics, math, content.texture;
import util.strings;
import content.texture;
import std.path, std.stdio;

struct FontLoader
{
	static Font* load(IAllocator allocator, string path, bool async)
	{
		auto file = File(path, "rb");
		auto data = allocator.allocateRaw(cast(uint)file.size + Texture2D.sizeof, 8);
		file.rawRead(data[Texture2D.sizeof .. $]);


		auto texPath = text1024(path[0 .. $ - path.extension.length], ".png", "\0");
		auto texture = loadTexture(texPath.ptr, 0, false, async);

		auto font  = cast(Font*)data;
		font.page  = texture;
		return font;
	}

	static void unload(IAllocator allocator, Font* item)
	{
		item.page.obliterate();
		auto data = cast(void*)item;
		allocator.deallocate(data[0 .. Font.sizeof + (item.charInfoLength - 1) * CharInfo.sizeof]);
	}
}