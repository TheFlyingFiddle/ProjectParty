module graphics.texture;

import graphics.context;
import graphics.enums;

struct Sampler 
{
	uint glName;

	static Sampler create()
	{
		uint glName;
		gl.genSamplers(1, &glName);
		return Sampler(glName);	
	}

	void wrapT(WrapMode mode) @property
	{
		gl.samplerParameteri(glName, SamplerParam.wrapT, mode);
	}

	void wrapR(WrapMode mode) @property
	{
		gl.samplerParameteri(glName, SamplerParam.wrapR, mode);
	}

	void wrapS(WrapMode mode) @property
	{
		gl.samplerParameteri(glName, SamplerParam.wrapS, mode);
	}

	void minFilter(TextureMinFilter filter) @property
	{
		gl.samplerParameteri(glName, SamplerParam.minFilter, filter);
	}

	void magFilter(TextureMagFilter filter) @property
	{
		gl.samplerParameteri(glName, SamplerParam.magFilter, filter);
	}

	void minLod(float min) @property
	{
		gl.samplerParameterf(glName, SamplerParam.minLod, min);
	}

	void maxLod(float max) @property
	{
		gl.samplerParameterf(glName, SamplerParam.maxLod, max);
	}

	void compareMode(CompareMode mode)  @property
	{
		gl.samplerParameteri(glName, SamplerParam.compareMode, mode);
	}

	void compareFunc(CompareFunc func) @property
	{
		gl.samplerParameteri(glName, SamplerParam.compareMode, func);
	}

	bool deleted() @property
	{
		return gl.isSampler(glName) == FALSE;
	}

	void destroy() 
	{
		gl.deleteSamplers(1, &glName);
	}
}

bool deleted(T)() if(isTexture!T)
{
	return gl.isTexture(glName) == GL_FALSE;
}

void obliterate(T)(T t) if(isTexture!T) 
{
	gl.deleteTextures(1, &t.glName);
}

static uint createTexture()
{
	uint glName;
	gl.genTextures(1, &glName);
	return glName;
}

struct Texture1D
{
	uint glName;
	uint width;

	this(uint glName, uint width)
	{
		this.glName = glName;
		this.width  = width;
	}
}

Texture1D createTexture1D(ColorFormat format, ColorType type,
						  InternalFormat internalFormat, 
						  uint width, void[] data, 
						  bool flag)
{
	auto texture = Texture1D(createTexture(), width);
	gl.activeTexture(TextureUnit.zero);
	gl.bindTexture(TextureTarget.texture1D, texture.glName);
	gl.texImage1D(TextureTarget.texture1D, 0, internalFormat, width, 0, format, type, data.ptr);
	gl.texParameteri(TextureTarget.texture1D, TextureParameter.baseLevel, 0);
	if(!flag)
		gl.texParameteri(TextureTarget.texture1D, TextureParameter.maxLevel, 0);
	else 
		gl.generateMipmap(TextureTarget.texture1D);
	return texture;
}

struct Texture2D
{
	enum target = TextureTarget.texture2D;

	uint glName;
	uint width, height;

	this(uint glName, uint width, uint height) {
		this.glName = glName;
		this.width = width;
		this.height = height;
	}

	static Texture2D create(ColorFormat format, ColorType type, 
							InternalFormat internalFormat,
							uint width, uint height, void[] data,
							bool flag = false) 	
	{
		auto texture = Texture2D(createTexture(), width, height);
		context[TextureUnit.zero] = texture;
		gl.texImage2D(TextureTarget.texture2D, 0, internalFormat, width, height, 0, format, type, data.ptr);
		gl.texParameteri(TextureTarget.texture2D, TextureParameter.baseLevel, 0);

		
		if(!flag)
			gl.texParameteri(TextureTarget.texture2D, TextureParameter.maxLevel, 0);
		else 
			gl.generateMipmap(TextureTarget.texture2D);


		return texture;
	}
}

struct Texture2DMultisample
{
	enum target = TextureTarget.texture2DMultisample;

	uint glName, width, height;
	this(uint glName, uint width, uint height)
	{
		this.glName = glName;
		this.width  = width;
		this.height = height;
	}

	static Texture2DMultisample create(InternalFormat format,
									   uint numSamples,
									   uint width,
									   uint height,
									   bool fixedSampleLocations)
	{
		auto texture = Texture2DMultisample(createTexture(), width, height);
		gl.activeTexture(TextureUnit.zero);
		gl.bindTexture(target, texture.glName);
		gl.texImage2DMultisample(target, numSamples, format, width, height, fixedSampleLocations);
		return texture;
	}
}


//TexSub image
void texSubImage(TextureTarget target, uint mipLevel, uint x, uint width, ColorFormat format, ColorType type, void[] data)
{
	gl.texSubImage1D(target, mipLevel, x, width, format, type, data.ptr);
}

void texSubImage(TextureTarget target, uint mipLevel, uint x, uint y,
				 uint width, uint height, ColorFormat format, ColorType type, void[] data)
{
	gl.texSubImage2D(target, mipLevel, x, y, width, height, format, type, data.ptr);
}

void texSubImage(TextureTarget target, uint mipLevel, uint x, uint y, uint z,
				 uint width, uint height, uint depth, ColorFormat format, ColorType type, void[] data)
{
	gl.texSubImage3D(target, mipLevel, x, y, z, width, height, depth, format, type, data.ptr);
}

//Compressed Tex image
void compressedTexImage(TextureTarget target, uint mipLevel, InternalFormat internalFormat,
						uint width, uint imageSize, void[] data) 
{
	gl.compressedTexImage1D(target, mipLevel, internalFormat, width, 0,imageSize, data.ptr);
}

void compressedTexImage(TextureTarget target, uint mipLevel, InternalFormat internalFormat,
						uint width, uint height, uint imageSize, void[] data) 
{
	gl.compressedTexImage2D(target,mipLevel, internalFormat, width, height, 0,imageSize, data.ptr);
}

void compressedTexImage(TextureTarget target, uint mipLevel, InternalFormat internalFormat,
						uint width, uint height, uint depth, uint imageSize, void[] data) 
{
	gl.compressedTexImage3D(target,mipLevel, internalFormat, width, height ,depth, 0, imageSize, data.ptr);
}

//CompressedSub Tex image
void compressedSubTexImage(TextureTarget target, uint mipLevel, InternalFormat internalFormat,
						   uint x, uint width, 
						   uint imageSize, void[] data) 
{
	gl.compressedTexSubImage1D(target, mipLevel, x, width, internalFormat, imageSize, data.ptr);
}

void compressedSubTexImage(TextureTarget target, uint mipLevel, InternalFormat internalFormat,
						   uint x, uint y, uint width, uint height, uint imageSize, void[] data) 
{
	gl.compressedTexSubImage2D(target, mipLevel, x, y, width, height, internalFormat, imageSize, data.ptr);
}

void compressedSubTexImage(TextureTarget target, uint mipLevel, InternalFormat internalFormat,
						   uint x, uint y, uint z, uint width, uint height,uint depth, uint imageSize, void[] data) 
{
	gl.compressedTexSubImage3D(target, mipLevel, x, y, z, width, height, depth, internalFormat, imageSize, data.ptr);
}


template isTexture(T) { enum isTexture = is(T == Texture1D) || is(T == Texture2D) || is(T == Texture2DMultisample); }