module ui.containers;

import ui;

struct GuiListBox
{
	struct Style
	{
		GuiFont  font;
		GuiFrame stripe0, stripe1;
		GuiFrame selected;
		GuiFrame bg;
		float itemSize;
		HashID scrollID;
	}

	struct State
	{
		float2 scroll;
	}
}

bool listbox(T)(ref Gui gui, 
				Rect rect, 
				ref int selected, 
				T items,
				HashID s = "listbox")
{
	import std.algorithm;

	alias Style = GuiListBox.Style;
	alias State = GuiListBox.State;

	gui.handleControl(rect);

	auto style = gui.fetchStyle!(Style)(s);

	auto length    = count(items);
	auto scrollMax =  length * style.itemSize - rect.h;
	
	
	auto hash  = HashID(rect);
	auto state = gui.fetchState(hash, State(float2(0, scrollMax)));
	scope(exit) gui.state(hash, state);

	if(length * style.itemSize > rect.h)
	{
		rect.w -= 10;
		gui.slider(Rect(rect.x + rect.w, rect.y, 10, rect.h), state.scroll.y, 0, scrollMax, style.scrollID);
		if(gui.isHovering(rect) && gui.mouse.scrollDelta.y != 0)
			updateSliderScroll(gui, state.scroll.y, 0, scrollMax);
	
	}
	else 
	{
		state.scroll.y = -rect.h + length * style.itemSize;
	}

	bool result = false;
	if(gui.wasClicked(rect))
	{
		selected = length - 1 - cast(int)((gui.mouse.location.y - rect.y + state.scroll.y) / style.itemSize);
		selected = clamp(selected, -1, cast(int)(length - 1));
		result   = true;
	}

	gui.drawQuad(rect, style.bg);
	Rect toDraw = Rect(rect.x, rect.y + rect.h - style.itemSize - (state.scroll.y - scrollMax),
					   rect.w, style.itemSize);

	int i = 0;
	foreach(item; items)
	{
		GuiFrame frame;
		if(i == selected) {
			frame = style.selected;
		}
		else
			frame = i % 2 == 0 ? style.stripe0 : style.stripe1;

		gui.drawQuad(toDraw, frame, rect);
		gui.drawText(item, toDraw, style.font, rect);

		toDraw.y -= style.itemSize;
		i++;
	}

	return result;
}

bool controlListBox(T)(ref Gui gui,
					   Rect rect,
					   T[] items,
					   bool delegate(ref Gui, Rect, ref T) itemFunc,
					   HashID s = "editListBox") 
{
	alias Style = GuiListBox.Style;
	alias State = GuiListBox.State;

//	gui.handleControl(rect);
	auto style = gui.fetchStyle!(Style)(s);
	auto scrollMax = items.length * style.itemSize - rect.h;

	auto hash  = HashID(rect, s);
	auto state = gui.fetchState(hash, State(float2.zero));
	scope(exit) gui.state(hash, state);

	bool result = false;

	void func(ref Gui _)
	{
		gui.drawQuad(rect, style.bg);
		Rect toDraw = Rect(0, rect.h - style.itemSize - (state.scroll.y - scrollMax), 
						   rect.w, style.itemSize);

		foreach(ref item; items)
		{
			result = itemFunc(gui, toDraw, item) || result;
			toDraw.y -= style.itemSize;
		}
	}

	Rect area = Rect(0,0, rect.w, items.length * style.itemSize);
	gui.scrollarea(rect, state.scroll, &func, area);
	return result;
}