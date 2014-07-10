module font;

import allocation;
import main, compilers;
import std.file, collections.blob;
import math;
import log;

import std.stdio;

CompiledFile compileFont(void[] data, DirEntry path, ref Context context)
{		
	auto blob = Blob(data.ptr, data.length, data.length);
	//Read first four bytes
	assert(blob.readBytes(3) == "BMF");
	assert(blob.read!(ubyte) == 3);

	InfoHeader    iHeader;
	char[]        fontName;
	CommonHeader  cHeader;
	char[]        pageName;
	CharRaw[]     rawCharInfo;
	KerningPair[] kerningInfo;

	while(!blob.empty)
	{
		ubyte type = blob.read!(ubyte);
		uint  size = blob.read!(uint);

		switch(type)
		{
			case BlockType.info:
				iHeader = blob.read!(InfoHeader);
				fontName = cast(char[])blob.readBytes(size - InfoHeader.sizeof);
				break;
			case BlockType.common:
				cHeader = blob.read!(CommonHeader);
				assert(cHeader.pages == 1, "Currently fonts are only allowed to have one texture assoiated with them!");
				break;
			case BlockType.pages:			
				pageName = cast(char[])blob.readBytes(size)[0 .. $ - 1];
				logInfo(pageName);
				break;
			case BlockType.chars:
				rawCharInfo = cast(CharRaw[])blob.readBytes(size);
				break;
			case BlockType.kerningPairs:
				kerningInfo = cast(KerningPair[])blob.readBytes(size);
				break;
			default:
				assert(0, "Font file " ~ path ~ " is corrupt.");
		}
	}


	import std.path;
	auto imagePath  = buildPath(path.name.dirName, pageName); 
	auto imageEntry = DirEntry(imagePath);
	auto imageData  = read(imageEntry.name);
	
	size_t min = size_t.max, max = 0;
	foreach(ref r; rawCharInfo)
	{
		if(r.id < min) min = r.id;
		if(r.id > max) max = r.id;
	}

	//Do we need the min? It could save some space but gives runtime lookup overhead.
	CharInfo[] chars = new CharInfo[(max + 1)];
	chars[] = CharInfo.init;

	//Transform the raw characters to CharInfo structs.
	foreach(r; rawCharInfo)
	{
		float advance   = r.xAdvance;
		float4 srcRect  = float4(r.x, cHeader.scaleH - r.y, r.width, -r.height); 
		float2 offset   = float2(r.xOffset, cHeader.base - r.yOffset);
		float4 texCoord = float4(srcRect.x / cHeader.scaleW,
								 srcRect.y / cHeader.scaleH,
								 (srcRect.z + srcRect.x) / cHeader.scaleW,
								 (srcRect.w + srcRect.y) / cHeader.scaleH);

		chars[r.id] = CharInfo(texCoord, srcRect, offset, advance);
	}


	auto fontData = new ubyte[float.sizeof * 3 + CharInfo.sizeof * chars.length];
	import util.bitmanip;

	size_t offset = 0;
	fontData.write!float(iHeader.fontSize, &offset);
	fontData.write!float(cHeader.base, &offset);
	fontData.write!float(cHeader.lineHeight, &offset);
	fontData[offset .. $] = cast(ubyte[])(chars);

	auto image		= compileImage(imageData, imageEntry, context);
	auto dependent = buildPath(path.name.dirName, pageName)[context.inFolder.length + 1 .. $];
	dependent = setExtension(dependent, image.items[0].extension);

	context.usedNames ~= stripExtension(dependent);
	return CompiledFile([CompiledItem(".fnt", fontData), image.items[0]], [dependent]);
}


struct CharInfo
{
	float4 textureCoords;
	float4 srcRect;
	float2 offset;
	float  advance;
}

align(1)
{
	struct InfoHeader
	{
		short fontSize;
		ubyte bitField;
		ubyte charSet;
		short stretchH;
		ubyte aa;
		ubyte paddingUp;
		ubyte paddingRight;
		ubyte paddingDown;
		ubyte paddingLeft;
		ubyte spacingHoriz;
		ubyte spacingVert;
		ubyte outline;
	}

	struct CommonHeader
	{
		short lineHeight;
		short base;
		short scaleW;
		short scaleH;
		short pages;
		ubyte bitField;
		ubyte alphaChan;
		ubyte redChan;
		ubyte greenChan;
		ubyte blueChan;
	}

	struct CharRaw
	{
		uint id;
		short x;
		short y;
		short width;
		short height;
		short xOffset;
		short yOffset;
		short xAdvance;
		ubyte page;
		ubyte chan;
	}

	struct KerningPair
	{
		uint first;
		uint second;
		short amount;
	}

	enum BlockType
	{
		info   = 1,
		common = 2,
		pages  = 3,
		chars  = 4,
		kerningPairs = 5
	}
}