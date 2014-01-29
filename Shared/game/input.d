module game.input;

import derelict.glfw3.glfw3;

struct Keyboard
{
	//Only support one window to start with.
	package static GLFWwindow* _handle;
	static bool isDown(Key key)
	{
		return glfwGetKey(_handle, key) == GLFW_PRESS;
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