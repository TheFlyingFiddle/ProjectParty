module ui.window;

import ui.base;
import ui.controls;
import std.algorithm;

enum Side
{
	none = 0x00,
	left = 0x01,
	right = 0x02,
	bottom = 0x04,
	top   = 0x08
}

alias WindowHandler = void delegate(ref Gui, ref GuiWindow);

struct GuiWindow
{
	int id;

private: 
	Rect area;
	WindowHandler controls;
	HashID style;

	Rect oldArea;
	bool active;
	int parent, order;

	//Should These Really Be part of window? 
	//They are only used by some windows.
	bool canFocus;
	Side resizeSide;
	bool isDraging;
	int  focus;

public:

	this(int id, int parent, 
		 Rect area, 
		 bool canFocus,
		 WindowHandler controls,
		 HashID style)
	{
		this.id = id;
		this.parent = parent;
		this.area = area;
		this.controls = controls;
		this.style = style;
		this.oldArea = area;
		this.active = false;
		this.order  = 0;

		this.canFocus = canFocus;
		resizeSide = Side.none;
		isDraging  = false;
		focus  = -2;
	}

	align(1) struct Style
	{
		align(1):
		Color focusColor, nonFocusColor;
		GuiFrame bg;
		GuiFont font;
		float titleHeight;

		HashID closeButton;
		ubyte4 padding;
	}
}

struct WindowManager
{
	private Table!(int, GuiWindow) windows;
	private Rect drag;
	private int active;

	@property GuiWindow* activeWindow()
	{
		return &windows[active];
	}

	this(A)(ref A allocator)
	{
		windows		= Table!(int, GuiWindow)(allocator, 20);
		drag		= Rect.empty;
		active		= -1;
	}

	void genOverlappingRects(ref Gui gui, ref GuiWindow window)
	{
		void impl(ref GuiWindow w)
		{
			import std.algorithm;
			foreach(ref wind; windows)
			{
				if((wind.parent == w.parent && 
				    wind.id != w.id &&
				    wind.order >= w.order) || 
				   wind.parent == w.id &&
				   wind.id != window.id)
				{
					Rect windRect = windowArea(wind.id);
					gui.overlaping ~= windRect;
				} 
			}

			auto parent = w.parent in windows; 
			if(!parent) return;

			impl(*parent);
		}

		gui.overlaping.clear();
		gui.overlaping ~= drag;

		impl(window);
	}

	bool delayWindow(int windowID,
					 int parentID,
					 ref Rect rect,
					 bool canFocus,
					 WindowHandler controls,
					 HashID guiwindowID)
	{
		auto wind = windowID in windows;
		auto isNewWindow = wind is null;
		if(wind)
		{
			if(rect == wind.oldArea) {
				wind.oldArea = wind.area;
				rect = wind.area;
			} else {
				wind.oldArea = rect;
				wind.area    = rect;
			}

			if(wind.parent != parentID) //reparent
			{
				wind.parent = parentID;
				wind.order = 0;
			}
		}
		else
		{
			windows[windowID] = GuiWindow(windowID, parentID, rect, canFocus, controls, guiwindowID);
			wind = windowID in windows;
		}

		wind.active = true;

		return isNewWindow;
	}

	Rect windowArea(int id)
	{
		if(id == -1) return Rect(0,0,100000,10000);

		static struct Bounds
		{
			Rect r;
			float2 o;
		}

		Bounds impl(int id)
		{
			if(id == -1) return Bounds(Rect(0,0,10000,10000), float2.zero); //Fix this
			else 
			{
				auto w = id in windows;
				if(!w) return Bounds(Rect.empty, float2.zero);

				Bounds a   = impl(w.parent);
				Rect p	   = a.r;
				Rect res   = Rect(w.area.x + p.x, w.area.y + p.y, w.area.w, w.area.h);

				if(res.x + res.w > p.x + p.w)
					res.w -= (res.x + res.w - (p.x + p.w));
				if(res.y + res.h > p.y + p.h)
					res.h -= (res.y + res.h - (p.y + p.h));

				float2 o = float2.zero;
				if(res.x < p.x)
					o.x = p.x - res.x;
				if(res.y < p.y)
					o.y = (p.y - res.y);

				if(a.o.x > w.area.x)
					o.x = (a.o.x - w.area.x);
				if(a.o.y > w.area.y)
					o.y = (a.o.y - w.area.y);

				return Bounds(res, o);				
			}
		}

		auto w    = windows[id];
		Bounds p  = impl(w.parent);

		Rect moved = Rect(w.area.x + p.r.x, w.area.y + p.r.y, w.area.w, w.area.h);		
		if(p.o.x > w.area.x)
		{
			moved.x += (p.o.x - w.area.x);
			moved.w -= (p.o.x - w.area.x);
		}

		if(p.o.y > w.area.y)
		{
			moved.y += (p.o.y - w.area.y);
			moved.h -= (p.o.y - w.area.y);
		}

		return intersection(p.r, moved);
	}

