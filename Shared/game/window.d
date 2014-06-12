module game.window;

import derelict.glfw3.glfw3;
import derelict.opengl3.gl3;

import logging;
import collections;
import math;
import util.strings;
import std.exception;
import game.input;

private auto logChnl = LogChannel("WINDOW");

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
			return create(config.size, null, Monitor.primary, config.blocking, config.decorated);
		else
			return create(config.size, null, config.blocking, config.decorated);
	}

	static Window create(uint2 size, const(char)[] title, bool blocking, bool decorated)
	{
		return create(size, title, Monitor(), blocking, decorated);
	}

	static Window create(uint2 size, const(char)[] title, Monitor monitor, bool blocking, bool decorated)
	{
		//glfwWindowHint(GLFW_VERSION_MAJOR, 3);
		//glfwWindowHint(GLFW_VERSION_MINOR, 3);
		glfwWindowHint(GLFW_SAMPLES, 4);
		glfwWindowHint(GLFW_DECORATED, decorated);

		auto glfwWindow = glfwCreateWindow(size.x, size.y, title.toCString(), monitor._monitor, null);
		auto window = Window(glfwWindow);

		enforce(glfwWindow, "Failed to create window");
		logChnl.info("Window created");

		if(windows.length == 0)
		{
			glfwMakeContextCurrent(glfwWindow);
			//TODO: On useless computers, the reload throws exceptions related to
			// not finding features which aren't actually necessary.
			// Ideally, a try catch shouldn't be needed, or should at least
			// check for the relevant unnecessary features.
			try {
				DerelictGL3.reload();
			} catch (Throwable t) {
				import std.stdio;
				writeln(t);
			}
			//After a window has been created the context must be set for that window.
			//But there should only be one context. 
			//So at this moment opengl does not work well with 
			//multiple windows. (As in it is broken)
			//I am not sure of the best way to resolve this so for now
			//only a single window is allowed.
			//An obvious way would be to require that all graphical commands
			//Goes through a graphics context object that is current on the thread.
			//But that is so annoying to manage. A diffrent approach is to have each
			//Window have it's own state and send stuff through messages.
		} else assert(0, "Only a single window is supported at this point.");

		windows   ~= window;
		callbacks ~= WindowCallbacks(); 

		glfwSetWindowPosCallback(glfwWindow, &positionChanged);
		glfwSetWindowSizeCallback(glfwWindow, &sizeChanged);
		glfwSetFramebufferSizeCallback(glfwWindow, &fboSizeChanged);
		glfwSetWindowCloseCallback(glfwWindow, &close);
		glfwSetWindowFocusCallback(glfwWindow, &focus);
		glfwSetWindowRefreshCallback(glfwWindow, &refresh);
		glfwSetWindowIconifyCallback(glfwWindow, &iconify);

		//Move window to center of screen. (If it's not a fullscreen window!)
		if(monitor._monitor is null)
		{
			uint2 msize = Monitor.primary.mode.size;
			window.position = int2(msize / 2 - size / 2);
		}


		//Hack needs to be done correcly.
		//But what is correct? I don't know.
		Keyboard._handle = glfwWindow;

		return window;
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
	bool decorated;
	//@Optional("Project Party") string title;
}


alias PositionCallback = void delegate(int, int);
alias SizeCallback     = void delegate(int, int);
alias FboSizeCallback  = void delegate(int, int);
alias CloseCallback    = void delegate();
alias RefreshCallback  = void delegate();
alias FocusCallback    = void delegate(bool);
alias IconifyCallback  = void delegate(bool);

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

	@property VideoMode mode()
	{
		auto _mode = glfwGetVideoMode(_monitor);
		return VideoMode(_mode);
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


	@property float2 relativeScale()
	{
		return float2(size)/float2(1920f,1080f);
	}

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

	@property uint2 size()
	{
		int2 s;
		glfwGetWindowSize(_windowHandle, &s.x, &s.y);
		return uint2(s);
	}

	@property void size(int2 value)
	{
		glfwSetWindowSize(_windowHandle, value.x, value.y);
	}

	@property uint2 fboSize()
	{
		int2 s;
		glfwGetFramebufferSize(_windowHandle,&s.x, &s.y);
		return uint2(s);
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