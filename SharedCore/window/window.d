module window.window;

import derelict.glfw3.glfw3;
import derelict.opengl3.gl3;

import log;
import collections;
import math;
import util.strings;
import std.exception;
import window.keyboard;

private auto logChnl = LogChannel("WINDOW");

struct WindowManager
{
	private static bool inUse;

	static Window create(WindowConfig config)
	{	
		if(config.fullScreen) 
			return create(config.size, config.title, Monitor.primary, config.blocking, config.decorated, config.numSamples);
		else
			return create(config.size, config.title, config.blocking, config.decorated, config.numSamples);
	}

	static Window create(float2 size, const(char)[] title, bool blocking, bool decorated, int samples)
	{
		return create(size, title, Monitor(), blocking, decorated, samples);
	}

	static Window create(float2 size, const(char)[] title, Monitor monitor, bool blocking, bool decorated, int samples)
	{
		assert(!inUse, "Only a single window can exist at the same time!");
		inUse = true;

		glfwWindowHint(GLFW_SAMPLES, samples);
		glfwWindowHint(GLFW_DECORATED, decorated);

		auto glfwWindow = glfwCreateWindow(cast(int)size.x, cast(int)size.y, title.toCString(), monitor._monitor, null);

		import allocation; //Need to allocate the WindowCallbacks
		glfwSetWindowUserPointer(glfwWindow, Mallocator.it.allocate!WindowState());
	

		assert(glfwWindow, "Failed to create window");

		glfwMakeContextCurrent(glfwWindow);
		//TODO: On useless computers, the reload throws exceptions related to
		// not finding features which aren't actually necessary.
		// Ideally, a try catch shouldn't be needed, or should at least
		// check for the relevant unnecessary features.
		try {
			DerelictGL3.reload();
		} catch (Throwable t) {
			logInfo(t);
		}

		glfwSetWindowPosCallback(glfwWindow, &positionChanged);
		glfwSetWindowSizeCallback(glfwWindow, &sizeChanged);
		glfwSetFramebufferSizeCallback(glfwWindow, &fboSizeChanged);
		glfwSetWindowCloseCallback(glfwWindow, &close);
		glfwSetWindowFocusCallback(glfwWindow, &focus);
		glfwSetWindowRefreshCallback(glfwWindow, &refresh);
		glfwSetWindowIconifyCallback(glfwWindow, &iconify);
		glfwSetCharCallback(glfwWindow, &unicode);
		glfwSetKeyCallback(glfwWindow, &key);
		glfwSetScrollCallback(glfwWindow, &scroll);

		//Move window to center of screen. (If it's not a fullscreen window!)
		if(monitor._monitor is null)
		{
			float2 msize = Monitor.primary.mode.size;
			glfwSetWindowPos(glfwWindow, 
							 cast(int)(msize.x / 2 - size.x / 2),
							 cast(int)(msize.x / 2 - size.x / 2));
		}

		return 	Window(glfwWindow, blocking);;
	}

	static void obliterate(Window window)
	{
		import allocation;
		auto state = cast(WindowState*)glfwGetWindowUserPointer(window._windowHandle);
		Mallocator.it.deallocate(state);

		glfwDestroyWindow(window._windowHandle);
	}

	extern(C) static nothrow void positionChanged(GLFWwindow* window, int x, int y)
	{
		try
		{
			auto state = cast(WindowState*)glfwGetWindowUserPointer(window);
			if(state.posCB !is null)
				state.posCB(x, y);
		}
		catch(Throwable t)
		{
			logChnl.error(t);
		}
	}

	extern(C) static nothrow void sizeChanged(GLFWwindow* window, int x, int y)
	{
		try
		{
			auto state = cast(WindowState*)glfwGetWindowUserPointer(window);
			if(state.sizeCB !is null)
				state.sizeCB(x, y);
		}
		catch(Throwable t)
		{
			logChnl.error(t);
		}
	}

	extern(C) static nothrow void fboSizeChanged(GLFWwindow* window, int x, int y)
	{
		try
		{
			auto state = cast(WindowState*)glfwGetWindowUserPointer(window);
			if(state.fboSizeCB !is null)
				state.fboSizeCB(x, y);
		}
		catch(Throwable t)
		{
			logChnl.error(t);
		}
	}

	extern(C) static nothrow void close(GLFWwindow* window)
	{
		try
		{
			auto state = cast(WindowState*)glfwGetWindowUserPointer(window);
			if(state.closeCB !is null)
				state.closeCB();
		}
		catch(Throwable t)
		{
			logChnl.error(t);
		}
	}

	extern(C) static nothrow void refresh(GLFWwindow* window)
	{
		try
		{
			auto state = cast(WindowState*)glfwGetWindowUserPointer(window);
			if(state.refreshCB !is null)
				state.refreshCB();
		}
		catch(Throwable t)
		{
			logChnl.error(t);
		}
	}

	extern(C) static nothrow void iconify(GLFWwindow* window, int b)
	{
		try
		{
			auto state = cast(WindowState*)glfwGetWindowUserPointer(window);
			if(state.iconifyCB !is null)
				state.iconifyCB(b == 1);
		}
		catch(Throwable t)
		{
			logChnl.error(t);
		}
	}

	extern(C) static nothrow void focus(GLFWwindow* window, int b)
	{
		try
		{
			auto state = cast(WindowState*)glfwGetWindowUserPointer(window);
			if(state.focusCB !is null)
				state.focusCB(b == 1);
		}
		catch(Throwable t)
		{
			logChnl.error(t);
		}
	}

