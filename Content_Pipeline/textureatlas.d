module textureatlas;

import derelict.freeimage.freeimage;
import content.sdl, 
	   util.hash, 
	   allocation, 
	   std.path, 
	   std.array,
	   std.file,
	   compilers,
	   std.algorithm,
	   main,
	   std.conv;

struct Image
{
	uint width, height;
	uint[] data;
	FIBITMAP* bitmap;
	string name;

	uint area() { return width * height; }
}

struct AtlasImage
{
	Image image;
	SourceRect[] rects;
}

struct SourceRect
{
	string name;
	uint bottom, left, right, top;
}

void copySubImage(ref Image to, ref Image from, 
				  uint bottom, uint left)
{
	foreach(row; 0 .. from.height)
	{
		auto aLeft = (row + bottom) * to.width + left;
		to.data[aLeft .. aLeft + from.width] = from.data[row * from.width .. row * from.width + from.width]; 
	}
}

Image loadImage(string path)
{
	FREE_IMAGE_FORMAT format = FreeImage_GetFileType(path.ptr);
	if(format == FIF_UNKNOWN)
	{
		format = FreeImage_GetFIFFromFilename(path.ptr);
	}


	FIBITMAP* bitmap = FreeImage_Load(format, path.ptr, 0);
	scope(exit) FreeImage_Unload(bitmap);

	FIBITMAP* bitmap32 = FreeImage_ConvertTo32Bits(bitmap);

	auto width  = FreeImage_GetWidth(bitmap32);
	auto height = FreeImage_GetHeight(bitmap32);
	auto bits   = FreeImage_GetBits(bitmap32);
	return Image(width, height, (cast(uint*)bits)[0 .. width * height], bitmap32);
}

void freeImages(Image[] images)
{
	foreach(image; images) FreeImage_Unload(image.bitmap);
}

struct AtlasConfig
{
	string[] items;
	uint width, height;
}

CompiledFile compileAtlas(void[] data, DirEntry file, ref Context context)
{
	auto atlasConfig = fromSDLSource!AtlasConfig(Mallocator.it, cast(string)data);

	auto root = file.name[context.inFolder.length + 1 .. $ - baseName(file.name).length];
	auto itemIDs = atlasConfig.items.map!(x => buildPath(root, x)).array;
	foreach(item; itemIDs)
	{
		context.usedNames ~= stripExtension(item);
	}

	auto atlas			= createAtlas(atlasConfig, file);

	import util.bitmanip;
	if(context.platform == Platform.desktop)
	{
		auto atlasMetaData	= new ubyte[atlas.rects.length * uint.sizeof * 5];

		size_t offset = 0;		
		foreach(i, r; atlas.rects)
		{
			atlasMetaData.write!uint(bytesHash(r.name.ptr, r.name.length).value, &offset);
			atlasMetaData.write!float(r.left, &offset);
			atlasMetaData.write!float(r.bottom, &offset);
			atlasMetaData.write!float(r.right - r.left, &offset);
			atlasMetaData.write!float(r.top - r.bottom, &offset);
		}

		return CompiledFile([CompiledItem(".atlas", atlasMetaData), 
							CompiledItem(".png"	 , atlas.data)],
							itemIDs);
	}
	else if(context.platform == Platform.phone)
	{
		auto name = file.name[context.inFolder.length + 1 .. $ - file.name.extension.length];

		string luaCode = "local atlas = { }";
		luaCode ~= "\natlas.frame  = Loader.loadFrame(\"" ~ name ~ "\")";
		luaCode ~= "\natlas.width  = " ~ atlasConfig.width.to!string;
		luaCode ~= "\natlas.height = " ~ atlasConfig.width.to!string;
		
		foreach(r; atlas.rects)
		{
			luaCode ~= text("\natlas.", r.name, " = Rect2(", r.bottom, ",", 
							r.left, ",", r.right, ",", r.top, ")");
		}

		luaCode ~= "\nreturn atlas";

		return CompiledFile([CompiledItem(".luac", cast(void[])luaCode),
							 CompiledItem(".png", atlas.data)],
							itemIDs);
	} else 
		assert(0, "Not yet implemented!");
}	

auto createAtlas(AtlasConfig config, DirEntry file)
{
	Image[] images;
	foreach(item; config.items.map!(x => Tuple!(string, string)(stripExtension(x),
															  buildPath(dirName(file.name), x ~ "\0"))))
	{
		Image image = loadImage(item[1]);
		image.name  = item[0];
		images ~= image;
	}

	auto result = buildAtlas(images, config.width, config.height);
	freeImages(images);

	auto bitmap = FreeImage_ConvertFromRawBits(cast(ubyte*)result.image.data.ptr, config.width, config.height,
											   config.width * 4, 32, 8, 8, 8, false);
	scope(exit) FreeImage_Unload(bitmap);

	FreeImageIO io;
	io.read_proc  = &readData;
	io.write_proc = &writeData;
	io.seek_proc  = &seekData;
	io.tell_proc  = &tellData;

	ArrayHandle handle = ArrayHandle(0, buffer);
	FreeImage_SaveToHandle(FIF_PNG, bitmap, &io, cast(fi_handle)&handle, 0); 

	struct AtlasResult
	{
		void[] data;
		SourceRect[] rects;
	}
	return AtlasResult(handle.array[0 .. handle.position], result.rects);
}


struct AtlasNode
{
	AtlasNode*[2] child;
	uint bottom, left, right, top;
	int type = -1;
	static AtlasImage* atlas;

	this(uint bottom, uint left, uint right, uint top, uint type)
	{
		this.bottom = bottom;
		this.left   = left;
		this.right  = right;
		this.top    = top;
		this.type   = type;
	}

	uint width() { return right - left; }
	uint height() { return top - bottom; }

	AtlasNode* insert(ref Image image)
	{
		if(type == 0)
		{
			auto newNode = child[0].insert(image);
			if(newNode == null)
				return child[1].insert(image);
			else 
				return newNode;
		}

		//Already full leaf node
		if(type == 1) return null;

		if(image.width == this.width && image.height == this.height)
		{
			copySubImage(atlas.image, image, bottom, left);
			atlas.rects ~= SourceRect(image.name, this.bottom, this.left, this.right, this.top);

			type = 1;
			return &this;
		}

		if(image.width  > this.width || 
		   image.height > this.height)
			return null;

		auto dw = width  - image.width;
		auto dh = height - image.height;

		if(dw > dh)
		{
			child[0] = new AtlasNode(bottom, left,
								left + image.width,
								top, 2);

			child[1] = new AtlasNode(bottom, left + image.width,
								right,
								top, 2);
		}
		else 
		{
			child[0] = new AtlasNode(bottom, left,
								right, bottom + image.height, 2);

			child[1] = new AtlasNode(bottom + image.height, left,
								right,
								top, 2);
		}

		this.type = 0;
		return child[0].insert(image);
	}
}

AtlasImage buildAtlas(Image[] images, uint maxWidth, uint maxHeight)
{
	AtlasImage atlas = AtlasImage(Image(maxWidth, maxHeight, new uint[maxWidth * maxHeight]));
	AtlasNode.atlas = &atlas;

	auto start = new AtlasNode(0, 0, maxWidth, maxHeight, 2);
	images.sort!((a,b) => a.area > b.area);
	foreach(image; images) {
		assert(start.insert(image), text("Failed to insert image when creating atlas! ", image.name));
	}

	return atlas;
}