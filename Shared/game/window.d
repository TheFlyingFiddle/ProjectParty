module game.window;

import derelict.glfw3.glfw3;
import derelict.opengl3.gl3;

import logging;
import collections;
import math;
import util.strings;
import std.exception;
import game.input;

auto logChnl = LogChannel("WINDOW");

struct WindowManager
{
	__gshared static List!Window windows;
	__gshared static List!WindowCallbacks callbacks;

	static void init(A)(ref A allocator, size_t maxWindows)
	{
		windows   = List!Window(allocator, maxWindows);
		callbacks = List!WindowCallbacks(allocator, maxWindows); 
	}

	static void shutdown()
	{
		foreach(window; windows) 
			window.obliterate();

	}

	static Window create(WindowConfig config)
	{	
		if(config.fullScreen) 
			return create(config.size, config.title, Monitor.primary, config.blocking);
		else
			return create(config.size, config.title, config.blocking);
	}


	static Window create(uint2 size, const(char)[] title, bool blocking)
	{
		return create(size, title, Monitor(), blocking);
	}

	//Used to create fullscreen windows. 
	static Window create(uint2 size, const(char)[] title, Monitor monitor, bool blocking)
	{
		auto window = glfwCreateWindow(size.x, size.y, title.toCString(), null, null);
		//enforce(window, "Failed to create window");
		logChnl.info("Window created");

		if(windows.length == 0)
		{
			glfwMakeContextCurrent(window);
			DerelictGL3.reload();
		}

		windows   ~= Window(window);
		callbacks ~= WindowCallbacks(); 

		glfwSetWindowPosCallback(window, &positionChanged);
		glfwSetWindowSizeCallback(window, &sizeChanged);
		glfwSetFramebufferSizeCallback(window, &fboSizeChanged);
		glfwSetWindowCloseCallback(window, &close);
		glfwSetWindowFocusCallback(window, &focus);
		glfwSetWindowRefreshCallback(window, &refresh);
		glfwSetWindowIconifyCallback(window, &iconify);


		//Hack needs to be done correcly.
		Keyboard._handle = window;

		return Window(window);
	}

	static void obliterate(Window window)
	{
		window.obliterate();
		import std.algorithm;

		auto index = windows.countUntil!(x => x == window);
		windows.removeAt(index);
		callbacks.removeAt(index);
	}



	extern(C) static nothrow void positionChanged(GLFWwindow* window, int x, int y)
	{
		import std.algorithm;
		auto index = windows.countUntil!(x => x._windowHandle == window);
		try
		{
			if(callbacks[index].posCB !is null)
				callbacks[index].posCB(x, y);
		}
		catch(Throwable t)
		{
			logChnl.error(t);
		}
	}

	extern(C) static nothrow void sizeChanged(GLFWwindow* window, int x, int y)
	{
		import std.algorithm;
		auto index = windows.countUntil!(x => x._windowHandle == window);
		try
		{
			if(callbacks[index].sizeCB !is null)
				callbacks[index].sizeCB(x, y);
		}
		catch(Throwable t)
		{
			logChnl.error(t);
		}
	}

	extern(C) static nothrow void fboSizeChanged(GLFWwindow* window, int x, int y)
	{
		import std.algorithm;
		auto index = windows.countUntil!(x => x._windowHandle == window);
		try
		{
			if(callbacks[index].fboSizeCB !is null)
				callbacks[index].fboSizeCB(x, y);
		}
		catch(Throwable t)
		{
			logChnl.error(t);
		}
	}

	extern(C) static nothrow void close(GLFWwindow* window)
	{
		import std.algorithm;
		auto index = windows.countUntil!(x => x._windowHandle == window);
		try
		{
			if(callbacks[index].closeCB !is null)
				callbacks[index].closeCB();
		}
		catch(Throwable t)
		{
			logChnl.error(t);
		}
	}

