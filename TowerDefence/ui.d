module ui;

public import content;
public import collections;
public import rendering.gui_renderer;
public import window.mouse, window.keyboard, window.clipboard;
public import util.variant;
public import util.hash;
public import rendering;

enum HorizontalAlignment : ubyte
{
	left,
	right,
	center
}

enum VerticalAlignment : ubyte
{
	bottom,
	top, 
	center
}

struct Rect
{
	float x, y, w, h;
	this(float x, float y, float w, float h)
	{
		this.x = x; this.y = y;
		this.w = w; this.h = h;
	}

	this(float4 f)
	{
		this(f.x, f.y, f.z - f.x, f.w - f.y);
	}


	alias toFloat4 this;

	float4 toFloat4()
	{
		return float4(x, y, x + w, y + h);
	}

	bool contains(float2 point)
	{
		return x < point.x &&  x + w > point.x &&
			   y < point.y &&  y + h > point.y;
	}

	void displace(float2 offset)
	{
		this.x += offset.x;
		this.y += offset.y;
	}

	static Rect empty() { return Rect(0,0,0,0); }
}

Rect intersection(ref Rect first, ref Rect second)
{
	import std.algorithm;
	float4 f = first.toFloat4, g = second.toFloat4;

	float4 r;
	r.x = max(f.x, g.x);
	r.y = max(f.y, g.y);
	r.z = min(f.z, g.z);
	r.w = min(f.w, g.w);

	auto res =  Rect(r.x, r.y, r.z - r.x, r.w - r.y);
	if(res.w < 0 || res.h < 0) return Rect(0,0,0,0);
	else return res;
}

Rect padded(ref Rect r, float2 p)
{
	return Rect(r.x + p.x, r.y + p.y, r.w - p.x * 2, r.h - p.y * 2);
}

struct GuiFrame
{
	HashID frame;
	Color  color;

	this(string s, Color c)
	{
		frame = bytesHash(s);
		color = c;
	}

	this(HashID f, Color c)
	{
		frame = f;
		color = c;
	}
}

struct GuiFont
{
	HashID font;
	Color  color;
	float2 thresholds;
	float2 size;

	this(string s, Color c, float2 sz, float2 thresh)
	{
		font = bytesHash(s);
		color = c;
		size  = sz;
		thresholds = thresh;
	}
}

struct GuiTooltipStyle
{
	GuiFont font;
}

struct ButtonObj
{
	string text;
	string tooltip;
}

alias EditText = List!char;

struct GuiState
{
	float4 fullArea;
	float2 offset;
	Rect area;
	Rect focusRect;
	uint focus;
	uint controlCount;
}

struct WindowState
{

	int id;
	Rect area;
	void delegate(Rect, ref Gui) controls;
	HashID style;

	Rect oldArea;
	bool active;
	int parent, order;
}

struct Gui
{
	import std.algorithm;

	private GuiRenderer* renderer;
	VariantTable!(64) skin;
	private Table!(HashID, VariantN!32) oldControlStates;
	private Table!(HashID, VariantN!32) controlStates;
	private List!WindowState windows;

	private int activeWindow, parentWindow;

	AtlasHandle  atlas;
	FontHandle   fonts;

	Rect drag;

	Keyboard* keyboard;
	Mouse*	 mouse;
	Clipboard* clipboard;

	GuiState guiState;


