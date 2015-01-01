module ui.menu;

import std.algorithm;
import ui.base, ui.controls;
import graphics;
import math;

enum MenuWindowID = 10000;

struct GuiMenu
{
	static struct Style
	{
		ubyte size, width, iconSpace, __pad;
		HashID windowID, submenuIcon;
		ubyte4 padding;


		GuiFont font;
		GuiFrame focus, highlight, idle;	
	}

	static struct State
	{
		int selected; 
		int parent;
	}
}

void renderWindow(ref Gui gui, 
				  ref GuiWindow window, 
				  ref GuiMenu.Style style, 
				  ref GuiMenu.State menuState,
				  ref Menu menu)
{
	int parent = menuState.parent;

	float height = style.font.lineHeight;
	Rect area = Rect(style.iconSpace, gui.area.h - height, gui.area.w, height);
	gui.fixRect(area);

	int childCount = 0;
	foreach(i, item; menu.items) if(item.parent == parent)
	{
		Rect copy = area;
		copy.x += style.padding.x - style.iconSpace;
		copy.y += style.padding.y;
		copy.w -= style.padding.x + style.padding.z;
		copy.h -= style.padding.y + style.padding.w;

		if(gui.isHovering(copy) || menuState.selected == childCount)
		{
			gui.drawQuad(copy, style.highlight);

			//Handle submenu
			if(item.type == MenuItemType.submenu)
			{
				auto font   = &gui.fonts.asset[style.font.font];	
				auto size   = menuSize(*font, style, menu, i);
				auto offset = (childCount + 1) * style.font.lineHeight;

				Rect r = Rect(gui.area.x + area.w, 
							  gui.area.y + (gui.area.h - offset + height) - size.y,
							  size.x, size.y);

				showPopupMenu(gui, r, window.id + 1, menu, i);
			}

			menuState.selected = childCount;
		}


		if(gui.wasClicked(copy))
		{
			if(item.method !is null)
			{
				item.method();
			}

			if(item.type != MenuItemType.submenu)
			{
				//Close Menu
				auto hash = HashID("menu");
				auto state = gui.fetchCurrentState(hash, GuiMenu.State.init);
				state.selected = -1;
				scope(exit) gui.state(hash, state);
			}
		}

		if(item.icon != HashID.init)
			gui.drawQuad(Rect(copy.x + 1, copy.y + 1, copy.h - 2, copy.h - 2), GuiFrame(item.icon, Color.white));
		if(item.type == MenuItemType.submenu)
			gui.drawQuad(Rect(copy.x + copy.w - 20, copy.y + 1, copy.h - 2, copy.h - 2), GuiFrame(style.submenuIcon, Color.white));

		gui.drawText(item.name, area, style.font, HorizontalAlignment.left, VerticalAlignment.center);
		area.y -= height;

		childCount++;
	}

}

struct NotMenuMember{ }
alias Alias(T...) = T;


float2 menuSize(ref Font font, GuiMenu.Style style, ref Menu menu, int parent)
{
	float x = 0, y = 0;
	foreach(i, item; menu.items) if(item.parent == parent) 
	{
		x  = max(x, (font.measure(item.name) * style.font.size).x);
		y += style.font.lineHeight;
	}

	return float2(x + style.width, y + style.padding.w);
}

private void showPopupMenu(ref Gui gui,Rect area,  int windowID, ref Menu menu, int item)
{
	auto hash = HashID("menu", windowID);
	//Need to do this i guess.
	auto windowState = gui.fetchState(hash, GuiMenu.State(-1, item));
	gui.state(hash, windowState);

	if(gui.guiwindow(windowID, -1, area, &menu.handleMenu, HashID("menuwindow"), false))
		gui.windows.bringToFront(windowID);
}

bool menu(ref Gui gui, ref Menu gmenu, HashID menuID = "menu")
{	
	auto hash = HashID("menu");
	auto style = gui.fetchStyle!(GuiMenu.Style)(menuID);
	auto state = gui.fetchState!(GuiMenu.State)(hash, GuiMenu.State.init);
	scope(exit) gui.state(hash, state);

	float height = style.font.lineHeight;

	Rect area = Rect(0, gui.area.h - height, 0, height);
	auto font = &gui.fonts.asset[style.font.font];	


	Rect fullRect = Rect(0, gui.area.h - height, gui.area.w, height);
	gui.handleControl(fullRect);
	gui.drawQuad(fullRect, style.idle);

	if(!gui.hasFocus())
	{
	    state.selected = -1;
	}

	int childCount = 0;
	foreach(i, item; gmenu.items) if(item.parent == -1)
	{
	    auto textSize = font.measure(item.name) * style.font.size;
	    area.w  = textSize.x;
	    area.w += style.size * 2;

	    auto copy = area;
	    gui.fixRect(copy);

	    GuiFrame frame = style.idle;
	    if(gui.hasFocus() && gui.isHovering(copy) || state.selected == i)
	    {
	        state.selected = i;
	        frame = style.focus;	
			if(item.type == MenuItemType.submenu)
			{
				auto font   = &gui.fonts.asset[style.font.font];	
				auto size   = menuSize(*font, style, gmenu, i);

				Rect r = Rect(copy.x, copy.y - size.y, size.x, size.y);

				showPopupMenu(gui, r, MenuWindowID, gmenu, i);
			}
		}
		else if(gui.isHovering(copy))
			frame = style.highlight;

	    gui.drawQuad(copy, frame);
	    gui.drawText(item.name, copy, style.font, HorizontalAlignment.center, VerticalAlignment.center);

	    area.x += area.w;
		childCount++;
	}

	return false;
}