	float2 windowLoc(int id)
	{
		if(id == -1) return float2.zero;
		else 
		{
			auto w  = windows[id];
			return w.area.xy + windowLoc(w.parent); 
		}
	}

	void render(ref Gui gui)
	{
		renderSubWindows(gui, -1);

		int[20] toRemove;
		int length = 0;
		foreach(key, ref wind; windows)
		{
			if(!wind.active)
				toRemove[length++] = key;
		}

		foreach(key;toRemove[0 .. length])
		{
			windows.remove(key);		
		}

		foreach(ref wind; windows)
			wind.active = false;

		gui.overlaping.clear();
		gui.overlaping ~= drag;
		foreach(ref wind; windows)
		{
			auto area = windowArea(wind.id);
			if(gui.wasDown(area) && wind.canFocus)
			{
				gui.unfocus();
			}

			gui.overlaping ~= area;
		}
	}

	void renderSubWindows(ref Gui gui, int active)
	{
		int[20] indices;
		int count = 0;
		foreach(key, value; windows) 
			if(value.parent == active)
			{
				indices[count++] = key;
			}

		indices[0 .. count].sort!((a,b) => windows[a].order < windows[b].order);

		foreach(i; 0 .. count)
		{
			auto window = &windows[indices[i]];
			genOverlappingRects(gui, *window);

			handleFocus(gui, *window);
			renderWindow(gui, *window);
			renderSubWindows(gui, window.id);
		}
	}

	void handleFocus(ref Gui gui, ref GuiWindow window)
	{
		auto area = windowArea(window.id);
		if(gui.wasDown(area))
		{
			bringToFront(window);
		}
	}

	void bringToFront(int windowID)
	{
		if(auto wind = windowID in windows)
			bringToFront(*wind);
	}

	void bringToFront(ref GuiWindow window)
	{
		int m = 0;
		foreach(id, ref wind; windows) if(wind.parent == window.parent)
		{
			m = max(wind.order, m);
		}

		window.order = m + 1;
	}

	void bringToBack(ref GuiWindow window)
	{
		window.order = 0;
	}

	bool isDragging()
	{
		return this.drag != Rect.empty;
	}

	void beginDrag(Rect rect)
	{
		this.drag = rect;
	}

	void endDrag()
	{
		this.drag  = Rect.empty;
	}

	bool hasFocus(int windowID)
	{
		auto wind = windowID in windows;
		if(!wind) return true;

		foreach(ref w; windows) if(w.parent == wind.parent)
		{
			if(w.order > wind.order) return false;
		}

		return hasFocus(wind.parent);
	}

	void renderWindow(ref Gui gui, ref GuiWindow window)
	{
		this.active = window.id;

		auto hash = HashID(window.id, "guiwindow");
		auto style = gui.fetchStyle!(GuiWindow.Style)(window.style);

		Rect clientRect = windowArea(window.id);
		gui.drawQuad(clientRect, style.bg); 

		Color c = hasFocus(window.id) ? style.focusColor : style.nonFocusColor;
		gui.drawQuadOutline(clientRect, 1.0f, GuiFrame("pixel", c));

		clientRect.h -= style.titleHeight;

		float2 pos = windowLoc(window.id);
		auto oldState = gui.beginSubArea(clientRect, pos - clientRect.xy, window.focus);
		scope(exit) gui.guiState = oldState;

		window.controls(gui, window);
		window.focus = gui.focus;

		if(hasFocus(window.id))
		{
			gui.drawFocused();
		}
		else 
		{
			window.focus = -2;
		}
	}
}

void dragWindow(ref Gui gui)
{
	auto window = gui.windows.activeWindow;

	auto hash = HashID(window.id, "guiwindow");
	auto style = gui.fetchStyle!(GuiWindow.Style)(window.style);

	auto old = gui.area;
	gui.area.h += style.titleHeight;
	scope(exit) gui.area = old;


	Rect area	   = gui.windows.windowArea(window.id);
	Rect dragArea  = Rect(area.x, area.y + area.h - style.titleHeight,
						  area.w, style.titleHeight - 5);

	if((gui.wasDown(dragArea) || 
		(window.isDraging && gui.mouse.isDown(MouseButton.left)))
	   && window.resizeSide == Side.none)
	{
		if(!window.isDraging) {
			gui.windows.beginDrag(area);
		}

		window.isDraging = true;
		window.area.displace(gui.mouse.moveDelta);
	} 
	else if(window.isDraging || window.resizeSide != Side.none)
	{
		gui.windows.endDrag();
		window.isDraging = false;
	} 
}