	//We need to store some sort of delta state so
	//that frame transitions work ok. 
	this(A)(ref A allocator, 
			AtlasHandle atlas,
			FontHandle  fonts,
			VariantTable!(64) skin,
			GuiRenderer* renderer,
			Keyboard* keyboard, 
			Mouse* mouse,
			Clipboard* clipboard,
			Rect area)
	{
		this.renderer	  = renderer;
		this.atlas		  = atlas;
		this.fonts		  = fonts;
		this.skin		  = skin;

		this.keyboard	  = keyboard;
		this.mouse		  = mouse;
		this.clipboard    = clipboard;
	

		oldControlStates	  = Table!(HashID, VariantN!32)(allocator, 100);
		controlStates = Table!(HashID, VariantN!32)(allocator, 100); 

		windows    = List!WindowState(allocator, 20);

		this.guiState.fullArea	  = area;
		this.guiState.area		  = area;
		this.guiState.offset	  = float2.zero;
		this.guiState.controlCount  = 0;
		this.guiState.focus		  = -1;

		this.drag			=  Rect.empty;
		this.activeWindow	= -1;
		this.parentWindow	= -1;
	}

	GuiState beginSubArea(Rect area, float2 offset, int focused)
	{
		GuiState old = this.guiState;
		
		Rect newArea = intersection(area, this.guiState.area);
		offset		= offset - (newArea.xy - area.xy);

		this.guiState.area		   = newArea;
		this.guiState.fullArea	   = Rect(area);
		this.guiState.offset	   = offset;
		this.guiState.focus		   = focused;
		this.guiState.controlCount = 0;

		return old;
	}

	void endSubArea(GuiState oldState)
	{
		guiState = oldState;
	}

	bool wasClicked(Rect rect)
	{
		Rect r = intersection(rect, guiState.area);
		return mouse.wasReleased(MouseButton.left) &&
			r.contains(mouse.location) &&
			r.contains(mouse.state(MouseButton.left).lastDown) &&
			!isCovered(mouse.state(MouseButton.left).lastDown);
	}

	bool isCovered(float2 point)
	{
		bool impl(int windowID, int parentID)
		{
			auto index = windows.countUntil!(x => x.id == windowID);
			WindowState* state;
			if(index != -1) state = &windows[index];

			import std.algorithm;
			foreach(ref wind; windows)
			{
				if(wind.parent == parentID && wind.id != windowID)
				{
					bool result = state ? state.order < wind.order : true;
					Rect windRect = windowArea(wind.id);
					if(result && windRect.contains(point))
						return true;
				} 
			}

			if(state.parent == -1) return false;

			index = windows.countUntil!(x => x.id == parentID);
			if(index == -1)
				return false;
			
			return impl(windows[index].id, windows[index].parent);
		}

		return impl(activeWindow, parentWindow) || drag != Rect.empty;
	}

	bool isDown(Rect rect)
	{
		Rect r = intersection(rect, guiState.area);
		return mouse.isDown(MouseButton.left) &&
			r.contains(mouse.location) &&
			!isCovered(mouse.location);
	}

	bool wasDown(Rect rect)
	{
		Rect r = intersection(rect, guiState.area);
		return mouse.isDown(MouseButton.left) &&
			r.contains(mouse.state(MouseButton.left).lastDown) &&
			!isCovered(mouse.state(MouseButton.left).lastDown);
	}

	bool isHovering(Rect rect)
	{
		Rect r = intersection(rect, guiState.area);
		return r.contains(mouse.location) && !isCovered(mouse.location);
	}

	bool hasFocus()
	{
		return guiState.focus == guiState.controlCount - 1;
	}

	bool nextHasFocus()
	{
		return guiState.focus == guiState.controlCount;
	}

	T fetchState(T)(HashID id, T default_)
	{
		auto ptr   = id in oldControlStates;
		auto state = ptr ? ptr.get!(T) : default_;
		return state;
	}

	T fetchStyle(T)(HashID id)
	{
		return skin[id].get!(T);
	}

	void state(T)(HashID id, T state)
	{
		controlStates[id] = VariantN!(32)(state);
	}

	void fixRect(ref Rect rect)
	{
		import std.algorithm; 
		rect.x += guiState.area.x;
		rect.y += guiState.area.y;

		guiState.fullArea.x = min(rect.x, guiState.fullArea.x);
		guiState.fullArea.y = min(rect.y, guiState.fullArea.y);
		guiState.fullArea.z = max(rect.x + rect.w, guiState.fullArea.z);
		guiState.fullArea.w = max(rect.y + rect.h, guiState.fullArea.w);

		rect.x += guiState.offset.x;
		rect.y += guiState.offset.y;
	}

