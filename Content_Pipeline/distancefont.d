module distancefont;

import derelict.freetype.ft;
import derelict.freetype.types;
import derelict.freeimage.freeimage;

import std.file;
import std.path;
import compilers;
import util.bitmanip;
import main;
import math;
import std.string;

struct CharInfo
{
	float4 textureCoords;
	float4 srcRect;
	float2 offset;
	float  advance;
}

struct RawCharInfo
{
	uint id, x, y, w, h;
	float xo, yo, xa;
}

struct Data
{
	uint size, width, height, max, count;
	RawCharInfo[] chars;	
}

CompiledFile compileDistFont(void[] input, DirEntry path, ref Context context)
{
	int imageWidth = 256, imageHeight = 256;

	auto typed = cast(ubyte[])input;

	sdf_glyph[] all_glyphs;
	int fontSize;
	auto imageData = render_signed_distance_font(ft_lib, 
											all_glyphs,
											fontSize,
											path.name.toStringz(),
											imageWidth,
											256);


	if(context.platform == Platform.phone)
		flipImage(cast(uint[])imageData, imageWidth, imageHeight);

	CharInfo[] infos = new CharInfo[256];
	foreach(i, r; all_glyphs)
	{

		CharInfo info;
		info.advance  = r.xadv;
		info.srcRect  = float4(r.x, imageHeight - r.y - r.height, r.width, r.height);
		info.offset   = float2(r.xoff, fontSize - info.srcRect.w + r.yoff);
		info.textureCoords = float4(info.srcRect.x / imageWidth,
									info.srcRect.y / imageHeight,
									(info.srcRect.z + info.srcRect.x) / imageWidth,
									(info.srcRect.w + info.srcRect.y) / imageHeight);

		infos[r.ID] = info;
	}

	auto fontData = new ubyte[float.sizeof * 3 + CharInfo.sizeof * infos.length];


	size_t offset = 0;

	fontData.write!float(fontSize, &offset);
	fontData.write!float(fontSize, &offset);
	fontData.write!float(fontSize * 1.2, &offset);
	fontData[offset .. $] = cast(ubyte[])(infos);


	FreeImageIO io;
	io.read_proc  = &readData;
	io.write_proc = &writeData;
	io.seek_proc  = &seekData;
	io.tell_proc  = &tellData;

	auto saveHandle = ArrayHandle(0, compilers.buffer);

	auto image = FreeImage_ConvertFromRawBits(imageData.ptr, 256, 256, ((32 * 256 + 31) / 32) * 4, 32, 8, 8, 8, true);
	scope(exit) FreeImage_Unload(image);

	FreeImage_SaveToHandle(FIF_PNG, image, &io, cast(fi_handle)&saveHandle, 0);

	return CompiledFile([CompiledItem(".fnt", fontData), CompiledItem(".png", compilers.buffer[0 .. saveHandle.position])], []);	
}


struct sdf_glyph
{
	int ID;
	int width, height;
	int x, y;
	float xoff, yoff;
	float xadv;
}

enum scaler = 16;

