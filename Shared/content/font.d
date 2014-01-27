module content.font;

import graphics.font;
import graphics.frame;
import math;
import std.exception;
import content.texture;
import content;


unittest
{
	import allocation;
	auto path = r"C:\Git\ProjectParty\resources\fonts\Arial32.fnt";
	auto allocator = Mallocator.it;
	Font f = loadFont(allocator, path);

	auto x = f.lineHeight;
}

struct FontID
{
	private uint index;
}

//struct FontManager 
//{
//    alias Table = ResourceTable!(Font, obliterateFont);
//    private Table resources;
//    private IAllocator fontAllocator;
//
//    void init(A)(ref A allocator, IAllocator fAllocator, size_t capacity)
//    {
//        resources	  = Table(allocator, capacity);
//        fontAllocator = fAllocator;
//
//        ContentReloader.registerReloader(FileExtention.fnt, &auto_reloader);
//    }
//
//    FontID load(const(char[]) path)
//    {
//        auto index = resources.indexOf(path);
//        if(index == -1)
//            return index;
//
//        auto font = loadFont(fontAllocator, path);
//        index = resources.add(font, path);
//        return FontID(index);
//    }
//
//    void unload(const(char[]) path)
//    {
//        resources.remove(path);
//    }
//    
//    void reload(const(char[]) path)
//    {
//        auto index = resouces.indexOf(path);
//        if(index == -1) {
//            return load(path);
//        }
//    }
//}


Font loadFont(A)(ref A allocator, string filePath)
{
	import allocation;
	import std.file, collections.blob;
	auto data = read(filePath);
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
				enforce(cHeader.pages == 1, "Currently fonts are only allowed to have one texture assoiated with them!");
				break;
			case BlockType.pages:			
				pageName = cast(char[])blob.readBytes(size)[0 .. $ - 1];
				break;
			case BlockType.chars:
				rawCharInfo = cast(CharRaw[])blob.readBytes(size);
				break;
			case BlockType.kerningPairs:
				kerningInfo = cast(KerningPair[])blob.readBytes(size);
				break;
			default:
				assert(0, "Font file " ~ filePath ~ " is corrupt.");
		}
	}

	
	import std.path;

	auto texturePath = buildPath(filePath.dirName, pageName); 

	auto texID = TextureManager.load(texturePath);
	Frame page = Frame(texID);

	size_t min = size_t.max, max = 0;
	foreach(ref r; rawCharInfo)
	{
		if(r.id < min) min = r.id;
		if(r.id > max) max = r.id;
	}

	//Do we need the min? It could save some space but gives runtime lookup overhead.
	CharInfo[] chars = allocate!(A,CharInfo[])(allocator, max + 1); //We must allocate here there is no way around it.
	chars[] = CharInfo.init;

	//Transform the raw characters to CharInfo structs.
	foreach(r; rawCharInfo)
	{
		float advance   = r.xAdvance;
		float4 srcRect  = float4(r.x, page.texture.height - r.y, r.width, -r.height); 
		float2 offset   = float2(r.xOffset, cHeader.base - r.yOffset);
		float4 texCoord = float4(page.coords.x + srcRect.x / page.texture.width,
								 page.coords.y + srcRect.y / page.texture.height,
								 page.coords.x + (srcRect.z + srcRect.x) / page.texture.width,
								 page.coords.y + (srcRect.w + srcRect.y) / page.texture.height);

		chars[r.id] = CharInfo(texCoord, srcRect, offset, advance);
	}

	//Delete memory gotten from read. Here but how?
	

	return Font(iHeader.fontSize, cHeader.lineHeight, page, chars);
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