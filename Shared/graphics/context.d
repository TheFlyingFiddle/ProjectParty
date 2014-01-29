module graphics.context;

import derelict.opengl3.gl3;
import logging;

auto logChnl = LogChannel("OPENGL");
struct gl
{
	import std.string, std.conv;
	static auto ref opDispatch(string name, Args...)(Args args) 
	{
		enum glName = "gl" ~ name[0].toUpper.to!string ~ name[1 .. $];

		logChnl.info("Calling: " , glName,"(", args, ")");
		debug scope(exit) checkGLError(name);
		mixin("return " ~ glName ~ "(args);");
	}
}

void checkGLError(string name)
{
	logChnl.info("Got here: " , name);
	auto err = glGetError();
	if(err)
	{
		switch(err)
		{
			case GL_INVALID_ENUM: 
				logChnl.error("Got GL_INVALID_ENUM error when calling " ~ name);
				break;
			case GL_INVALID_VALUE:
				logChnl.error("Got GL_INVALID_VALUE error when calling " ~ name);
				break;
			case GL_INVALID_OPERATION:
				logChnl.error("Got GL_INVALID_OPERATION error when calling " ~ name);
				break;
			case GL_INVALID_FRAMEBUFFER_OPERATION:
				logChnl.error("Got GL_INVALID_FRAMEBUFFER_OPERATION error when calling " ~ name);
				break;
			case GL_OUT_OF_MEMORY:
				logChnl.error("Got GL_OUT_OF_MEMORY error when calling " ~ name);
				break;
			default:
				logChnl.error("IDK");
				break;
		}	

		assert(0, "GL ERROR");
	}
}