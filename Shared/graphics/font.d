module graphics.font;

import math;
import std.exception;
import graphics.frame;


struct CharInfo
{
	float4 textureCoords;
	float4 srcRect;
	float2 offset;
	float  advance;
}

struct Font
{
	enum wchar unkownCharValue = '\u00A5';
	enum tabSpaceCount = 4;

	float size;
	float lineHeight;
	Frame page;
	CharInfo[] chars;

	this(float size, float lineHeight, Frame page, CharInfo[] chars)
	{
		this.size		 = size;
		this.lineHeight = lineHeight;
		this.page		 = page;
		this.chars		 = chars;

		import std.conv;
		enforce(chars[unkownCharValue] != CharInfo.init,
				"Unkown character (" ~ unkownCharValue.to!string ~ " missing from the font!");
	}

	ref CharInfo opIndex(dchar c)
	{
		//For some reason this would allocate
		//If put in the if statement.
		CharInfo i = CharInfo.init;

		if(chars.length > c && chars[c] != i)
			return chars[c];

		return chars[unkownCharValue];
	}
}