void resizeWindow(ref Gui gui)
{
	auto window = gui.windows.activeWindow;

	auto hash = HashID(window.id, "guiwindow");
	auto style = gui.fetchStyle!(GuiWindow.Style)(window.style);

	auto old = gui.area;
	gui.area.h += style.titleHeight;
	scope(exit) gui.area = old;

	Rect area	   = gui.windows.windowArea(window.id);
	if(gui.mouse.isDown(MouseButton.left) && !window.isDraging)
	{
		Rect lower = area; lower.h = 5;
		Rect upper = area; upper.h = 5; upper.y = area.y + area.h - 5;
		if(gui.wasDown(lower) || (window.resizeSide & Side.bottom) == Side.bottom)
		{	
			window.area.y += gui.mouse.moveDelta.y;
			window.area.h -= gui.mouse.moveDelta.y; 
			window.resizeSide |= Side.bottom;
		} 
		else if(gui.wasDown(upper) || (window.resizeSide & Side.top) == Side.top)
		{	
			window.area.h += gui.mouse.moveDelta.y; 
			window.resizeSide |= Side.top;
		}
		Rect left  = area; left.w = 5;
		Rect right = area; right.w = 5; right.x = area.x + area.w - 5;
		if(gui.wasDown(left) || (window.resizeSide & Side.left) == Side.left)
		{	
			window.area.x += gui.mouse.moveDelta.x;
			window.area.w -= gui.mouse.moveDelta.x; 
			window.resizeSide |= Side.left;
		} 
		else if(gui.wasDown(right) || (window.resizeSide & Side.right) == Side.right)
		{	
			window.area.w += gui.mouse.moveDelta.x; 
			window.resizeSide |= Side.right;
		}
	}
	else
	{
		window.resizeSide = Side.none;
	}
}

void windowContent(ref Gui gui, const(char)[] title, GuiFrame frame = GuiFrame.init)
{
	auto window   = gui.windows.activeWindow;
	auto winStyle = gui.fetchStyle!(GuiWindow.Style)(window.style);
	auto font =  winStyle.font;

	auto old = gui.area;
	gui.area.h += winStyle.titleHeight;
	scope(exit) gui.area = old;


	Rect frameArea = Rect.empty;
	if(frame != GuiFrame.init)
	{
		frameArea = Rect(winStyle.padding.x, window.area.h - winStyle.titleHeight + winStyle.padding.y,
						 winStyle.titleHeight - winStyle.padding.z - winStyle.padding.x, 
						 winStyle.titleHeight - winStyle.padding.w - winStyle.padding.y);
		Rect c = frameArea;
		gui.fixRect(c);

		gui.drawQuad(c, frame);
	}

	Rect area = Rect(frameArea.w + 5, window.area.h - winStyle.titleHeight, 
					 window.area.w, winStyle.titleHeight);

	gui.fixRect(area);
	gui.drawText(title, area.xy + float2(winStyle.padding.x, winStyle.padding.y + winStyle.padding.w), area, font);
}

bool closeWindow(ref Gui gui, )
{
	auto window   = gui.windows.activeWindow;
	auto winStyle = gui.fetchStyle!(GuiWindow.Style)(window.style);
	auto style = winStyle.closeButton;

	auto old = gui.area;
	gui.area.h += winStyle.titleHeight;
	scope(exit) gui.area = old;

	Rect area		= window.area;
	Rect buttonArea = Rect(area.w - winStyle.titleHeight, 
						   area.h - winStyle.titleHeight + winStyle.padding.y,
						   winStyle.titleHeight - winStyle.padding.z - winStyle.padding.x, 
						   winStyle.titleHeight - winStyle.padding.w - winStyle.padding.y);

	auto index = gui.overlaping.countUntil!(x => x == gui.windows.drag);
	if(index != -1) 
		gui.overlaping.removeAt(index);
	scope(exit) gui.overlaping ~= gui.windows.drag;

	return gui.button(buttonArea, "X", style);
}



int activeWindowID(ref Gui gui)
{
	return gui.windows.active;
}

bool guiwindow(ref Gui gui,
			   int windowID,
			   int parentID,
			   ref Rect rect, 
			   void delegate(ref Gui, ref GuiWindow) controls,
			   HashID guiwindowID = "guiwindow",
			   bool canFocus = true)
{
	return gui.windows.delayWindow(windowID, parentID, rect, canFocus, controls, guiwindowID);
}


bool guiwindow(ref Gui gui,
			   int windowID,
			   ref Rect rect, 
			   void delegate(ref Gui, ref GuiWindow) controls,
			   HashID guiwindowID = "guiwindow",
			   bool canFocus = true)
{
	return gui.windows.delayWindow(windowID, -1, rect,canFocus,  controls, guiwindowID);
}
