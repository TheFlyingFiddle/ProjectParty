module content.font;

import allocation, graphics, math, content.texture;
import util.strings;
import content.texture;
import std.path, std.stdio;
import util.hash;

struct FontLoader
{
	struct FontHeader
	{
		float size, lineHeight;
		uint  dataOffset, dataLength;
		uint layer, hashID;
	}

	static FontHeader[] loadHeader(ref File file, ubyte[] store)
	{
		ushort[1] count;
		file.rawRead(count[]);
		file.rawRead(store[0 .. count[0] * FontHeader.sizeof]);

		return (cast(FontHeader*)(store.ptr))[0 .. count[0]];
	}


	static FontAtlas* load(IAllocator allocator, string path, bool async)
	{
		ubyte[1024] buffer = void;
		auto file = File(path, "rb");
		auto header = loadHeader(file, buffer[]);


		auto texPath = text1024(path[0 .. $ - path.extension.length], ".png", "\0");
		auto texture = loadTexture(texPath.ptr, 0, false, async, ColorFormat.rgba);

		int dataSize = FontAtlas.sizeof + Font.sizeof * header.length;
		int length = dataSize;
		foreach(font; header)
			length += font.dataLength * CharInfo.sizeof;

		auto data = allocator.allocateRaw(length, 8);
		file.rawRead(data[dataSize .. $]);

		auto atlas  = cast(FontAtlas*)data;
		atlas.page  = texture;
		atlas.fonts = cast(Font[])(data[FontAtlas.sizeof .. dataSize]);
		foreach(i, ref font; atlas.fonts)
		{
			font.size		= header[i].size;
			font.lineHeight = header[i].lineHeight;
			font.page       = atlas.page;
			font.hashID		= HashID(header[i].hashID);
			
			int start = dataSize + header[i].dataOffset;
			int end   = start + header[i].dataLength * CharInfo.sizeof;

			font.chars = cast(CharInfo[])(data[start .. end]);
			font.layer = header[i].layer;
		}

		return atlas;
	}

	static void unload(IAllocator allocator, FontAtlas* item)
	{
		item.page.obliterate();
		auto data = cast(void*)item;
		allocator.deallocate(data[0 .. 1]); //Length is irrelevant... Shoudl fix this
	}
}