module ui_controls;

import ui;

enum GuiElementType
{
	text,
	icon
}

struct GuiElement
{
	GuiElementType type;
	union
	{
		const(char)[] text;
		GuiFrame  icon;
	}

	const(char)[]  tooltip;

	this(T)(T t, const(char)[] tooltip = "")
	{
		opAssign(t, tooltip);
	}

	void opAssign(const(char)[] text, const(char)[] tooltip = "")
	{
		this.type = GuiElementType.text;
		this.text = text;
		this.tooltip = tooltip;
	}

	void opAssign(GuiFrame icon, const(char)[] tooltip = "")
	{
		this.type = type;
		this.icon = icon;
		this.tooltip = tooltip;
	}
}


struct GuiToggle
{	
	struct Style
	{
		HashID toggled, untoggled;		
	}
}

struct GuiButton
{
	static struct Style
	{
		GuiFrame up, down, highlight, downHl;
		GuiFont font;

		HorizontalAlignment horizontal;
		VerticalAlignment vertical;
	}

	Gui* gui;
	alias gui this;

	void handleButton(Rect rect, GuiElement element, HashID styleID)
	{
		auto style = skin[styleID].get!(GuiButton.Style);

		GuiFrame frame;
		if(wasDown(rect))
		{
			if(isHovering(rect))
				frame = style.downHl;
			else 
				frame = style.down;
		}
		else if(isHovering(rect))
		{
			frame = style.highlight;
		}
		else
		{
			frame = style.up;
		}

	


		//Padding and stuff here
		gui.drawQuad(rect, frame);

		if(element.type == GuiElementType.text)
		{
			auto text = element.text;
			auto font = &fonts.asset[style.font.font];
			auto textSize = font.measure(text) * style.font.size;

			auto fontPos = rect.xy;
			if(style.vertical == VerticalAlignment.center)
				fontPos.y += rect.h / 2 - textSize.y / 2;
			else if(style.vertical == VerticalAlignment.top)
				fontPos.y += rect.h - textSize.y;

			if(style.horizontal == HorizontalAlignment.center)
				fontPos.x += rect.w / 2 - textSize.x / 2;
			else if(style.horizontal == HorizontalAlignment.right)
				fontPos.x += rect.w - textSize.x;

			gui.drawText(text, fontPos, rect, style.font);
		}
		else
		{		
			gui.drawQuad(rect, element.icon);
		}
	}

	bool standard(Rect rect, GuiElement element, HashID styleID)
	{
		handleControl(rect);
		handleButton(rect, element, styleID);

		if(isHovering(rect))
			gui.drawTooltip(rect, element.tooltip);

		return wasClicked(rect) || 
			hasFocus() && 
			keyboard.wasPressed(Key.enter);		
	}

	bool repeat(Rect rect, GuiElement element,  HashID styleID )
	{
		handleControl(rect);
		handleButton(rect, element, styleID);

		if(isHovering(rect))
			gui.drawTooltip(rect, element.tooltip);

		return wasDown(rect) && 
			   isHovering(rect) || (
			hasFocus() && 
			keyboard.isDown(Key.enter));
	}
}

bool button(ref Gui gui, Rect rect, const(char)[] text, 
			HashID styleID = "button")
{
	return button(gui, rect, GuiElement(text), styleID);
}

bool button(ref Gui gui, Rect rect, ref GuiFrame frame, 
			HashID styleID = "button")
{
	return button(gui, rect, GuiElement(frame), styleID);
}

bool button(ref Gui gui, Rect rect, GuiElement element, 
			HashID styleID = "button")
{
	auto b = GuiButton(&gui);
	return b.standard(rect, element, styleID);
}

bool toggle(T)(ref Gui gui, Rect rect, ref bool toggled, T item, 
			   HashID styleID = "toggle")
{
	return toggle(gui, rect, toggled, item, item, styleID);
}

import log;
bool toggle(T)(ref Gui gui, Rect rect, ref bool toggled, T togItem, T untogItem, 
			   HashID styleID = "toggle")
{
	auto style = gui.skin[styleID].get!(GuiToggle.Style);
	
	if(toggled && gui.button(rect, togItem, style.toggled))
	{
		toggled = !toggled;
		return true;
	}
	else if(!toggled && gui.button(rect, untogItem, style.untoggled))
	{
		toggled = !toggled;
		return true;
	}

	return false;
}

