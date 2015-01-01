module enumfield;

import ui;
import std.traits;
import std.algorithm;
import util.strings;

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
		bool active;
		uint enumValue;
	}
}

void enumWindow(Enum)(ref Gui gui, ref GuiWindow window)
{
	auto styleID = HashID("enumfield");
	auto style = gui.fetchStyle!(GuiEnum.Style)(styleID);

	float height = style.font.lineHeight;
	Rect area = Rect(style.padding.x, gui.area.h - height - style.padding.y, gui.area.w - style.padding.x * 2, height);
	gui.fixRect(area);
	
	foreach(i, member; EnumMembers!(Enum)) 
	{
		Rect item = area;
		item.h -= style.spacing;

		if(gui.isHovering(item))
		{
			gui.drawQuad(item, style.highlight);
		}

		if(gui.wasClicked(item))
		{
			auto state = gui.fetchCurrentState(styleID, GuiEnum.State.init);
			state.active = false;
			state.enumValue = member;
			gui.state(styleID, state);
		}

		gui.drawText(text1024(member), item, style.font, HorizontalAlignment.left, VerticalAlignment.center);
		area.y -= height + style.spacing;
	}
}

float2 enumWindowSize(Enum)(ref Gui gui, ref GuiEnum.Style style)
{
	auto font = &gui.fonts.asset[style.font.font];	

	float x = 0, y = 0;
	foreach(i, member; EnumMembers!Enum)
	{
		x  = max(x, (font.measure(text1024(member)) * font.size).x);
		y += style.font.lineHeight + style.spacing;
	}
	
	return float2(x + style.padding.x * 2, y + style.padding.y);
}

bool enumField(Enum)(ref Gui gui, Rect rect, ref Enum enum_, HashID styleID = "enumfield")
{
	gui.handleControl(rect);
	auto style = gui.fetchStyle!(GuiEnum.Style)(styleID);
	auto state = gui.fetchState(styleID, GuiEnum.State(false, uint.max));

	if(state.active && gui.hasFocus())
	{
		import ui_window;
		import std.functional;

		float2 size = enumWindowSize!Enum(gui, style);
		Rect windowArea = Rect(rect.x, rect.y - size.y, max(size.x, rect.w), size.y + style.padding.y);
		
		gui.guiwindow(100, -1, positionMenu(gui.area, windowArea), toDelegate(&enumWindow!Enum), HashID("menuwindow"), false);
		gui.windows.bringToFront(100);
	}


	gui.drawQuad(rect, style.bg);
	foreach(i, member; EnumMembers!(Enum))
	{
		if(member == enum_)
		{
			gui.drawText(text1024(member), rect, style.font, HorizontalAlignment.center, VerticalAlignment.center);
			break;
		}
	}

	if((gui.wasClicked(rect) || state.active) && gui.hasFocus())
	{
		state.active = true;
		state.enumValue = enum_;
		gui.state(styleID, state);
	}

	if(state.enumValue != uint.max && state.enumValue != enum_)
	{
		enum_ = cast(Enum)state.enumValue;
		return true;
	}

	return false;
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