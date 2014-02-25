module content.texture;

import content.common, content.reloading;
import util.strings;
import graphics.texture;
import derelict.freeimage.freeimage;
import graphics.enums;
import std.traits;
import util.hash;
import std.algorithm;
import logging;


private LogChannel logChnl = LogChannel("RESOURCES.TEXTURE");

struct TextureID
{
	private uint index;

	@property uint width()
	{
		return TextureManager.lookup(this).width;
	}

	@property uint height()
	{
		return TextureManager.lookup(this).height;
	}

	@property Texture2D texture()
	{
		return TextureManager.lookup(this);
	}

	static TextureID invalid()
	{
		return TextureID(uint.max);
	}
}

package: 

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

		ContentReloader.registerReloader(AssetType.texture, exts, &auto_reload);
	}

	static void shutdown()
	{
		foreach(ref resource; resources)
			resource.obliterate();
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
			return TextureID(index);


		import std.path;
		const(char)* c_path = buildPath(resourceDir, path).toCString();

		auto texture = loadTexture(c_path, loadingParam, flag);
		index = resources.add(texture, path);
		return TextureID(index);

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
			logChnl.warn("Trying to reload non-loaded texture: " ~ path);
			return load(path);
		}

		import std.path;
		const(char)* c_path = buildPath(resourceDir, path).toCString();

		auto tex = loadTexture(c_path, paramConfig, flag);
		resources.replace(tex, path);
		
		return TextureID(index);
	}

	static bool isLoaded(const(char)[] path)
	{
		import std.algorithm;
		return resources.indexOf(path) != -1;
	}	

	static ref Texture2D lookup(TextureID id)
	{
		return resources[id.index];
	}

}

private Texture2D loadTexture(const(char)* c_path, uint paramConfig = 0, 
					  Flag!"generateMipMaps" flag = Flag!"generateMipMaps".no)
{
	FREE_IMAGE_FORMAT format = FreeImage_GetFileType(c_path);
	if(format == FIF_UNKNOWN)
	{
		format = FreeImage_GetFIFFromFilename(c_path);
	}

	FIBITMAP* bitmap = FreeImage_Load(format, c_path, paramConfig);
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