ubyte[] render_signed_distance_font(ref FT_Library ft_lib,
									ref sdf_glyph[] all_glyphs,
									ref int fontSize,
								    const char* font_file,
								    int texture_size,
								    int max_unicode_char) 
{

	import std.range, std.algorithm;

	FT_Face ft_face;
	int ft_err = FT_New_Face(ft_lib, font_file, 0, &ft_face);
	assert(!ft_err, "Failed to load font file!");
	
	auto render_list = iota(0, max_unicode_char).array;


	fontSize = 4;
	bool keep_going = true;
	while(keep_going)
	{
		fontSize *= 2;
		keep_going = gen_pack_list( ft_face, fontSize, texture_size, max_unicode_char, all_glyphs);
	}	
	
	int low = fontSize / 2, high = fontSize;
	fontSize = (low + high) / 2;
	while(true)
	{
		bool success = gen_pack_list( ft_face, fontSize, texture_size, max_unicode_char, all_glyphs);
		if(success)
		{
			low = fontSize;
			fontSize = (fontSize + high) / 2;
			if(fontSize == low) break;
		}
		else 
		{
			fontSize = (low + fontSize) / 2;
			if(fontSize == low) 
			{
				fontSize = low;
				gen_pack_list( ft_face, fontSize, texture_size, max_unicode_char, all_glyphs);
				break;
			}
		}
	}


	assert(!keep_going, "Failed to fit font in texture!");


	FT_Set_Pixel_Sizes(ft_face, fontSize * scaler, 0);
	auto pdata = new ubyte[ 4 * texture_size * texture_size];
	int packed_glyph_index = 0;
	foreach(sdlGlyph; all_glyphs)
	{
		int glyph_index = FT_Get_Char_Index( ft_face, sdlGlyph.ID );
		if( glyph_index )
		{	
			ft_err = FT_Load_Glyph( ft_face, glyph_index, 0 );
			ft_err = FT_Render_Glyph( ft_face.glyph, FT_Render_Mode.FT_RENDER_MODE_MONO );

			int w = ft_face.glyph.bitmap.width;
			int h = ft_face.glyph.bitmap.rows;
			int p = ft_face.glyph.bitmap.pitch;

			int sw = w + scaler * 4;
			int sh = h + scaler * 4;
					
			ubyte[] smooth_buf;
			smooth_buf.length = sw * sh;
			smooth_buf[] = 0;

			ubyte* buf = cast(ubyte*)ft_face.glyph.bitmap.buffer;
			foreach(j; 0 .. h)
			{
				foreach(i; 0 .. w)
				{
					int index = scaler * 2 + i + (j + scaler * 2) * sw;
					auto wtf   = ((buf[j * p + (i >> 3)] >> (7 - (i & 7))) & 1);
					smooth_buf[index] = cast(ubyte)(255 * wtf);
				}
			}

			foreach(j; 0 .. sdlGlyph.height)
			{
				foreach(i; 0 .. sdlGlyph.width)
				{
					int pd_idx = (i + sdlGlyph.x + (j + sdlGlyph.y) * texture_size) * 4;
					pdata[pd_idx] = get_SDF_radial(
										smooth_buf, sw, sh,
										i * scaler + (scaler / 2), 
										j * scaler + (scaler / 2),
										2 * scaler);

					pdata[pd_idx + 1] = pdata[pd_idx];
					pdata[pd_idx + 2] = pdata[pd_idx];
					pdata[pd_idx + 3] = pdata[pd_idx];
				}
			}
		}
	}

	FT_Done_Face( ft_face );

	return pdata;
}

ubyte get_SDF_radial(ubyte[] fontmap,
					 int w, int h,
					 int x, int y,
					 int max_radius )
{

	//	hideous brute force method
	float d2 = cast(float)(max_radius*max_radius+1.0);
	ubyte v = fontmap.ptr[x+y*w];
	for( int radius = 1; (radius <= max_radius) && (radius*radius < d2); ++radius )
	{
		int line, lo, hi;
		//	north
		line = y - radius;
		if( (line >= 0) && (line < h) )
		{
			lo = x - radius;
			hi = x + radius;
			if( lo < 0 ) { lo = 0; }
			if( hi >= w ) { hi = w-1; }
			int idx = line * w + lo;
			for( int i = lo; i <= hi; ++i )
			{
				//	check this pixel
				if( fontmap[idx] != v )
				{
					float nx = (i - x);
					float ny = (line - y);
					float nd2 = nx*nx+ny*ny;
					if( nd2 < d2 )
					{
						d2 = nd2;
					}
				}
				//	move on
				++idx;
			}
		}
		//	south
		line = y + radius;
		if( (line >= 0) && (line < h) )
		{
			lo = x - radius;
			hi = x + radius;
			if( lo < 0 ) { lo = 0; }
			if( hi >= w ) { hi = w-1; }
			int idx = line * w + lo;
			for( int i = lo; i <= hi; ++i )
			{
				//	check this pixel
				if( fontmap[idx] != v )
				{
					float nx = (i - x);
					float ny = (line - y);
					float nd2 = nx*nx+ny*ny;
					if( nd2 < d2 )
					{
						d2 = nd2;
					}
				}
				//	move on
				++idx;
			}
		}
		//	west
		line = x - radius;
		if( (line >= 0) && (line < w) )
		{
			lo = y - radius + 1;
			hi = y + radius - 1;
			if( lo < 0 ) { lo = 0; }
			if( hi >= h ) { hi = h-1; }
			int idx = lo * w + line;
			for( int i = lo; i <= hi; ++i )
			{
				//	check this pixel
				if( fontmap[idx] != v )
				{
					float nx = (line - x);
					float ny = (i - y);
					float nd2 = nx*nx+ny*ny;
					if( nd2 < d2 )
					{
						d2 = nd2;
					}
				}
				//	move on
				idx += w;
			}
		}
		//	east
		line = x + radius;
		if( (line >= 0) && (line < w) )
		{
			lo = y - radius + 1;
			hi = y + radius - 1;
			if( lo < 0 ) { lo = 0; }
			if( hi >= h ) { hi = h-1; }
			int idx = lo * w + line;
			for( int i = lo; i <= hi; ++i )
			{
				//	check this pixel
				if( fontmap[idx] != v )
				{
					float nx = (line - x);
					float ny = (i - y);
					float nd2 = nx*nx+ny*ny;
					if( nd2 < d2 )
					{
						d2 = nd2;
					}
				}
				//	move on
				idx += w;
			}
		}
	}
	import std.math;
	d2 = sqrt( d2 );
	if( v==0 )
	{
		d2 = -d2;
	}
	d2 *= 127.5f / max_radius;
	d2 += 127.5;
	if( d2 < 0.0 ) d2 = 0.0;
	if( d2 > 255.0 ) d2 = 255.0;
	return cast(ubyte)(d2 + 0.5);
}



