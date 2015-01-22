module content.texture;

import graphics;
import derelict.freeimage.freeimage;
import concurency.task;
import allocation;

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

struct FrameLoader
{
	static Frame* load(IAllocator allocator, string path, bool async)
	{
		import util.strings;
		auto tex = loadTexture(text1024(path, '\0').ptr, 0, false, async);
		Frame* frame = allocator.allocate!Frame(tex);
		return frame;		
	}

	static void unload(IAllocator allocator, Frame* frame)
	{
		frame.texture.obliterate();
		auto data = cast(void*)frame;
		allocator.deallocate(data[0 .. Frame.sizeof]);
	}
}