bool repeatButton(ref Gui gui, Rect rect, GuiElement element, 
				  HashID styleID = "button")
{
	auto b = GuiButton(&gui);
	return b.repeat(rect, element, styleID);
}

struct GuiLabel
{
	struct Style
	{
		GuiFont font;
	}
}

bool label(ref Gui gui, Rect rect, const(char)[] text, 
		   HashID labelID = "label")
{
	gui.handleControl(rect);

	auto style = gui.fetchStyle!(GuiLabel.Style)(labelID);
	gui.drawText(text, rect.xy + float2(0, style.font.size.x / 5), rect, style.font);
	return false;
}

struct GuiImage
{
	struct Style
	{
		GuiFrame bg;
	}
}

bool image(ref Gui gui, Rect rect, Frame frame, HashID imageID = "image")
{
	gui.handleControl(rect);

	auto style = gui.fetchStyle!(GuiImage.Style)(imageID);
	gui.drawQuad(rect, style.bg);
	gui.drawQuad(rect, frame, Color.white);
	return false;
}


struct GuiToolbar
{
	static struct Style
	{
		HashID   toggleID;
		float    padding;
	}
}

import std.range;
bool toolbar(Items)(ref Gui gui, Rect rect, 
					ref int selected, Items items,
					HashID styleID = HashID("toolbar"))
	if(isRandomAccessRange!Items)
{
	auto style	 = gui.skin[styleID].get!(GuiToolbar.Style);
	int selectedIndex = selected;
	float width = (rect.w - style.padding *  (items.length - 1)) / items.length;
	foreach(i; 0 .. items.length)
	{
		bool sel = i == selected;
		Rect buttonRect = Rect(rect.x + (width + style.padding) * i, rect.y, width, rect.h);
		if(gui.toggle(buttonRect, sel, items[i], style.toggleID))
			selectedIndex = i;
	}
	
	if(selectedIndex != selected) 
	{
		selected = selectedIndex;
		return true;
	}
	else
	{
		return false;
	}
}


struct GuiSlider
{
	struct Style
	{
		GuiFrame bg, fg;
	}
}

private bool updateSlider(ref Gui gui, ref Rect rect, ref float value, float min, float max)
{
	import math;
	
	float percent;
	//Hslider
	if(rect.w > rect.h)
		percent = clamp(gui.mouse.location.x - rect.x, 0, rect.w) / rect.w;
	else 
		percent = clamp(gui.mouse.location.y - rect.y, 0, rect.h) / rect.h;

	float newVal = percent * (max - min) + min;
	bool result  = newVal != value;
	value = newVal;
	return result;
}

private bool updateSliderScroll(ref Gui gui, ref float value, float min, float max)
{
	import math;
	value = clamp(value + gui.mouse.scrollDelta.y * (max - min) / 50, min, max);
	return true;
}

private void renderSlider(ref Gui gui, Rect rect, 
						  ref float value, 
						  float min, 
						  float max,
						  ref GuiSlider.Style style)
{
	import math;
	float percent = (value - min) / (max - min);
	Rect sliderRect = rect;
	if(rect.w > rect.h)
	{
		sliderRect.w = sliderRect.h = rect.h;
		sliderRect.x = clamp(rect.x + (rect.w * percent) - rect.h / 2, rect.x, rect.x + rect.w - rect.h); 
	}
	else 
	{
		sliderRect.h = sliderRect.w = rect.w;
		sliderRect.y = clamp(rect.y + (rect.h * percent) - rect.w / 2, rect.y, rect.y + rect.h - rect.w); 
	}

	gui.drawQuad(rect,style.bg);
	gui.drawQuad(sliderRect, style.fg);
}

