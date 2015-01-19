module graphics.color;

import math;
import std.string : format;

struct Color
{
	uint packedValue;

	int rbits()
	{
		return (packedValue & 0xFF);
	}

	int gbits()
	{
		return (packedValue >> 8) & 0xFF;
	}


	int bbits()
	{
		return (packedValue >> 16) & 0xFF;
	}


	int abits()
	{
		return ((packedValue >> 24) & 0xFF);
	}

	@property float r() 
	{
		return rbits / cast(float)0xFF; 
	}

	@property void r(float value) 
	{ 
		this.packedValue = (packedValue & 0xFFFFFF00) | cast(uint)(value * 0xFF); 
	}

	@property float g()
	{ 
		return (gbits & 0xFF) / cast(float)0xFF; 
	}

	@property void g(float value)
	{ 
		this.packedValue = (packedValue & 0xFFFF00FF) | (cast(uint)(value * 0xFF) << 8); 
	}

	@property float b() 
	{
		return (bbits) / cast(float)0xFF;
	}

	@property void b(float value) 
	{
		this.packedValue = (packedValue & 0xFF00FFFF) | (cast(uint)(value * 0xFF) << 16);
	}

	@property float a() 
	{
		return abits /  cast(float)0xFF;
	}

	@property void a(float value) 
	{
		this.packedValue = (packedValue & 0x00FFFFFF) | (cast(uint)(value * 0xFF) << 24);
	}

	this(uint hexColor) 
	{
		this.packedValue = hexColor;
	}

	this(uint r, uint g, uint b, uint a) 
	{
		this(cast(float)r / 255f, cast(float)g / 255f,cast(float)b / 255f,cast(float)a / 255f);
	}

	this(float r, float g, float b, float a)
	{
		uint red = cast(uint)(clamp(r,0f,1f) * 0xFF) << 0;
		uint green = cast(uint)(clamp(g,0f,1f) * 0xFF) << 8;
		uint blue = cast(uint)(clamp(b,0f,1f) * 0xFF) << 16;
		uint alpha = (cast(uint)(clamp(a,0f,1f) * 0xFF) << 24);

		this.packedValue = red | green | blue | alpha;
	}

	Color opBinary(string op)(float scalar) if(op == "*") 
	{
		scalar = clamp(scalar, 0f, 1f);
		return Color(this.r * scalar, this.g * scalar, this.b * scalar, scalar);
	}

	string toString() 
	{
		return format("r:%f, g:%f, b:%f, a:%f", r,g,b,a);
	}


	//Implicit conversion to vector4.
	float4 toVector4() @property
	{
		return float4(r,g,b,a);
	}
	
	static Color fromHSV(ColorHSV hsv)
	{	
		double hh, p, q, t, ff;
		long i;

		float r, g, b;

		if(hsv.s <= 0.0)
		{
			r = hsv.v;
			g = hsv.v;
			b = hsv.v;
			return Color(r,g,b, 1.0f);
		}

		hh = hsv.h;
		if(hh >= 360.0) hh = 0;
		hh /= 60;

		i  = cast(long)hh;
		ff = hh - i;

		p = hsv.v * (1.0 - hsv.s);
		q = hsv.v * (1.0 - (hsv.s * ff));
		t = hsv.v * (1.0 - (hsv.s * (1.0 - ff)));

		switch(i) {
			case 0:
				r = hsv.v;
				g = t;
				b = p;
				break;
			case 1:
				r = q;
				g = hsv.v;
				b = p;
				break;
			case 2:
				r = p;
				g = hsv.v;
				b = t;
				break;

			case 3:
				r = p;
				g = q;
				b = hsv.v;
				break;
			case 4:
				r = t;
				g = p;
				b = hsv.v;
				break;
			case 5:
			default:
				r = hsv.v;
				g = p;
				b = q;
				break;
		}
		
		return Color(r, g, b, 1.0f);
		
	}

	static Color interpolate(Color c0, Color c1, float t)
	{
		int ip(float x, float y, float t)
		{
			return cast(int)((1 - t) * x + t * y);
		}

		int r = ip(c0.rbits, c1.rbits, t);
		int g = ip(c0.gbits, c1.gbits, t);
		int b = ip(c0.bbits, c1.bbits, t);
		int a = ip(c0.abits, c1.abits, t);
		
		return Color(r,g,b,a);
	}

	static Color interpolateHSV(Color a, Color b, float t)
	{
		float ip(float x, float y, float t)
		{
			return (1 - t) * x + t * y;
		}

		ColorHSV ca = ColorHSV.fromRGB(a);
		ColorHSV cb = ColorHSV.fromRGB(b);
		ColorHSV final_;

		final_.h = ip(ca.h, cb.h, t);
		final_.s = ip(ca.h, cb.h, t);
		final_.v = ip(ca.h, cb.h, t);
		
		return Color.fromHSV(final_);
	}

	enum Color transparent = Color(0);
	enum Color black = Color(0xFF000000);
	enum Color white = Color(0xFFFFFFFF);
	enum Color blue = Color(0xFFFF0000);
	enum Color green = Color(0xFF00FF00);
	enum Color red = Color(0xFF0000FF);
}


struct ColorHSV
{
	float h;
	float s;
	float v;

	static ColorHSV fromRGB(Color c)
	{
		ColorHSV out_;
		double min, max, delta;

		float r = c.r, g = c.g, b = c.b;

		min = r < g ? r : g;
		min = min < b ? min : b;

		max = r > g ? r : g;
		max = max > b ? max : b;

		out_.v = max;
		delta  = max - min;

		if(max > 0.0) 
		{
			out_.s = delta / max;
		}
		else 
		{
			out_.s = 0.0f;
			out_.h = float.nan;
			return out_;
		}

		if(r >= max)
			out_.h = (g - b) / delta;
		else if(g >= max)
			out_.h = 2.0 + (b - r) / delta;
		else 
			out_.h = 4.0 + (r - g) / delta;

		out_.h *= 60.0;

		if(out_.h < 0.0)
			out_.h += 360.0f;

		return out_;
	}
}





enum Metro : Color
{
	lightGreen  = Color(0xFF33b499),
	green       = Color(0xFF00a300),
	darkGreen   = Color(0xFF1e7145), 
	magenta     = Color(0xFF9700ff),
	lightPurple = Color(0xFFa70097),
	purple		= Color(0xFF78387e),
	darkPurple  = Color(0xFFba3c60),
	darken		= Color(0xFF1d1d1d),
	teal		= Color(0xFFa9ab00),
	lightBlue	= Color(0xFFfff4ef),
	blue		= Color(0xFFef892d),
	darkBlue	= Color(0xFF97572b),
	yellow		= Color(0xFF0dc4ff),
	orange		= Color(0xFF1aa2e3),
	darkOrange	= Color(0xFF2c53da),
	red			= Color(0xFF1111ee),
	darkRed		= Color(0xFF471db9),
	white		= Color(0xFFFFFFFF)
}