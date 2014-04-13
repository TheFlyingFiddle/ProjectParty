module graphics.textureatlas;

import util.hash, collections.table, content.texture, graphics.frame, math;


void obliterate(ref TextureAtlas atlas)
{

}

struct TextureAtlas
{
	TextureID _texture;
	Table!(uint, float4) frames;

	@property TextureID texture()
	{
		return _texture;
	}

	ref float4 opIndex(string index)
	{
		uint h = bytesHash(index.ptr, index.length, 0);
		auto p = h in frames;
		if(p) return *p;

		import std.conv;
		assert(0, text("Texture not present in atlas : ", index));
	}

	Frame frame(string index)
	{
		return Frame(texture, this[index]);
	}
}