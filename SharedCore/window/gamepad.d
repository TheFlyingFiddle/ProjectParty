module window.gamepad;

enum PlayerIndex
{
	zero = 0, 
	one  = 1,
	two  = 2,
	three = 3
}

struct GamePad
{
	import math;
	private bool[XUSER_MAX_COUNT]		  active;
	private XINPUT_STATE[XUSER_MAX_COUNT] oldState, newState;

	void enable()
	{
		XInputEnable(true);
	}

	void disable()
	{
		XInputEnable(false);
	}

	void update()
	{
		oldState[] = newState[];
		foreach(i; 0 .. XUSER_MAX_COUNT)
		{
			auto result = XInputGetState(i, &newState[i]);
			active[i]   = result == 0;
		}
	}

	float leftTrigger(PlayerIndex index)
	{
		ubyte state = newState[index].Gamepad.bLeftTrigger;
		return (cast(float)state) / 255.0f;
	}

	float oldLeftTrigger(PlayerIndex index)
	{
		ubyte state = oldState[index].Gamepad.bLeftTrigger;
		return (cast(float)state) / 255.0f;
	}

	float rightTrigger(PlayerIndex index)
	{
		ubyte state = newState[index].Gamepad.bRightTrigger;
		return (cast(float)state) / 255.0f;
	}

	float oldRightTrigger(PlayerIndex index)
	{
		ubyte state = oldState[index].Gamepad.bRightTrigger;
		return (cast(float)state) / 255.0f;
	}

	void vibrate(PlayerIndex index, float2 motors)
	{
		XINPUT_VIBRATION vibration;
		vibration.wRightMotorSpeed = cast(ushort)(motors.x * ushort.max);
		vibration.wLeftMotorSpeed  = cast(ushort)(motors.y * ushort.max);

		XInputSetState(index, &vibration);
	}

	bool isActive(PlayerIndex index)
	{
		return active[index];
	}

	private static float2 fixDeadzone(short x, short y, short deadzone)
	{
		import math;
		float2 pos = float2(x, y);

		float mag = pos.magnitude;
		float normalizedMag = 0;

		if(mag > deadzone)
		{
			if(mag > short.max) mag = short.max;

			mag -= deadzone;
			normalizedMag = mag / (ushort.max - deadzone);
		}
		else
		{
			normalizedMag = 0;
		}
		
		return pos.normalized * normalizedMag;
	}

	float2 leftThumb(PlayerIndex index)
	{
		return fixDeadzone(newState[index].Gamepad.sThumbLX,
						   newState[index].Gamepad.sThumbLY,
						   XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE);
	}

	float2 oldLeftThumb(PlayerIndex index)
	{
		return fixDeadzone(oldState[index].Gamepad.sThumbLX,
						   oldState[index].Gamepad.sThumbLY,
						   XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE);

	}

	float2 rightThumb(PlayerIndex index)
	{	
		return fixDeadzone(newState[index].Gamepad.sThumbRX,
						   newState[index].Gamepad.sThumbRY,
						   XINPUT_GAMEPAD_RIGHT_THUMB_DEADZONE);
	}

	float2 oldRightThumb(PlayerIndex index)
	{
		return fixDeadzone(oldState[index].Gamepad.sThumbRX,
						   oldState[index].Gamepad.sThumbRY,
						   XINPUT_GAMEPAD_RIGHT_THUMB_DEADZONE);
	}

	bool wasReleased(PlayerIndex index, GamePadButton button)
	{
		return (newState[index].Gamepad.wButtons & button) == 0 && 
			   (oldState[index].Gamepad.wButtons & button) == button;
	}

	bool wasPressed(PlayerIndex index, GamePadButton button)
	{
		return (newState[index].Gamepad.wButtons & button) == button && 
			   (oldState[index].Gamepad.wButtons & button) == 0;
	}

	bool isDown(PlayerIndex index, GamePadButton button)
	{
		return (newState[index].Gamepad.wButtons & button) == button;
	}

	bool isUp(PlayerIndex index, GamePadButton button)
	{
		return (newState[index].Gamepad.wButtons & button) == 0;
	}
}

//
// Constants for gamepad buttons
//
enum GamePadButton : ushort
{
	up           = 0x0001,
	down         = 0x0002,
	left         = 0x0004,
	right        = 0x0008,
	start        = 0x0010,
	back         = 0x0020,
	leftThumb    = 0x0040,
	rightThumb   = 0x0080,
	leftSholder  = 0x0100,
	rightSholder = 0x0200,
	a			 = 0x1000,
	b			 = 0x2000,
	x			 = 0x4000,
	y			 = 0x8000
}


