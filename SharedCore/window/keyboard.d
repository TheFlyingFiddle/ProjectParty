module window.keyboard;

import derelict.glfw3.glfw3;
import window.window;
import log;

enum KeyState : ubyte
{
	pressed  = GLFW_PRESS,
	released = GLFW_RELEASE 
}

enum KeyEventAction : ubyte
{
	pressed  = GLFW_PRESS,
	released = GLFW_RELEASE,
	repeat   = GLFW_REPEAT
}

enum KeyModifiers : ubyte
{
	none	= 0x00,
	shift   = 0x01,
	control = 0x02,
	alt	    = 0x04,
	super_  = 0x08
}

struct Keyboard
{
	private Window* _handle;
	KeyState[cast(uint)Key.last_key] keystates;
	bool[cast(uint)Key.last_key]	 changed;

	char[32] charInput;
	size_t inputSize;

	Key repeatKey;

	this(Window* _handle) 
	{
		this._handle = _handle;
		this._handle.onUnicode  = &onCharInput;
		this._handle.onKey = &onKeyInput; 
		keystates[] = KeyState.released;
	}

	void onCharInput(char[] input)
	{

		charInput[inputSize .. inputSize + input.length] = input;
		inputSize += input.length;
	}

	void onKeyInput(Key key, KeyEventAction action, KeyModifiers modifiers)
	{
		if(action == KeyEventAction.repeat) 
		{
			repeatKey = key;
		}
	}

	char[] unicodeInput()
	{
		return charInput[0 .. inputSize];
	}

	void update()
	{
		changed[] = false;
		foreach(i; 0 .. cast(uint)Key.last_key)
		{
			int state = glfwGetKey(_handle._windowHandle, i);
			if(state == GLFW_PRESS)
			{
				if(keystates[i] == KeyState.released)
					changed[i] = true;

				keystates[i] = KeyState.pressed;
			}
			else if(state == GLFW_RELEASE)
			{
				if(keystates[i] == KeyState.pressed)
					changed[i] = true;

				keystates[i] = KeyState.released;
			}
			
			if(i == repeatKey)
			{
				changed[i] = true;
			}
		}
	}

	void postUpdate()
	{
		inputSize = 0;
		repeatKey = Key.last_key;
	}

	bool isDown(Key key)
	{
		return keystates[key] == KeyState.pressed;
	}

	bool isModifiersDown(int modifiers)
	{
		int modifier;
		if(isDown(Key.leftAlt) || isDown(Key.rightAlt))
			modifier |= KeyModifiers.alt;
		if(isDown(Key.leftShift) || isDown(Key.rightShift))
			modifier |= KeyModifiers.shift;
		if(isDown(Key.leftControl) || isDown(Key.leftControl))
			modifier |= KeyModifiers.control;
		if(isDown(Key.leftSuper) || isDown(Key.rightSuper))
			modifier |= KeyModifiers.super_;

		return modifiers == modifier;
	}

	bool isUp(Key key)
	{
		return keystates[key] == KeyState.released;
	}

	bool wasPressed(Key key)
	{
		return isDown(key) && changed[key];
	}

	bool wasRepeated(Key key)
	{
		return key == repeatKey;
	}

	//Pressed or repeated!
	bool wasInput(Key key)
	{
		return wasPressed(key) || wasRepeated(key);
	}

	bool wasReleased(Key key)
	{
		return isUp(key) && changed[key];
	}
}

enum Key
{
	unknown     = GLFW_KEY_UNKNOWN,
	space       = GLFW_KEY_SPACE,
	apostrophe  = GLFW_KEY_APOSTROPHE,
	comma       = GLFW_KEY_COMMA,
	minus       = GLFW_KEY_MINUS,
	period      = GLFW_KEY_PERIOD,
	slash       = GLFW_KEY_SLASH,
	zero        = GLFW_KEY_0,
	one         = GLFW_KEY_1,
	two         = GLFW_KEY_2,
	three       = GLFW_KEY_3,
	four        = GLFW_KEY_4,
	five        = GLFW_KEY_5,
	six         = GLFW_KEY_6,
	seven       = GLFW_KEY_7,
	eigth       = GLFW_KEY_8,
	nine        = GLFW_KEY_9,
	semicololon = GLFW_KEY_SEMICOLON,
	equal       = GLFW_KEY_EQUAL,