	extern(C) static nothrow void refresh(GLFWwindow* window)
	{
		import std.algorithm;
		auto index = windows.countUntil!(x => x._windowHandle == window);
		try
		{
			if(callbacks[index].refreshCB !is null)
				callbacks[index].refreshCB();
		}
		catch(Throwable t)
		{
			logChnl.error(t);
		}
	}

	extern(C) static nothrow void iconify(GLFWwindow* window, int b)
	{
		import std.algorithm;
		auto index = windows.countUntil!(x => x._windowHandle == window);
		try
		{
			if(callbacks[index].iconifyCB !is null)
				callbacks[index].iconifyCB(b == 1);
		}
		catch(Throwable t)
		{
			logChnl.error(t);
		}
	}

	extern(C) static nothrow void focus(GLFWwindow* window, int b)
	{
		import std.algorithm;
		auto index = windows.countUntil!(x => x._windowHandle == window);
		try
		{
			if(callbacks[index].focusCB !is null)
				callbacks[index].focusCB(b == 1);
		}
		catch(Throwable t)
		{
			logChnl.error(t);
		}
	}
}


//Can make this contain more but this is enough for now.
struct WindowConfig
{
	uint2 size;
	bool fullScreen;
	bool blocking;
	string title;
}


alias PositionCallback = void function(int, int);
alias SizeCallback     = void function(int, int);
alias FboSizeCallback  = void function(int, int);
alias CloseCallback    = void function();
alias RefreshCallback  = void function();
alias FocusCallback    = void function(bool);
alias IconifyCallback  = void function(bool);

struct WindowCallbacks
{
	PositionCallback posCB;
	SizeCallback     sizeCB;
	CloseCallback    closeCB;
	RefreshCallback  refreshCB;
	FocusCallback    focusCB;
	IconifyCallback  iconifyCB;
	FboSizeCallback  fboSizeCB;
}

struct VideoMode
{
	private const(GLFWvidmode)* _vidMode;

	@property uint2 size()
	{
		return uint2(_vidMode.width, 
					 _vidMode.height);
	}
	
	//RGB bits standard 8-8-8
	@property uint3 colorBits()
	{
		return uint3(_vidMode.redBits,
					 _vidMode.greenBits,
					 _vidMode.blueBits);
	}
}

struct Monitor
{	
	private GLFWmonitor* _monitor;
	@property static Monitor primary()
	{
		auto monitor = glfwGetPrimaryMonitor();
		return Monitor(monitor);
	}

	@property static MRange all()
	{
		int count;
		GLFWmonitor** monitors = glfwGetMonitors(&count);
		GLFWmonitor*[] m = monitors[0 .. count];

		return MRange(m, 0);
	}

	@property VRange videoModes()
	{
		int count;
		auto modes = glfwGetVideoModes(_monitor, &count);
		auto m = modes[0 .. count];
		return VRange(m, 0);
	}

	@property uint2 physicalSize()
	{
		int2 size;
		glfwGetMonitorPhysicalSize(_monitor, &size.x, &size.y);
		return uint2(size);
	}

	@property const(char)* name()
	{
		return glfwGetMonitorName(_monitor);
	}

	struct MRange
	{
		GLFWmonitor*[] monitors;
		uint _offset;

		Monitor front() { return Monitor(monitors[_offset]); }
		bool empty() { return _offset == monitors.length; }
		void popFront() { _offset++; }
	}

	struct VRange
	{
		const(GLFWvidmode)[] modes;
		uint _offset;

		VideoMode front() { return VideoMode(&modes[_offset]); }
		bool empty() { return _offset == modes.length; }
		void popFront() { _offset++; }
	}
}

struct Window
{
	private GLFWwindow* _windowHandle;
	private bool blocking;

	@property void onPositionChanged(PositionCallback cb)
	{
		import std.algorithm;
		auto index = WindowManager.windows.countUntil!(x => x._windowHandle == _windowHandle);
		WindowManager.callbacks[index].posCB = cb;
	}