import core.sys.windows.windows;

enum XINPUT_DEVTYPE_GAMEPAD =  0x01;
enum XINPUT_DEVSUBTYPE_GAMEPAD =  0x01;


enum XINPUT_DEVSUBTYPE_UNKNOWN           =  0x00;
enum XINPUT_DEVSUBTYPE_WHEEL             =  0x02;
enum XINPUT_DEVSUBTYPE_ARCADE_STICK      =  0x03;
enum XINPUT_DEVSUBTYPE_FLIGHT_STICK      =  0x04;
enum XINPUT_DEVSUBTYPE_DANCE_PAD         =  0x05;
enum XINPUT_DEVSUBTYPE_GUITAR            =  0x06;
enum XINPUT_DEVSUBTYPE_GUITAR_ALTERNATE  =  0x07;
enum XINPUT_DEVSUBTYPE_DRUM_KIT          =  0x08;
enum XINPUT_DEVSUBTYPE_GUITAR_BASS       =  0x0B;
enum XINPUT_DEVSUBTYPE_ARCADE_PAD        =  0x13;

//
// Flags for XINPUT_CAPABILITIES
//
enum XINPUT_CAPS_VOICE_SUPPORTED     = 0x0004;

enum XINPUT_CAPS_FFB_SUPPORTED       = 0x0001;
enum XINPUT_CAPS_WIRELESS            = 0x0002;
enum XINPUT_CAPS_PMD_SUPPORTED       = 0x0008;
enum XINPUT_CAPS_NO_NAVIGATION       = 0x0010;


//
// Gamepad thresholds
//
enum XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE  = 7849;
enum XINPUT_GAMEPAD_RIGHT_THUMB_DEADZONE = 8689;
enum XINPUT_GAMEPAD_TRIGGER_THRESHOLD    = 30;

//
// Flags to pass to XInputGetCapabilities
//
enum XINPUT_FLAG_GAMEPAD             = 0x00000001;

//
// Devices that support batteries
//
enum BATTERY_DEVTYPE_GAMEPAD         = 0x00;
enum BATTERY_DEVTYPE_HEADSET         = 0x01;

//
// Flags for battery status level
//
enum BATTERY_TYPE_DISCONNECTED       = 0x00;    // This device is not connected
enum BATTERY_TYPE_WIRED              = 0x01;    // Wired device, no battery
enum BATTERY_TYPE_ALKALINE           = 0x02;    // Alkaline battery source
enum BATTERY_TYPE_NIMH               = 0x03;    // Nickel Metal Hydride battery source
enum BATTERY_TYPE_UNKNOWN            = 0xFF;    // Cannot determine the battery type

// These are only valid for wireless, connected devices, with known battery types
// The amount of use time remaining depends on the type of device.
enum BATTERY_LEVEL_EMPTY             = 0x00;
enum BATTERY_LEVEL_LOW               = 0x01;
enum BATTERY_LEVEL_MEDIUM            = 0x02;
enum BATTERY_LEVEL_FULL              = 0x03;


// User index definitions
enum XUSER_MAX_COUNT                 = 4;
enum XUSER_INDEX_ANY                 = 0x000000FF;

//
// Structures used by XInput APIs
//
struct XINPUT_GAMEPAD
{
    WORD                                wButtons;
    BYTE                                bLeftTrigger;
    BYTE                                bRightTrigger;
    SHORT                               sThumbLX;
    SHORT                               sThumbLY;
    SHORT                               sThumbRX;
    SHORT                               sThumbRY;
};

struct XINPUT_STATE
{
    DWORD                               dwPacketNumber;
    XINPUT_GAMEPAD                      Gamepad;
}

struct XINPUT_VIBRATION
{
    WORD                                wLeftMotorSpeed;
    WORD                                wRightMotorSpeed;
}



shared static this()
{
	import core.runtime, std.c.windows.windows;

	auto lib = Runtime.loadLibrary("XINPUT1_4.dll");

	auto xEnable	= GetProcAddress(lib, "XInputEnable");
	auto xGetState  = GetProcAddress(lib, "XInputGetState");
	auto xSetState	= GetProcAddress(lib, "XInputSetState");

	XInputEnable   = cast(typeof(XInputEnable))xEnable;
	XInputGetState = cast(typeof(XInputGetState))xGetState;
	XInputSetState = cast(typeof(XInputSetState))xSetState;
}

extern(Windows):

__gshared DWORD function(DWORD, XINPUT_STATE*) XInputGetState;
__gshared DWORD function(DWORD, XINPUT_VIBRATION*) XInputSetState;
__gshared void function(BOOL) XInputEnable;