	bool handleControl(ref Rect rect)
	{
		fixRect(rect);

		if(wasDown(rect))
			guiState.focus = guiState.controlCount;
		guiState.controlCount++;

		if(hasFocus())
		{
			guiState.focusRect = rect;
			return true;
		}

		return false;
	}

	void drawTooltip(Rect rect, const(char)[] tooltip)
	{
		GuiTooltipStyle style = skin.tooltip.get!(GuiTooltipStyle);
		renderer.drawText(tooltip, float2.zero, float2(30), 
						  fonts.asset[style.font.font], 
						  style.font.color,
						  style.font.thresholds);
	}

	void drawLine(Frame)(float2 start, float2 end, float width, auto ref Frame frame)
	{
		renderer.drawLine(start, end, width, atlas.asset[frame.frame], frame.color);
	}

	void drawQuad(Frame)(Rect rect, auto ref Frame frame)
	{
		renderer.drawQuad(rect, atlas.asset[frame.frame], frame.color, guiState.area);
	}

	void drawQuad(Frame)(Rect rect, auto ref Frame frame, Color color)
	{
		renderer.drawQuad(rect, frame, color, guiState.area);
	}

	void drawText(const(char[]) text, float2 pos, Rect rect, ref GuiFont font)
	{
		renderer.drawText(text, pos, font.size, fonts.asset[font.font], 
						  font.color, font.thresholds, intersection(rect, guiState.area));
	}

	void begin()
	{
		updateFocus();

		import std.algorithm;
		swap(controlStates, oldControlStates);
		controlStates.clear();

		foreach(ref wind; windows)
			wind.active = false;

		renderer.begin();
	}

	void updateFocus()
	{
		guiState.fullArea = guiState.area.toFloat4;
		if(keyboard.wasInput(Key.tab))
			guiState.focus++;
		guiState.controlCount = 0;
	}

	void drawFocused()
	{
		if(guiState.focus != -1 && guiState.focus < guiState.controlCount)
		{
			renderer.drawQuadOutline(intersection(guiState.area, guiState.focusRect), 1.0f, atlas.asset.pixel, Color.black);
		}
	}

	void end()
	{
		drawFocused();
		renderSubWindows(-1);

		foreach_reverse(i; 0 .. windows.length)
		{
			if(!windows[i].active)
				windows.removeAt(i);
		}

		if(guiState.focus >= guiState.controlCount)
			guiState.focus = 0;

		renderer.end();
	}

	//Windows Management and handeling below.
	
	void renderSubWindows(int active)
	{
		int[20] indices;
		int count = 0;
		foreach(i; 0 .. windows.length) if(windows[i].parent == active)
		{
			indices[count++] = i;
		}

		indices[0 .. count].sort!((a,b) => windows[a].order < windows[b].order);

		foreach(i; 0 .. count)
		{
			this.parentWindow		= active;
			this.activeWindow       = windows[indices[i]].id;
			performWindow(this, windows[indices[i]]);
			renderSubWindows(this.activeWindow);
		}
	}

	void delayWindow(int windowID, int parentID,
					 ref Rect rect, 
					 void delegate(Rect, ref Gui) controls,
					 HashID guiwindowID = "guiwindow")
	{
		auto index    = windows.countUntil!(x => x.id == windowID);
		WindowState* wind;
		if(index != -1)
		{
			//Rect and Scroll can change from the user to!
			wind = &windows[index];
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
				int order = reduce!(max)(0, windows.map!(x => x.parent == activeWindow ? x.order : 0)) + 1;
				wind.order = order;
			}
		}
		else 
		{
			windows ~= WindowState(windowID, rect, controls, guiwindowID, rect);
			wind = &windows[$ - 1];

			wind.parent = parentID;
			int order = reduce!(max)(0, windows.map!(x => x.parent == activeWindow ? x.order : 0)) + 1;
			wind.order = order;
		}

