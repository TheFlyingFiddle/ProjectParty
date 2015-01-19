module window.mouse;

import derelict.glfw3.glfw3;
import math.vector;
import window.window;
import std.datetime;

struct MouseButtonState
{
	float2 lastUp, lastDown;
	bool isDown;
}

enum MouseButton
{	
	left	  = GLFW_MOUSE_BUTTON_1,
	rigth   = GLFW_MOUSE_BUTTON_2,
	middle  = GLFW_MOUSE_BUTTON_3,
	x0		  = GLFW_MOUSE_BUTTON_4,
	x1		  = GLFW_MOUSE_BUTTON_5,
	x2		  = GLFW_MOUSE_BUTTON_6,
	x3		  = GLFW_MOUSE_BUTTON_7,
	x4		  = GLFW_MOUSE_BUTTON_8
}

struct Mouse
{
	private Window* _handle;
	private MouseButtonState[GLFW_MOUSE_BUTTON_LAST]  buttonStates;
	private bool[GLFW_MOUSE_BUTTON_LAST]		 changed;

	private TickDuration oldClickTime;
	private bool isDoubleClick;

	private float2 oldLoc;
	private float2 newLoc;

	float2 scrollDelta;

	this(Window* window)
	{
		_handle = window;
		changed[] = false;
		foreach(i; 0 .. GLFW_MOUSE_BUTTON_LAST)
		{
			int state = glfwGetMouseButton(_handle._windowHandle, i);
			if(state == GLFW_PRESS)
			{
				buttonStates[i] = MouseButtonState(newLoc, newLoc, true);
			}
			else 
			{
				buttonStates[i] = MouseButtonState(newLoc, newLoc, false);
			}
		}

		double x, y;
		glfwGetCursorPos(_handle._windowHandle, &x, &y);
		y = _handle.size.y - y;
		oldLoc = newLoc = float2(x,y);

		_handle.onScrollChanged = &scrollChanged;
	}

	void scrollChanged(double x, double y)
	{
		scrollDelta = float2(x,y);
	}

	void update()
	{
		changed[] = false;

		foreach(i; 0 .. GLFW_MOUSE_BUTTON_LAST)
		{
			int state = glfwGetMouseButton(_handle._windowHandle, i);
			if(state == GLFW_PRESS)
			{
				if(!buttonStates[i].isDown)
				{

					changed[i] = true;
					buttonStates[i].isDown = true;
					buttonStates[i].lastDown = newLoc;

					if(i == MouseButton.left)
					{
						TickDuration dur = Clock.currSystemTick;
						if((dur - oldClickTime) < TickDuration.from!"msecs"(100))
						{
							isDoubleClick = true;
						}

						oldClickTime = dur;
					}
				}
			}
			else 
			{
				if(buttonStates[i].isDown)
				{
					changed[i] = true;
					buttonStates[i].isDown = false;
					buttonStates[i].lastUp = newLoc;
				}
			}
		}

		double x, y;
		glfwGetCursorPos(_handle._windowHandle, &x, &y);
		y = _handle.size.y - y;
		oldLoc = newLoc;
		newLoc = float2(x, y);
	}

	void postUpdate()
	{
		scrollDelta   = float2.zero;
		isDoubleClick = false;
	}
	
	auto state(MouseButton button) 
	{
		return buttonStates[button];
	}

	bool wasReleased(MouseButton button) 
	{
		return changed[button] && !buttonStates[button].isDown;
	}

	bool wasPressed(MouseButton button)
	{
		return changed[button] && buttonStates[button].isDown;
	}

	bool isDown(MouseButton button) 
	{
		return buttonStates[button].isDown;
	}

	bool isUp(MouseButton button) 
	{
		return !buttonStates[button].isDown;
	}

	bool wasDoubleClick()
	{
		return isDoubleClick;
	}


	@property float2 location()
	{
		return newLoc;
	}

	@property float2 moveDelta()
	{
		return newLoc - oldLoc;
	}
}	