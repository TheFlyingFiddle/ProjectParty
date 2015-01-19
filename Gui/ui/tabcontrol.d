module ui.tabcontrol;
import ui.base;
import ui.textfield;
import ui.controls;

struct GuiTabs
{
	struct Style
	{
		GuiFrame pageBg;
		HashID	 toolbarStyle; 
		float	toolbarSize;
	}

	struct State
	{
		float2 scroll;
		int    focused;
		bool   focusLocked;
	}
}

struct TabPage
{
	GuiElement element;
	void delegate(ref Gui) guidel;

	this(T)(auto ref T t, void delegate(ref Gui) guidel)
	{
		this.element = t;
		this.guidel = guidel;
	}
}

import std.range;
bool tabs(Pages)(ref Gui gui, Rect rect, ref int selected, 
				 Pages pages, HashID s = "tabs")
if(isRandomAccessRange!Pages)
{
	auto style = gui.skin[s].get!(GuiTabs.Style);
	auto ptr   = bytesHash(rect) in gui.old;
	auto state = ptr ? (*ptr).get!(GuiTabs.State) : GuiTabs.State(float2.zero, -1, false);

	auto subgui = Gui(gui, rect, float2.zero, state.focused, state.focusLocked);
	auto toolbarRect = Rect(0, rect.h - style.toolbarSize, rect.w, style.toolbarSize); 
	auto select = subgui.toolbar(toolbarRect, selected, pages.map!(x => x.element));

	auto pageRect = Rect(rect.x, rect.y, rect.w, rect.h - style.toolbarSize);
	if(gui.hasFocus(rect))
		gui.lockFocus();

	gui.drawQuad(pageRect, style.pageBg);
	pages[selected].guidel(subgui);

	//Basically A Button Group to find selection index
	//Draw background for the tab control. 
	//Needs to be a scrollable area
	state.focused = subgui.focus;
	state.focusLocked = subgui.focusLocked;
	gui.state[bytesHash(s)] = VariantN!32(state);

	return select;
}