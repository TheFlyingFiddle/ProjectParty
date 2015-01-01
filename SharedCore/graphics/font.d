module graphics.font;

import math;
import graphics.texture;
import util.hash;
import std.algorithm;


struct CharInfo
{
	float4 textureCoords;
	float4 srcRect;
	float2 offset;
	float  advance;
}


struct FontAtlas
{
	Texture2D page;
	Font[] fonts;

	ref Font opIndex(string s)
	{
		auto id = bytesHash(s);
		auto index = fonts.countUntil!(x => x.hashID == id);
		if(index != -1)
		{
			return fonts[index];
		}

		assert(false, "Failed to find font! " ~ s);
	}

	ref Font opIndex(HashID id)
	{
		auto index = fonts.countUntil!(x => x.hashID == id);
		if(index != -1)
		{
			return fonts[index];
		}

		import std.conv;
		assert(false, text("Failed to find font! ", id));
	}
}

struct Font
{
	enum wchar unkownCharValue = '\u002F';
	enum tabSpaceCount = 4;

	float size;
	float lineHeight;
	CharInfo[] chars;

	Texture2D page;
	uint layer;
	HashID hashID;

	ref CharInfo opIndex(dchar c)
	{
		//For some reason this would allocate
		//If put in the if statement.
		CharInfo i = CharInfo.init;
		if(chars.length > c && chars[c] != i)
			return chars[c];

		return chars[unkownCharValue];
	}
	
	float2 measure(const(char)[] text)
	{
		import std.math;
		float charHeight = 0;
		float width = 0, height = 0, cursor = 0;

		foreach(dchar c; text)
		{
			if(c == '\r') continue;

			if(c == ' ') {
				CharInfo spaceInfo = this[' '];
				cursor += spaceInfo.advance;
				continue;
			}	else if(c == '\n') {
				height += lineHeight;
				width   = fmax(cursor, width);
				cursor = 0;
				continue;
			} else if(c == '\t') {
				CharInfo spaceInfo = this[' '];
				cursor += spaceInfo.advance * tabSpaceCount;
				continue;
			}

			CharInfo info = this[c];
			cursor += (info.advance);
			charHeight = max(charHeight, info.srcRect.w);
		}

		width = fmax(width, cursor);

		if(height == 0)
			return float2(width, charHeight) / size;
		else
			return float2(width, height + size) / size;
	}

}

struct Measure
{
	int index, codepoint;
	float2 size;
}

auto measureUntil(alias pred)(ref Font font, const(char)[] input)
{
	import std.math, std.utf;
	float width = 0, height = 0, cursor = 0;
	uint index = 0, codepoint = 0;

	char[] text = cast(char[])input;
	while(index < input.length)
	{
		dchar c = decode(text, index);
		codepoint++;

		if(c == '\r') continue;

		CharInfo info;
		if(c == '\n') {
			height += font.lineHeight;
			width   = fmax(cursor, width);
			cursor = 0;
		} else if(c == '\t') {
			info = font[' '];
			cursor += info.advance * font.tabSpaceCount;
		} else {
			info = font[c];
			cursor += (info.advance);
		}
		
		if(pred(float2(fmax(width, cursor), height + font.size) / font.size, float2(info.advance, info.srcRect.w) / font.size))
			return  Measure(index, codepoint, float2(fmax(width, cursor), height + font.size) / font.size);
	}

	return  Measure(-1, codepoint, float2(fmax(width, cursor), height + font.size) / font.size);
}