	@property void onSizeChanged(SizeCallback cb)
	{
		import std.algorithm;
		auto index = WindowManager.windows.countUntil!(x => x._windowHandle == _windowHandle);
		WindowManager.callbacks[index].sizeCB = cb;
	}

	@property void onFboSizeChanged(FboSizeCallback cb)
	{
		import std.algorithm;
		auto index = WindowManager.windows.countUntil!(x => x._windowHandle == _windowHandle);
		WindowManager.callbacks[index].posCB = cb;
	}

	@property void onFocusChanged(FocusCallback cb)
	{
		import std.algorithm;
		auto index = WindowManager.windows.countUntil!(x => x._windowHandle == _windowHandle);
		WindowManager.callbacks[index].focusCB = cb;
	}

	@property void onClose(CloseCallback cb)
	{
		import std.algorithm;
		auto index = WindowManager.windows.countUntil!(x => x._windowHandle == _windowHandle);
		WindowManager.callbacks[index].closeCB = cb;
	}

	@property void onRefresh(RefreshCallback cb)
	{
		import std.algorithm;
		auto index = WindowManager.windows.countUntil!(x => x._windowHandle == _windowHandle);
		WindowManager.callbacks[index].refreshCB = cb;
	}

	@property void onInotifyChanged(IconifyCallback cb)
	{
		import std.algorithm;
		auto index = WindowManager.windows.countUntil!(x => x._windowHandle == _windowHandle);
		WindowManager.callbacks[index].iconifyCB = cb;
	}

	@property int2 size()
	{
		int2 s;
		glfwGetWindowSize(_windowHandle, &s.x, &s.y);
		return s;
	}

	@property void size(int2 value)
	{
		glfwSetWindowSize(_windowHandle, value.x, value.y);
	}

	@property int2 fboSize()
	{
		int2 s;
		glfwGetFramebufferSize(_windowHandle,&s.x, &s.y);
		return s;
	}

	@property int2 position()
	{
		int2 p;
		glfwGetWindowPos(_windowHandle,&p.x, &p.y);
		return p;
	}

	@property void position(int2 value)
	{
		glfwSetWindowPos(_windowHandle, value.x, value.y);
	}

	@property void title(const(char)[] title)
	{
		glfwSetWindowTitle(_windowHandle ,title.toCString());
	}

	@property bool shouldClose()
	{
		return glfwWindowShouldClose(_windowHandle) == 1;
	}

	@property void shouldClose(bool value)
	{
		glfwSetWindowShouldClose(_windowHandle, value);
	}

	@property bool focused()
	{
		return glfwGetWindowAttrib(_windowHandle, GLFW_FOCUSED) == 1;
	}

	@property bool iconified()
	{
		return glfwGetWindowAttrib(_windowHandle, GLFW_ICONIFIED) == 1;
	}

	@property bool visible()
	{
		return glfwGetWindowAttrib(_windowHandle, GLFW_VISIBLE) == 1;
	}

	@property bool resizable()
	{
		return glfwGetWindowAttrib(_windowHandle, GLFW_RESIZABLE) == 1;
	}

	@property bool decorated()
	{
		return glfwGetWindowAttrib(_windowHandle, GLFW_DECORATED) == 1;
	}

	void iconify()
	{
		glfwIconifyWindow(_windowHandle);
	}
	
	void restore()
	{
		glfwRestoreWindow(_windowHandle);
	}

	void show()
	{
		glfwShowWindow(_windowHandle);
	}
	
	void hide()
	{
		glfwHideWindow(_windowHandle);
	}

	void obliterate()
	{
		glfwDestroyWindow(_windowHandle);
		_windowHandle = null;
	}

	package void update()
	{
		if(blocking)
			glfwWaitEvents();
		else 
			glfwPollEvents();
	}

	package void swapBuffer()
	{
		glfwSwapBuffers(_windowHandle);
	}
}