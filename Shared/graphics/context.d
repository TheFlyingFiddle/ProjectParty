module graphics.context;

import derelict.opengl3.gl3;
import logging;

struct gl
{
	import std.string, std.conv;
	static auto ref opDispatch(string name, Args...)(Args args) 
	{
		enum glName = "gl" ~ name[0].toUpper.to!string ~ name[1 .. $];

		scope(exit) checkGLError(name);
		mixin("return " ~ glName ~ "(args);");
	}
}

void checkGLError(string name)
{

	auto err = glGetError();
	if(err)
	{
		switch(err)
		{
			case GL_INVALID_ENUM: 
				error("Got GL_INVALID_ENUM error when calling " ~ name);
				break;
			case GL_INVALID_VALUE:
				error("Got GL_INVALID_VALUE error when calling " ~ name);
				break;
			case GL_INVALID_OPERATION:
				error("Got GL_INVALID_OPERATION error when calling " ~ name);
				break;
			case GL_INVALID_FRAMEBUFFER_OPERATION:
				error("Got GL_INVALID_FRAMEBUFFER_OPERATION error when calling " ~ name);
				break;
			case GL_OUT_OF_MEMORY:
				error("Got GL_OUT_OF_MEMORY error when calling " ~ name);
				break;
			default:
				error("IDK");
				break;
		}	

		assert(0, "GL ERROR");
	}
}