struct Menu
{
	void* context;
	List!MenuItem items;

	this(A, T)(ref A allocator, T* context, int size)
	{
		items = List!MenuItem(allocator, size);
		this.context = context;
		constructMenu(*context, this, -1);
	}

	this(A)(ref A allocator, int size)
	{
		context = null;
		items = List!MenuItem(allocator, size);
	}

	int addSubmenu(string name, int parent = -1)
	{
		items ~= MenuItem(parent, HashID.init, name, null, MenuItemType.submenu);
		return items.length - 1;
	}

	void addItem(string name, void delegate() method, int parent)
	{
		items ~= MenuItem(parent, HashID.init, name, method, MenuItemType.normal);
	}

	private void handleMenu(ref Gui gui, ref GuiWindow window)
	{
		auto hash = HashID("menu", window.id);

		auto oldstate = gui.fetchState(hash, GuiMenu.State.init);
		auto newstate = gui.fetchCurrentState(hash, GuiMenu.State.init);

		auto style = gui.fetchStyle!(GuiMenu.Style)(HashID("menu"));
		auto state = newstate != GuiMenu.State.init ? newstate : oldstate;
		scope(exit) gui.state(hash, state);

		if(state.parent == -1) return;

		renderWindow(gui, window, style, state, this);
	}
}

//Okey So we Deconstruct it
struct MenuItem
{
	int parent;
	HashID icon;
	string name;
	void delegate() method;
	MenuItemType type;
}

enum MenuItemType
{
	normal, 
	submenu
}


void constructMenu(T)(ref T t, ref Menu menu, int parent)
{
	foreach(i, member; menuItems!(T)) 
	{
		MenuItem item;
		item.parent = parent;
		item.icon   = menuItemIcon!(member, T);
		item.name   = member;

		static if(isFunction!(member, T))
			mixin("item.method = &t." ~ member ~ ";");
		else 
			item.method = null;

		static if(isMenu!(member, T))
			item.type = MenuItemType.submenu;
		else 
			item.type = MenuItemType.normal;

		menu.items.put(item);

		static if(isMenu!(member, T))
		{
			alias type = typeof(__traits(getMember, t, member));
			int current = menu.items.length - 1;
			mixin("constructMenu!(type)(t." ~ member ~ ", menu, current);");
		}
	}
}

template menuItemIcon(string member, T)
{
	HashID icon()
	{
		alias attribs = Alias!(__traits(getAttributes, mixin("T." ~ member)));
		foreach(attrib; attribs)
		{
			static if(is(typeof(attrib) == MenuItem))
			{
				return attrib.icon;
			}
		}
		return HashID.init;
	}

	enum menuItemIcon = icon();
}

template menuItemName(string member, T)
{
	string name()
	{
		alias attribs = Alias!(__traits(getAttributes, mixin("T." ~ member)));
		foreach(attrib; attribs)
		{
			static if(is(typeof(attrib) == MenuItem))
			{
				return attrib.name != "" ? attrib.name : member;
			}
		}
		return member;
	}

	enum menuItemName = name();
}

template isFunction(string member, T)
{
	import std.traits;
	enum isFunction = isCallable!(__traits(getMember, T.init, member));
}

template isMenuMember(string member, T)
{
	import std.typetuple;

	alias attribs = Alias!(__traits(getAttributes, mixin("T." ~ member)));
	enum index   = staticIndexOf!(NotMenuMember, attribs);

	enum isMenuMember = staticIndexOf!(member, "this", "__ctor", "__dtor") == -1 && index == -1;
}

template isMenu(string member, T)
{
	enum isMenu = is(typeof(__traits(getMember, T.init, member)) == struct);
}

template menuItems(T)
{
	template pred(string member)
	{
		enum pred = isMenuMember!(member, T);
	}

	import std.typetuple;
	alias menuItems = Filter!(pred, TypeTuple!(__traits(allMembers, T)));
}