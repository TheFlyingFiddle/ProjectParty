module graphics.context;

import derelict.opengl3.gl3;
import logging;
import graphics.enums;

auto logChnl = LogChannel("OPENGL");
struct gl
{
	import std.string, std.conv;
	static auto ref opDispatch(string name, Args...)(Args args) 
	{
		enum glName = "gl" ~ name[0].toUpper.to!string ~ name[1 .. $];

		//logChnl.info(glName,"(", args, ")");
		debug scope(exit) checkGLError(name, args);

		mixin("return " ~ glName ~ "(args);");
	}
}


void checkGLError(Args...)(string name, Args args)
{
	auto err = glGetError();
	import std.stdio;
	if(err)
	{
		switch(err)
		{
			case GL_INVALID_ENUM: 
				writeln("Got GL_INVALID_ENUM error when calling " ~ name);
				break;
			case GL_INVALID_VALUE:
				writeln("Got GL_INVALID_VALUE error when calling " ~ name);
				break;
			case GL_INVALID_OPERATION:
				writeln("Got GL_INVALID_OPERATION error when calling " ~ name);
				break;
			case GL_INVALID_FRAMEBUFFER_OPERATION:
				writeln("Got GL_INVALID_FRAMEBUFFER_OPERATION error when calling " ~ name);
				break;
			case GL_OUT_OF_MEMORY:
				writeln("Got GL_OUT_OF_MEMORY error when calling " ~ name);
				break;
			default:
				writeln("IDK");
				break;
		}	

		logChnl.info("Called with arguments");
		foreach(i, arg; args)
		{
			logChnl.info("Arg ", i, "=", arg);
		}



		assert(0, "GL ERROR");
	}
}


struct Context
{
	import graphics.texture;

	uint program;
	uint[TextureUnit.max - TextureUnit.min] textures;
	uint[TextureUnit.max - TextureUnit.min] samplers;
	uint ibo, vbo, texbo, pixbo, pixubo, vao;
	uint fbo;


	void opIndexAssign(T)(T texture, TextureUnit unit)
	{
		if(textures[unit - TextureUnit.min] == texture.glName)
			return;

		textures[unit - TextureUnit.min] = texture.glName;
		gl.activeTexture(unit);
		gl.bindTexture(texture.target, texture.glName);
	}

	void opIndexAssign(Sampler sampler, TextureUnit unit)
	{
		if(samplers[unit - TextureUnit.min] == sampler.glName)
			return;

		samplers[unit - TextureUnit.min] = sampler.glName;
		gl.bindSampler(unit - TextureUnit.min, sampler.glName);
	}

}

__gshared Context context;