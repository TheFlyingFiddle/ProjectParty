module content.texture;

import graphics.common;
import graphics.texture;
import derelict.freeimage.freeimage;
import graphics.enums;
import std.traits;

Texture2D loadTexture(string path, int loadingParam = 0, Flag!"generateMipMaps" flag = Flag!"generateMipMaps".no)
{
	const(char*) c_str = path.toCString();
	FREE_IMAGE_FORMAT format = FreeImage_GetFileType(c_str);
	if(format == FIF_UNKNOWN)
	{
		format = FreeImage_GetFIFFromFilename(c_str);
	}


	FIBITMAP* bitmap = FreeImage_Load(format, c_str, 0);
	scope(exit) FreeImage_Unload(bitmap);

	uint width  = FreeImage_GetWidth(bitmap);
	uint height = FreeImage_GetHeight(bitmap);
	uint bpp    = FreeImage_GetBPP(bitmap);

	void* bits  = FreeImage_GetBits(bitmap);

	ColorFormat cFormat;
	ColorType   cType;
	InternalFormat iFormat;

	cFormat = bpp == 32 ? ColorFormat.rgba : 
			  bpp == 24 ? ColorFormat.rgb  : 
			  bpp == 16 ? ColorFormat.rgb  : ColorFormat.red;

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