module window.clipboard;

import derelict.glfw3.glfw3;

import window.window;

struct Clipboard
{
	Window* _handle;

	this(Window* window)
	{
		_handle = window;
	}

	@property const(char)[] text()
	{
		import std.c.string;
		auto ptr = glfwGetClipboardString(_handle._windowHandle);
		if(ptr == null) return null;

		return ptr[0 .. strlen(ptr)];
	}

	@property void text(char[] value)
	{
		import util.strings;
		auto c_str = value.toCString();
		glfwSetClipboardString(_handle._windowHandle, c_str);
	}
}