bool gen_pack_list(ref FT_Face ft_face,
				   int pixel_size,
				   int pack_tex_size,
				   int maxChar,
				   ref sdf_glyph[] packed_glyphs)
{
	packed_glyphs.length = 0;

	int ft_err;
	ft_err = FT_Set_Pixel_Sizes(ft_face, pixel_size * scaler, 0);
	
	foreach(charIndex; 32 .. maxChar)
	{
		int glyph_index = FT_Get_Char_Index( ft_face, charIndex );
		if( glyph_index )
		{
			ft_err = FT_Load_Glyph( ft_face, glyph_index, 0 );
			if( !ft_err )
			{
				ft_err = FT_Render_Glyph( ft_face.glyph, FT_Render_Mode.FT_RENDER_MODE_MONO );
				if( !ft_err )
				{
					sdf_glyph add_me;
					//	we have the glyph, already rendered, get the data about it
					int w = ft_face.glyph.bitmap.width;
					int h = ft_face.glyph.bitmap.rows;

					int sw = w + scaler * 4;
					int sh = h + scaler * 4;
					//	do the SDF
					int sdfw = sw / scaler;
					int sdfh = sh / scaler;

					add_me.ID = charIndex;
					add_me.width = sdfw;
					add_me.height = sdfh;

					add_me.x = -1;
					add_me.y = -1;

					add_me.xoff = ft_face.glyph.bitmap_left;
					add_me.yoff = ft_face.glyph.bitmap_top;
					add_me.xadv = ft_face.glyph.advance.x / 64.0f;
					//	so scale them (the 1.5's have to do with the padding
					//	border and the sampling locations for the SDF)
					add_me.xoff = (add_me.xoff / scaler - 1.5);
					add_me.yoff = (add_me.yoff / scaler + 1.5);
					add_me.xadv = (add_me.xadv / scaler);

					packed_glyphs ~= add_me;
				}
			}

		}
	}
	return packData(packed_glyphs, pack_tex_size);
}

bool packData(sdf_glyph[] glyphs, int texSize)
{
	import std.algorithm, binpacking, std.range, std.array;
	auto binPack = RectPacker(texSize, texSize);

	foreach(i, ref glyph; glyphs)
	{
		auto rect =	binPack.Insert(glyph.width, glyph.height);
		if(rect.height == 0) return false;
		
		glyph.x = rect.x;
		glyph.y = rect.y;

		if(rect.x + rect.width >= texSize || 
		   rect.y + rect.height >= texSize)
		{
			return false;
		}

		if(rect.width != glyph.width || 
		   rect.height != glyph.height)
			return false;
	}

	return true;
}
