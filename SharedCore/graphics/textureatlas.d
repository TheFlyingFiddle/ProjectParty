module graphics.textureatlas;

import util.hash, collections.table, graphics.frame,
	   graphics.texture, math, std.algorithm;

struct SourceRect
{
	uint hash;
	float4 source;
}

struct TextureAtlas
{
	Texture2D _texture;
	uint length;
	SourceRect[1] _rects;

	private SourceRect[] rects()
	{
		return (cast(SourceRect*)_rects)[0 .. length];
	}

	@property Texture2D texture()
	{
		return _texture;
	}

	float4 opIndex(string name)
	{
		uint h = bytesHash(name);
		auto index = rects.countUntil!(x => x.hash == h);
		if(index != -1)
			return rects[index].source;

		import util.strings;
		assert(0, text1024("Frame not present in atlas : ", name));
	}

	Frame frame(string index)
	{
		return Frame(texture, this[index]);
	}

	int opApply(int delegate(uint, Frame) dg)
	{
		int result;
		foreach(i; 0 .. length)
		{
			result = dg(i, Frame(texture, rects[i].source));
			if(result) break;
		}
		return result;
	}

	@disable this(this); //No copying of this is very important not to copy this.
}