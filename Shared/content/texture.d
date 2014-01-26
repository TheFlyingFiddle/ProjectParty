module content.texture;

import graphics.common;
import graphics.texture;
import derelict.freeimage.freeimage;
import graphics.enums;
import std.traits;
import util.hash;
import collections.list;
import logging;

struct TextureID
{
	private uint index;
	private uint idHash;
	uint width;
	uint height;
}

struct TextureManager
{
	private static List!Texture2D	textures;
	private static List!uint		ids;
 
	static init(A)(ref A allocator, uint capacity)
	{
		textures = List!Texture2D(allocator, capacity);
		ids = List!uint(allocator, capacity);
	}

	static TextureID load(string path, int loadingParam = 0, 
				   Flag!"generateMipMaps" flag = Flag!"generateMipMaps".no)
	{
		auto texture = loadTexture(path, loadingParam, flag);
		return addToTextures(texture, path);
	}
	
	static private TextureID addToTextures(Texture2D texture, string path)
	{
		auto hash = bytesHash(path.ptr, path.length);
		foreach(i, t; textures) {
			if (t.glName == 0) {
				auto id = TextureID(i, hash, texture.width, texture.height);
				textures[i] = texture;
				ids ~= hash;
				return id;
			}
		}
		textures ~= texture;
		ids ~= hash;
		
		return TextureID(textures.length-1, hash, texture.width, texture.height);
	}

	static void unload(TextureID id)
	{
		auto texture = textures[id.index];
		if (texture.glName == 0) {
			warn("Trying to remove non-existant texture");
			return;
		}
		texture.obliterate();
		textures[id.index] = Texture2D(0,0,0);
		ids[id.index] = 0;
	}

	static TextureID reload(string path, uint paramConfig = 0, 
					 Flag!"generateMipMaps" flag = Flag!"generateMipMaps".no)
	{
		auto hash = bytesHash(path.ptr, path.length);
		auto index = ids.countUntil!(x => x == hash);
		if (index == -1) {
			warn("Trying to reload unloaded texture: " ~ path);
			return load(path);
		}
		
		textures[index].obliterate();
		textures[index] = loadTexture(path, paramConfig, flag);
		return TextureID(index, hash, 
						 textures[index].width, textures[index].height);
	}

	static Texture2D lookup(TextureID id)
	{
		return textures[id.index];
	}
}

private Texture2D loadTexture(string path, uint paramConfig = 0, 
					  Flag!"generateMipMaps" flag = Flag!"generateMipMaps".no)
{
	const(char*) c_str = path.toCString();
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