	a = GLFW_KEY_A,
	b = GLFW_KEY_B,
	c = GLFW_KEY_C,
	d = GLFW_KEY_D,
	e = GLFW_KEY_E,
	f = GLFW_KEY_F,
	g = GLFW_KEY_G,
	h = GLFW_KEY_H,
	i = GLFW_KEY_I,
	j = GLFW_KEY_J,
	k = GLFW_KEY_K,
	l = GLFW_KEY_L,
	m = GLFW_KEY_M,
	n = GLFW_KEY_N,
	o = GLFW_KEY_O,
	p = GLFW_KEY_P,
	q = GLFW_KEY_Q,
	r = GLFW_KEY_R,
	s = GLFW_KEY_S,
	t = GLFW_KEY_T,
	u = GLFW_KEY_U,
	v = GLFW_KEY_V,
	w = GLFW_KEY_W,
	x = GLFW_KEY_X,
	y = GLFW_KEY_Y,
	z = GLFW_KEY_Z,


	leftBracket  = GLFW_KEY_LEFT_BRACKET,
	rightBracket = GLFW_KEY_RIGHT_BRACKET,
	backslash    = GLFW_KEY_BACKSLASH,
	graveAccent  = GLFW_KEY_GRAVE_ACCENT,
	world1       = GLFW_KEY_WORLD_1,
	world2       = GLFW_KEY_WORLD_2,
	escape       = GLFW_KEY_ESCAPE,
	enter        = GLFW_KEY_ENTER,
	tab          = GLFW_KEY_TAB,
	backspace    = GLFW_KEY_BACKSPACE,
	insert       = GLFW_KEY_INSERT,
	delete_		 = GLFW_KEY_DELETE,
	right        = GLFW_KEY_RIGHT,
	left         = GLFW_KEY_LEFT,
	down         = GLFW_KEY_DOWN,
	up           = GLFW_KEY_UP,
	pageUp       = GLFW_KEY_PAGEUP,
	pageDown     = GLFW_KEY_PAGE_DOWN,
	home         = GLFW_KEY_HOME,
	end          = GLFW_KEY_END,
	capsLock     = GLFW_KEY_CAPS_LOCK,
	scrollLock   = GLFW_KEY_SCROLL_LOCK,
	numLock      = GLFW_KEY_NUM_LOCK,
	printScreen  = GLFW_KEY_PRINT_SCREEN,
	pause        = GLFW_KEY_PAUSE,


    f1 = GLFW_KEY_F1,
	f2 = GLFW_KEY_F2,
	f3 = GLFW_KEY_F3,
	f4 = GLFW_KEY_F4,
	f5 = GLFW_KEY_F5, 
	f6 = GLFW_KEY_F6,
	f7 = GLFW_KEY_F7,
	f8 = GLFW_KEY_F8,
	f9 = GLFW_KEY_F9,

	f10 = GLFW_KEY_F10,
	f11 = GLFW_KEY_F11,
	f12 = GLFW_KEY_F12,
	f13 = GLFW_KEY_F13,
	f14 = GLFW_KEY_F14,
	f15 = GLFW_KEY_F15,
	f16 = GLFW_KEY_F16,
	f17 = GLFW_KEY_F17,
	f18 = GLFW_KEY_F18,
	f19 = GLFW_KEY_F19,
	f20 = GLFW_KEY_F20,
	f21 = GLFW_KEY_F21,
	f22 = GLFW_KEY_F22,
	f23 = GLFW_KEY_F23,
	f24 = GLFW_KEY_F24,
	f25 = GLFW_KEY_F25,

	kp0 = GLFW_KEY_KP_0,
	kp1 = GLFW_KEY_KP_1,
	kp2 = GLFW_KEY_KP_2,
	kp3 = GLFW_KEY_KP_3,
	kp4 = GLFW_KEY_KP_4,
	kp5 = GLFW_KEY_KP_5,
	kp6 = GLFW_KEY_KP_6,
	kp7 = GLFW_KEY_KP_7,
	kp8 = GLFW_KEY_KP_8,
	kp9 = GLFW_KEY_KP_9,

	kpDecimal  = GLFW_KEY_KP_DECIMAL,
	kpDivide   = GLFW_KEY_KP_DIVIDE,
	kpMultiply = GLFW_KEY_KP_MULTIPLY,
	kpSubtract = GLFW_KEY_KP_SUBTRACT,
	kpAdd      = GLFW_KEY_KP_ADD,
	kpEnter    = GLFW_KEY_KP_ENTER,
	kpEqual    = GLFW_KEY_KP_EQUAL,

	leftShift    = GLFW_KEY_LEFT_SHIFT,
	rightShift   = GLFW_KEY_RIGHT_SHIFT,
	leftControl  = GLFW_KEY_LEFT_CONTROL,
	rightControl = GLFW_KEY_RIGHT_CONTROL,
	leftAlt      = GLFW_KEY_LEFT_ALT,
	rightAlt     = GLFW_KEY_RIGHT_ALT,
	leftSuper    = GLFW_KEY_LEFT_SUPER,
	rightSuper   = GLFW_KEY_RIGHT_SUPER,
	menu         = GLFW_KEY_MENU,
	esc          = GLFW_KEY_ESC,

	last_key     = GLFW_KEY_LAST
}