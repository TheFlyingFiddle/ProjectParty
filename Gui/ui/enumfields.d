module ui.enumfields;

import ui.base;

import std.traits;
import std.algorithm;
import util.strings;

struct NameGen
{
	bool function(int i, ref string s, void* context) func;
	void[16] context;

	this(T)(T t, bool function(int i, ref string s, void* context) func) if(T.sizeof <= 16)
	{
		*cast(T*)(context.ptr) = t;
		this.func = func;
	}

	this(bool function(int i, ref string s, void* context) func)
	{
		this.func = func;
	}

	bool opCall(int i, ref string s)
	{
		return func(i, s, context.ptr);
	}
}

struct GuiEnum
{
	struct Style
	{
		GuiFrame bg, highlight;
		GuiFont  font;
		float2	 padding;
		float    spacing;
	}

	struct State
	{
		bool		active;
		uint		selected;

		NameGen     nameGen;
	}
}

import log;
void enumWindow(ref Gui gui, ref GuiWindow window)
{
	auto styleID = HashID("enumfield");
	auto style = gui.fetchStyle!(GuiEnum.Style)(styleID);

	float height = style.font.lineHeight;
	Rect area = Rect(style.padding.x, gui.area.h - height - style.padding.y, gui.area.w - style.padding.x * 2, height);
	gui.fixRect(area);

	auto state = gui.fetchCurrentState(styleID, GuiEnum.State.init);

	int index = 0;
	while(true)
	{
		string member;
		if(state.nameGen.func && state.nameGen(index++, member))
		{
			Rect item = area;
			item.h -= style.spacing;

			if(gui.isHovering(item))
			{
				gui.drawQuad(item, style.highlight);
			}

			if(gui.wasClicked(item))
			{
				state.active = false;
				state.selected = index - 1;
				gui.state(styleID, state);
				break;
			}

			gui.drawText(member, item, style.font, HorizontalAlignment.left, VerticalAlignment.center);
			area.y -= height + style.spacing;	
		}
		else break;
	}
}

float2 selectionWindowSize(ref Gui gui, ref GuiEnum.Style style, NameGen nameGen)
{
	auto font = &gui.fonts.asset[style.font.font];	

	float x = 0, y = 0;
	int index;
	while(true)
	{
		string member;
		if(nameGen(index++, member))
		{
			x  = max(x, (font.measure(member) * font.size).x);
			y += style.font.lineHeight + style.spacing;
		} else break;
	}

	return float2(x + style.padding.x * 2, y + style.padding.y);
}

int enumIndex(Enum)(Enum value)
{
	foreach(i, e; EnumMembers!Enum)
	{
		if(e == value) return i;
	}

	assert(0, "Invalid enum value");
}


Enum fromIndex(Enum)(int idx)
{
	foreach(i, e; EnumMembers!Enum)
	{
		if(i == idx) return e;
	}
	assert(0, "Invalid enum value");
}

bool enumField(Enum)(ref Gui gui, Rect rect, ref Enum enum_, HashID styleID = "enumfield")
{
	import std.functional;
	int idx  = enumIndex!Enum(enum_);
	auto nameGen = NameGen(&enumNameGen!Enum);
	
	if(selectionfield(gui, rect, idx, nameGen, styleID))
	{
		enum_ = fromIndex!Enum(idx);
		return true;
	}
	else 
	{
		return false;
	}
}

bool selectionfield(Items)(ref Gui gui, Rect rect, ref int selected, Items items, HashID styleID = "enumfield")
{
	auto gen = itemNameGen(items);
	return selectionfield(gui, rect, selected, gen, styleID);
}

bool selectionfield(ref Gui gui, Rect rect, ref int selected, NameGen nameGen, HashID styleID = "enumfield")
{
	gui.handleControl(rect);
	auto style = gui.fetchStyle!(GuiEnum.Style)(styleID);
	GuiEnum.State state;

	if(gui.hasFocus())
	{
		state = gui.fetchState(styleID, GuiEnum.State(false, uint.max, nameGen));
	}
	else 
	{
		state = GuiEnum.State(false, uint.max, nameGen);
	}

	if(state.active && gui.hasFocus())
	{
		import ui.window;
		import std.functional;

		float2 size = selectionWindowSize(gui, style, nameGen);
		Rect windowArea = Rect(rect.x, rect.y - size.y, max(size.x, rect.w), size.y + style.padding.y);

		gui.guiwindow(100, -1, positionMenu(gui.area, windowArea), toDelegate(&enumWindow), HashID("menuwindow"), false);
		gui.windows.bringToFront(100);
	}


	gui.drawQuad(rect, style.bg);

	string s;
	if(nameGen(selected, s))
	{
		gui.drawText(s, rect, style.font, HorizontalAlignment.center, VerticalAlignment.center);
	}

	if((gui.wasClicked(rect) || state.active) && gui.hasFocus())
	{
		state.active = true;
		state.selected = selected;
		gui.state(styleID, state);
	}

	if(state.selected != uint.max && state.selected != selected)
	{
		selected = state.selected;
		return true;
	}
	return false;
}

bool enumNameGen(Enum)(int i, ref string s, void* context)
{
	static string[] names =  [__traits(allMembers, Enum)];
	if(i >= names.length) return false;

	s = names[i];

	return true;
}

NameGen itemNameGen(Items)(Items items)
{
	static bool impl(int i, ref string s, void* context)
	{
		Items items = *cast(Items*)context;
		if(i >= items.length) return false;
		
		s = items[i];
		return true;
	}

	pragma(msg, Items.sizeof);

	return NameGen(items, &impl);
}


ref Rect positionMenu(Rect fullArea, ref Rect menuArea)
{
	Rect section = menuArea.intersection(fullArea);
	if(section == menuArea) return menuArea;

	if(menuArea.y < 0)
		menuArea.y = 0;

	if(menuArea.x < 0)
		menuArea.y = 0;

	return menuArea;
}