module content.texture;

import graphics;
import derelict.freeimage.freeimage;
import concurency.task;

package Texture2D loadTexture(const(char)* c_path, uint paramConfig = 0, 
							  bool flag = false, bool async = false,
							  ColorFormat cFormat = ColorFormat.bgra)
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

	ColorType   cType	   = ColorType.ubyte_;
	InternalFormat iFormat = InternalFormat.rgba8;

	Texture2D result;
	if(async)
	{
		result = doTaskOnMain!(Texture2D.create)(cFormat, cType, iFormat,
								  width, height, bits[0 .. 4 * width * height],
								  flag);

	}
	else 
	{
		result = Texture2D.create(cFormat, cType, iFormat,
								  width, height, bits[0 .. 4 * width * height],
								  flag);
	}

	return result;
}