bool slider(ref Gui gui, Rect rect, ref float value, float min = 0, float max = 100, HashID sliderID = HashID("slider"))
{
	gui.handleControl(rect);
	auto style = gui.skin[sliderID].get!(GuiSlider.Style);

	bool result = false;
	//Update value;
	if(gui.hasFocus() && gui.wasDown(rect))
		result = updateSlider(gui, rect, value, min, max);
	if(gui.isHovering(rect) && gui.mouse.scrollDelta.y != 0)
		result |= updateSliderScroll(gui, value, min, max);

	renderSlider(gui, rect, value, min, max, style);
	return result;
}


bool scrollbar(ref Gui gui, Rect rect, 
			   ref float value, float min = 0, float max = 100, 
			   HashID scrollbarID = HashID("scrollbar"))
{
	auto style = gui.skin[scrollbarID].get!(GuiSlider.Style);
	bool result = false;
	if(gui.wasDown(rect))
		result = updateSlider(gui, rect, value, min, max);
	
	renderSlider(gui, rect, value, min, max, style);
	return result;
}

struct GuiScrollArea
{
	struct Style
	{
		GuiFrame bg;

		HashID scrollID;
		float scrollWidth;
	}

	struct State
	{
		Rect area; //The Full Scrollarea.
		int focused;
		int controlcount;
	}
}


bool scrollarea(ref Gui gui, 
				Rect rect, 
				ref float2 scroll, 
				void delegate(ref Gui gui) controls, 
				HashID scrollareaID = "scrollarea",
				int stateID = -1)
{
	gui.handleControl(rect);
	auto hash = stateID == -1 ? HashID(rect, "scrollarea") : HashID(stateID);
	bool isFocused = gui.hasFocus();

	auto state = gui.fetchState(hash, GuiScrollArea.State(rect));
	auto style = gui.fetchStyle!(GuiScrollArea.Style)(scrollareaID);

	Rect modified = rect;
	bool result = false;
	if(rect.w < state.area.w)
	{
		modified.y += style.scrollWidth;
		modified.h -= style.scrollWidth;
	}
	if(rect.h < state.area.h)
		modified.w -= style.scrollWidth;

	if(rect.h >= state.area.h && 
	   rect.w >= state.area.w)
		scroll = float2.zero;


	gui.drawQuad(modified, style.bg);
	if(modified.y > rect.y)
		result  = gui.scrollbar(Rect(rect.x, rect.y, modified.w, style.scrollWidth),
								scroll.x, 0, state.area.w - modified.w, style.scrollID);
	if(modified.w < rect.w)
		result  = gui.scrollbar(Rect(modified.x + modified.w, modified.y, style.scrollWidth, modified.h),
								scroll.y, 0, state.area.h - modified.h, style.scrollID);

	auto savedState = gui.beginSubArea(modified, scroll * -1, state.focused);
	scope(exit) gui.endSubArea(savedState);

	controls(gui);
	if(isFocused) 
	{
		gui.drawFocused();
		state.focused = gui.guiState.focus;
		state.controlcount = gui.guiState.controlCount;
	}
	else
	{
		state.focused = -2;
		state.controlcount = 0;
	}

	state.area = Rect(gui.guiState.fullArea);
	gui.state(hash, state);
	return result;
}	


struct GuiWindow
{
	struct Style
	{
		Color focusColor, nonFocusColor;
		GuiFrame bg;
		float dragHeight;
	}

	struct State
	{
		bool isDraging;
		int focus;
	}
}	


float2 dragWindow(ref Gui gui, Rect window,
				  ref Rect titlebar, ref GuiWindow.State state)
{
	if(gui.wasDown(titlebar) || 
	   (state.isDraging && gui.mouse.isDown(MouseButton.left)))
	{
		if(!state.isDraging)
			gui.beginDrag(window);
			
		state.isDraging = true;
		return gui.mouse.moveDelta;
	} 

	if(state.isDraging)
		gui.endDrag();
	
	state.isDraging = false;
	return float2.zero;
}

bool guiwindow(ref Gui gui,
			   int windowID,
			   int parentID,
			   ref Rect rect, 
			   void delegate(Rect, ref Gui) controls,
			   HashID guiwindowID = "guiwindow")
{
	gui.delayWindow(windowID, parentID, rect, controls, guiwindowID);

	auto copy = gui.windowArea(windowID);
	if(gui.handleControl(copy))
		return true;


	return false;
}

