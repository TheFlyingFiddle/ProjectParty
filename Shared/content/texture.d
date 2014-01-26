module content.texture;

import content;
import graphics.common;
import graphics.texture;
import derelict.freeimage.freeimage;
import graphics.enums;
import std.traits;
import util.hash;
import std.algorithm;
import logging;

struct TextureID
{
	private uint index;
	uint width;
	uint height;
}

struct TextureManager
{
	alias Table = ResourceTable!(Texture2D, graphics.texture.obliterate!Texture2D); 
	private static Table resources;

	static init(A)(ref A allocator, uint capacity)
	{
		resources = Table(allocator, capacity);

		import content.reloading;
		FileExtention[7] exts =
		[FileExtention.bmp,
		 FileExtention.dds,
		 FileExtention.jpg,
		 FileExtention.jp2,
		 FileExtention.png,
		 FileExtention.psd,
		 FileExtention.tiff];

		ContentReloader.registerReloader(exts, &auto_reload);
	}

	void auto_reload(const(char)[] path)
	{
		reload(path, 0, Flag!"generateMipMaps".no);
	}

	static TextureID load(const(char)[] path, int loadingParam = 0, 
				   Flag!"generateMipMaps" flag = Flag!"generateMipMaps".no)
	{
		auto index = resources.indexOf(path);
		if(index != -1)
			return TextureID(index, resources[index].width, resources[index].height);

		auto texture = loadTexture(path, loadingParam, flag);
		index = resources.add(texture, path);
		return TextureID(index, resources[index].width, resources[index].height);

	}

	static void unload(const(char)[] path)
	{
		resources.remove(path);
	}

	static TextureID reload(const(char)[] path, uint paramConfig = 0, 
					 Flag!"generateMipMaps" flag = Flag!"generateMipMaps".no)
	{
		auto index = resources.indexOf(path);
		if (index == -1) {
			warn("Trying to reload unloaded texture: " ~ path);
			return load(path);
		}
		
		auto tex = loadTexture(path, paramConfig, flag);
		resources.replace(tex, path);
		
		return TextureID(index, resources[index].width, resources[index].height);
	}

	static bool isLoaded(const(char)[] path)
	{
		import std.algorithm;
		return resources.indexOf(path) != -1;
	}	

	static Texture2D lookup(TextureID id)
	{
		return resources[id.index];
	}

}

private Texture2D loadTexture(const(char)[] path, uint paramConfig = 0, 
					  Flag!"generateMipMaps" flag = Flag!"generateMipMaps".no)
{
	import std.path;
	const(char*) c_str = buildPath(resourceDir, path).toCString();
	FREE_IMAGE_FORMAT format = FreeImage_GetFileType(c_str);
	if(format == FIF_UNKNOWN)
	{
		format = FreeImage_GetFIFFromFilename(c_str);
	}


	FIBITMAP* bitmap = FreeImage_Load(format, c_str, paramConfig);
	scope(exit) FreeImage_Unload(bitmap);

	uint width  = FreeImage_GetWidth(bitmap);
	uint height = FreeImage_GetHeight(bitmap);
	uint bpp    = FreeImage_GetBPP(bitmap);

	void* bits  = FreeImage_GetBits(bitmap);

	ColorFormat cFormat;
	ColorType   cType;
	InternalFormat iFormat;

	cFormat = bpp == 32 ? ColorFormat.bgra : 
	bpp == 24 ? ColorFormat.bgr  : 
	bpp == 16 ? ColorFormat.bgr  : ColorFormat.red;

	cType   = bpp == 32 ? ColorType.ubyte_ :
	bpp == 24 ? ColorType.ubyte_ :
	bpp == 16 ? ColorType.ushort_5_6_5 : ColorType.ubyte_;

	iFormat = bpp == 32 ? InternalFormat.rgba8 :
	bpp == 24 ? InternalFormat.rgb8  :
	bpp == 16 ? InternalFormat.rgb8  : InternalFormat.red8;

	return Texture2D.create(cFormat, cType, iFormat,
									width, height, bits[0 .. bpp / 8 * width * height],
									flag);
}