	extern(C) static nothrow void unicode(GLFWwindow* window, uint codepoint)
	{
		try
		{
			//Transform into unicode
			import std.utf;

			import log;

			char[4] buf;
			size_t s = encode(buf, cast(dchar)codepoint);
			logInfo("Unicode char: ", codepoint, "=" , buf[0 .. s]);

			auto state = cast(WindowState*)glfwGetWindowUserPointer(window);
			if(state.unicodeCB !is null)
				state.unicodeCB(buf[0 .. s]);
		}
		catch(Throwable t)
		{
			logChnl.error(t);
		}
	}	
	
	extern(C) static nothrow void key(GLFWwindow* window, int key, int scancode, int action, int mods)
	{
		try
		{
			auto state = cast(WindowState*)glfwGetWindowUserPointer(window);
			if(state.keyCB !is null)
				state.keyCB(cast(Key)key, cast(KeyEventAction)action, cast(KeyModifiers)mods);
		}
		catch(Throwable t)
		{
			logChnl.error(t);
		}
	}

	extern(C) static nothrow void scroll(GLFWwindow* window, double x, double y)
	{
		try
		{
			auto state = cast(WindowState*)glfwGetWindowUserPointer(window);
			if(state.scrollCB !is null)
				state.scrollCB(x, y);
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
	import content.sdl;

	float2 size;
	bool fullScreen;
	bool blocking;
	bool decorated;

	@Optional("") string title;
	@Optional(0)  int numSamples;
}


alias PositionCallback = void delegate(int, int);
alias SizeCallback     = void delegate(int, int);
alias FboSizeCallback  = void delegate(int, int);
alias CloseCallback    = void delegate();
alias RefreshCallback  = void delegate();
alias FocusCallback    = void delegate(bool);
alias IconifyCallback  = void delegate(bool);
alias UnicodeCallback  = void delegate(char[]);
alias KeyCallback      = void delegate(Key, KeyEventAction, KeyModifiers);
alias ScrollCalback    = void delegate(double, double);

struct WindowState
{
	PositionCallback posCB;
	SizeCallback     sizeCB;
	CloseCallback    closeCB;
	RefreshCallback  refreshCB;
	FocusCallback    focusCB;
	IconifyCallback  iconifyCB;
	FboSizeCallback  fboSizeCB;
	UnicodeCallback  unicodeCB;
	KeyCallback      keyCB;
	ScrollCalback    scrollCB;
}

struct VideoMode
{
	private const(GLFWvidmode)* _vidMode;

	@property float2 size()
	{
		return float2(_vidMode.width, 
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

	@property float2 physicalSize()
	{
		int2 size;
		glfwGetMonitorPhysicalSize(_monitor, &size.x, &size.y);
		return float2(size);
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
	package GLFWwindow* _windowHandle;
	private bool blocking;

	@property void* nativeHandle()
	{
		return glfwGetWin32Window(_windowHandle);
	}

	@property WindowState* state()
	{
		return cast(WindowState*)glfwGetWindowUserPointer(this._windowHandle);
	}	


	@property void onScrollChanged(ScrollCalback cb)
	{
		state.scrollCB = cb;
	}

	@property void onPositionChanged(PositionCallback cb)
	{
		state.posCB = cb;
	}

	@property void onSizeChanged(SizeCallback cb)
	{
		state.sizeCB = cb;
	}

	@property void onFboSizeChanged(FboSizeCallback cb)
	{
		state.posCB = cb;
	}

	@property void onFocusChanged(FocusCallback cb)
	{
		state.focusCB = cb;
	}

	@property void onClose(CloseCallback cb)
	{
		state.closeCB = cb;
	}

	@property void onRefresh(RefreshCallback cb)
	{
		state.refreshCB = cb;
	}

	@property void onInotifyChanged(IconifyCallback cb)
	{
		state.iconifyCB = cb;
	}

	@property void onUnicode(UnicodeCallback cb)
	{
		state.unicodeCB = cb;
	}

	@property void onKey(KeyCallback cb)
	{
		state.keyCB = cb;
	}

	@property float2 size()
	{
		int2 s;
		glfwGetWindowSize(_windowHandle, &s.x, &s.y);
		return float2(s);
	}

	@property void size(float2 value)
	{
		int2 val = int2(value);
		glfwSetWindowSize(_windowHandle, val.x, val.y);
	}

	@property float2 fboSize()
	{
		int2 s;
		glfwGetFramebufferSize(_windowHandle,&s.x, &s.y);
		return float2(s);
	}

	@property float2 position()
	{
		int2 p;
		glfwGetWindowPos(_windowHandle,&p.x, &p.y);
		return float2(p.x, size.y - p.y);
	}

	@property void position(float2 value)
	{
		int2 val = int2(value);
		val.y    = cast(int)(size.y - value.y);

		glfwSetWindowPos(_windowHandle, val.x, val.y);
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
		WindowManager.obliterate(this);
	}

	void update()
	{
		if(blocking)
			glfwWaitEvents();
		else 
			glfwPollEvents();
	}

	void swapBuffer()
	{
		glfwSwapBuffers(_windowHandle);
	}

	void* getNativeHandle()
	{
		return glfwGetWin32Window(_windowHandle);
	}
}