		wind.active = true;


		auto oldW = this.activeWindow,
			oldP = this.parentWindow;

		scope(exit)
		{
			this.activeWindow = oldW;
			this.parentWindow = oldP;
		}

		this.activeWindow = wind.id;
		this.parentWindow = wind.parent;

		Rect fixedArea = windowArea(wind.id);
		if(wasDown(fixedArea)) 
		{
			foreach(ref w; windows) if(wind.parent == w.parent)
			{
				if(w.order > 1000)
					w.order -= 1000;
			}

			if(wind.order < 1000)
				wind.order += 1000; 
		}
	}

	//I am not very proud of this function... 
	//But it does the trick. There should be 
	//A simpler way to do this but i have 
	//gotten to the point where i don't want
	//to change this.
	Rect windowArea(int id)
	{
		if(id == -1) return Rect(0,0,100000,10000);

		static struct A
		{
			Rect r;
			float2 o;
		}

		A impl(int id)
		{
			if(id == -1) return A(Rect(0,0,10000,10000), float2.zero); //Fix this
			else 
			{
				auto index = windows.countUntil!(x => x.id == id);
				if(index == -1) return A(Rect.empty, float2.zero);

				auto w     = windows[index];
				A a		   = impl(w.parent);
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

				return A(res, o);				
			}
		}

		auto w     = windows.find!(x => x.id == id)[0];
		A p     = impl(w.parent);

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
			auto w     = windows.find!(x => x.id == id)[0];
			return w.area.xy + windowLoc(w.parent); 
		}
	}

	bool isDragging()
	{
		return this.drag != Rect.empty;
	}

	void beginDrag(Rect rect)
	{
		fixRect(rect);
		this.drag = rect;
	}

	void endDrag()
	{
		this.drag  = Rect.empty;
	}

	bool hasFocus(int windowID)
	{
		auto index = windows.countUntil!(x => x.id == windowID);
		if(index == -1) return true;

		auto state = windows[index];
		int order = reduce!(max)(0, windows.map!(x => x.parent == state.parent ? x.order : 0));
		return state.order == order && hasFocus(state.parent);
	}
}

void performWindow(ref Gui gui, ref WindowState winState)
{
	import ui_controls;
	
	Rect wa  = gui.windowArea(winState.id);

	auto hash = HashID(winState.id, "guiwindow");
	auto style = gui.fetchStyle!(GuiWindow.Style)(winState.style);
	auto state = gui.fetchState(hash, GuiWindow.State(false, 0));
	Rect dragArea   = Rect(wa.x, wa.y + wa.h - style.dragHeight,
						   wa.w, style.dragHeight);
		
	float2 drag = dragWindow(gui, wa, dragArea, state);
	winState.area.displace(drag);

	Rect clientRect = gui.windowArea(winState.id);
	gui.drawQuad(clientRect, style.bg);
	
	Color c;
	if(gui.hasFocus(winState.id))
		c = style.focusColor;
	else 
		c = style.nonFocusColor;

	gui.renderer.drawQuadOutline(clientRect, 1.0f, gui.atlas.asset.pixel, c);

	clientRect.h -= style.dragHeight;

	float2 pos = gui.windowLoc(winState.id);
	auto oldState = gui.beginSubArea(clientRect, pos - clientRect.xy, state.focus);
	scope(exit) gui.guiState = oldState;
	winState.controls(Rect(-(pos - wa.xy).x, -(pos - wa.xy).y, clientRect.w, clientRect.h), gui);

	if(gui.hasFocus(winState.id)) { 
		gui.drawFocused();
	}

	state.focus = gui.guiState.focus;
	gui.state(hash, state);
}