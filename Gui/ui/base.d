module ui.base;

public import content;
public import collections;
public import rendering.combined;
public import window.mouse, window.keyboard, window.clipboard;
public import util.variant;
public import util.hash;
public import rendering;
public import ui.window;

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


	float left() { return x; }
	float right() { return x + w; }
	float top() { return y + h; }
	float bottom() { return y; }
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
	ubyte4 packed;

	void thresholds(float2 value)
	{
		packed.z	= cast(ubyte)(value.x * 255.0);
		packed.w	= cast(ubyte)(value.y * 255.0);
	}

	float2 thresholds()
	{
		return float2(packed.z / 255.0f, packed.w / 255.0f);
	}

	float2 size()
	{
		return float2(packed.x, packed.y);
	}

	float lineHeight()
	{
		return size.y * 1.5f;
	}

	void size(float2 value)
	{
		packed.x	   = cast(ubyte)(value.x);
		packed.y	   = cast(ubyte)(value.y);
	}

	this(string s, Color c, float2 sz, float2 thresh)
	{
		font = bytesHash(s);
		color = c;
		thresholds = thresh;
		size  = sz;
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
	private float2 offset;
	private Rect area;
	private Rect focusRect;
	private int focus;
	int controlCount;
}

struct Gui
{
	import std.algorithm;

	Renderer2D* renderer;
	private VariantTable!(64) skin;
	private Table!(HashID, VariantN!32) oldControlStates;
	private Table!(HashID, VariantN!32) controlStates;
	WindowManager windows;

	//Diffrent items use diffrent overlapping rectangles. 
	List!Rect overlaping;

	AtlasHandle  atlas;
	FontHandle   fonts;
	Keyboard* keyboard;
	Mouse*	 mouse;
	Clipboard* clipboard;

	GuiState guiState;

	@property ref Rect area()
	{
		return guiState.area;
	}

	@property area(Rect value)
	{
		guiState.area = value;
	}

	@property int focus()
	{
		return guiState.focus;
	}


	//We need to store some sort of delta state so
	//that frame transitions work ok. 
	this(A)(ref A allocator, 
			AtlasHandle atlas,
			FontHandle  fonts,
			VariantTable!(64) skin,
			Renderer2D* renderer,
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
		controlStates		  = Table!(HashID, VariantN!32)(allocator, 100); 
		overlaping			  = List!Rect(allocator, 50);
		windows				  = WindowManager(allocator);

		this.guiState.fullArea	  = area;
		this.guiState.area		  = area;
		this.guiState.offset	  = float2.zero;
		this.guiState.controlCount  = 0;
		this.guiState.focus		  = -1;
	}


	void unfocus()
	{
		this.guiState.focus = -1;
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
		foreach(ref rect; overlaping)
		{
			if(rect.contains(point))
				return true;
		}

		return false;
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

	T fetchCurrentState(T)(HashID id, T default_)
	{
		auto ptr   = id in controlStates;
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
		renderer.drawText(tooltip, float2.zero, style.font.size, 
						  fonts.asset[style.font.font], 
						  style.font.color,
						  style.font.thresholds);
	}

	void drawLine(Frame)(float2 start, float2 end, float width, auto ref Frame frame)
	{
		Rect area = guiState.area;

		start.x = min(area.x + area.w, max(area.x, start.x));
		end.x = min(area.x + area.w, max(area.x, end.x));

		start.y = min(area.y + area.h, max(area.y, start.y));
		end.y = min(area.y + area.h, max(area.y, end.y));

		renderer.drawLine(start, end, width, atlas.asset[frame.frame], frame.color);
	}

	void drawQuad(Frame)(Rect rect, auto ref Frame frame)
	{
		renderer.drawQuad(rect, atlas.asset[frame.frame], frame.color, guiState.area);
	}

	void drawQuad(Frame)(Rect rect, auto ref Frame frame, Rect bounds)
	{
		renderer.drawQuad(rect, atlas.asset[frame.frame], frame.color, bounds);
	}



	void drawQuadOutline(Frame)(Rect rect, float width, auto ref Frame frame)
	{
		renderer.drawQuadOutline(rect, width, atlas.asset[frame.frame], frame.color);
	}

	void drawQuad(Frame)(Rect rect, auto ref Frame frame, Color color)
	{
		renderer.drawQuad(rect, frame, color, guiState.area);
	}

	void drawText(const(char[]) text, float2 pos, Rect rect, ref GuiFont font)
	{
		drawText(text, pos, rect, font, guiState.area);
	}

	void drawText(const(char[]) text, float2 pos, Rect rect, ref GuiFont font, Rect bounds)
	{
		renderer.drawText(text, pos, font.size, fonts.asset[font.font], 
						  font.color, font.thresholds, intersection(rect, bounds));
	}

	void drawText(const(char[]) text, Rect rect, ref GuiFont font, Rect bounds,
				  HorizontalAlignment horizontal = HorizontalAlignment.left, 
				  VerticalAlignment vertical = VerticalAlignment.center)
	{
		auto f = &fonts.asset[font.font];
		auto textSize = f.measure(text) * font.size;

		auto fontPos = rect.xy;
		if(vertical == VerticalAlignment.center)
			fontPos.y += rect.h / 2 - textSize.y / 2;
		else if(vertical == VerticalAlignment.top)
			fontPos.y += rect.h - textSize.y;

		if(horizontal == HorizontalAlignment.center)
			fontPos.x += rect.w / 2 - textSize.x / 2;
		else if(horizontal == HorizontalAlignment.right)
			fontPos.x += rect.w - textSize.x;

		drawText(text, fontPos, rect, font, bounds);
	}


	void drawText(const(char[]) text, Rect rect, ref GuiFont font,
				  HorizontalAlignment horizontal = HorizontalAlignment.left, 
				  VerticalAlignment vertical = VerticalAlignment.center)
	{
		drawText(text, rect, font, guiState.area, horizontal, vertical);
	}

	void begin()
	{
		updateFocus();

		import std.algorithm;
		swap(controlStates, oldControlStates);
		controlStates.clear();


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
		if(guiState.focus >= 0 && guiState.focus < guiState.controlCount)
		{
			//renderer.drawQuadOutline(intersection(guiState.area, guiState.focusRect), 1.0f, atlas.asset.pixel, Color.black);
		}
	}

	void end()
	{
		drawFocused();

		if(guiState.focus >= guiState.controlCount)
			guiState.focus = 0;

		windows.render(this);

		renderer.end();
	}
}