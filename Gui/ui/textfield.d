module ui.textfield;

public import content;
public import collections;
public import rendering.combined;
public import window.mouse, window.keyboard, window.clipboard;
public import util.variant;
public import util.hash;
public import rendering;
import ui.base;
import log;

struct GuiTextfield
{
	struct Style
	{
		GuiFrame bg;
		GuiFont font;

		float2 padding;
		Color cursorColor;
		Color selectionColor;
		Color errorColor;
		float flashSpeed;
	}

	struct State
	{
		int cursor;
		uint2 selection;

		bool hasSelection() { return selection.x != selection.y; }
		void cancelSelection() { selection.x = selection.y = cursor; }
	}

	alias Filter = bool function(ref GuiTextfield, const(char)[]);
	alias Error  = bool function(ref GuiTextfield, const(char)[]);

	Filter filter;
	Error  error;

	Gui* gui;
	alias gui this;

	Rect rect;
	Style style;
	State state;
	bool changed;

	@property FontAtlas fonts()
	{
		return gui.fonts.asset;
	}

	this(Gui* gui, Rect rect, HashID style, Filter filter, Error error)
	{
		this.gui = gui;
		this.rect = rect;
		this.style = gui.fetchStyle!(Style)(style);
		this.filter = filter;
		this.error  = error;
		this.changed = false;
	}

	bool couldInsert(ref EditText text, const(char)[] input)
	{
		if(text.capacity - text.length < input.length) return false;

		if(text.length)
			text.insert(state.cursor, input);
		else
			text ~= input;

		auto size = fonts[style.font.font].measure(text.array) * style.font.size;
		bool result = filter(this, text.array);
		if(!result)
			text.removeSection(state.cursor, state.cursor + input.length);

		changed = result;
		return result;
	}

	int textfieldSelectionIndex(ref EditText text,float2 loc)
	{
		auto picker(float2 size, float2 glyph)
		{
			float x = (size.x - glyph.x / 2) * style.font.size.x;
			float dx = loc.x;
			return x >= dx;
		}

		import std.utf;
		auto messure = fonts[style.font.font].measureUntil!(picker)(text.array);
		if(messure.index > 0) 
			messure.index -= text.strideBack(messure.index);
		if(messure.index == -1) 
			messure.index = text.length;

		return messure.index;
	}

	void textfieldEditNormal(ref EditText text)
	{
		import std.algorithm, std.utf;
		if(keyboard.wasInput(Key.left) && state.cursor > 0)
		{
			size_t s = text.strideBack(state.cursor);
			state.cursor -= s;	
			if(keyboard.isModifiersDown(KeyModifiers.shift)) 
			{
				state.selection.x = state.cursor + s;
				state.selection.y = state.cursor;
			}
		}
		else if(keyboard.wasInput(Key.right) && state.cursor < text.length)
		{
			size_t s = text.stride(state.cursor);
			state.cursor += s;	
			if(keyboard.isModifiersDown(KeyModifiers.shift)) 
			{
				state.selection.x = state.cursor - s;
				state.selection.y = state.cursor;
			}
		}


		if(keyboard.wasInput(Key.backspace) && state.cursor > 0)
		{
			size_t s = text.strideBack(state.cursor);
			text.removeSection(state.cursor - s, state.cursor);
			state.cursor  -= s;
			changed = true;
		}

		if(keyboard.wasInput(Key.delete_) && text.length > 0 && state.cursor < text.length)
		{
			size_t s = text.stride(state.cursor);
			text.removeSection(state.cursor, state.cursor + s);
			changed = true;
		}

		if(keyboard.unicodeInput.length)
		{
			if(couldInsert(text,keyboard.unicodeInput))
				state.cursor += keyboard.unicodeInput.length;

		}

		if(keyboard.wasInput(Key.v) && keyboard.isModifiersDown(KeyModifiers.control))
		{
			if(text.capacity - text.length > clipboard.text.length)
			{
				if(couldInsert(text, clipboard.text))
				{
					state.cursor += clipboard.text.length;
				}
			}
		}

		if(keyboard.wasInput(Key.a) && keyboard.isModifiersDown(KeyModifiers.control))
		{
			state.selection.x = 0;
			state.selection.y = text.length;
			state.cursor      = text.length;
		}

	}

	void textfieldEditSelection(ref EditText text)
	{
		import std.algorithm, std.utf;
		if(keyboard.wasInput(Key.left) && state.cursor > 0)
		{
			state.cursor -= text.strideBack(state.cursor);			

			if(keyboard.isModifiersDown(KeyModifiers.shift)) 
				state.selection.y = state.cursor;
			else 
			{
				state.cancelSelection();
				return;
			}
		}

		if(keyboard.wasInput(Key.right) && state.cursor < text.length)
		{
			state.cursor += text.array.stride(state.cursor);			

			if(keyboard.isModifiersDown(KeyModifiers.shift)) 
				state.selection.y = state.cursor;
			else 
			{
				state.cancelSelection();
				return;
			}
		}

		if(keyboard.wasInput(Key.backspace) || 
		   keyboard.wasInput(Key.delete_) || 
		   keyboard.unicodeInput.length > 0 ||
		   (keyboard.wasInput(Key.v) && 
			keyboard.isModifiersDown(KeyModifiers.control)))
		{
			size_t low  = min(state.selection.x, state.selection.y);
			size_t high = max(state.selection.x, state.selection.y);
			text.removeSection(low, high);
			state.cursor = low;
			state.cancelSelection();
			changed = true;
		}

		if(keyboard.unicodeInput.length > 0)
		{
			if(couldInsert(text,keyboard.unicodeInput))
				state.cursor += keyboard.unicodeInput.length;
			return;
		}

		if(keyboard.wasInput(Key.c) && keyboard.isModifiersDown(KeyModifiers.control))
		{
			size_t low  = min(state.selection.x, state.selection.y);
			size_t high = max(state.selection.x, state.selection.y);

			clipboard.text(text.array[low .. high]);
		}

		if(keyboard.wasInput(Key.v) && keyboard.isModifiersDown(KeyModifiers.control))
		{
			if(text.capacity - text.length > clipboard.text.length)
			{
				if(couldInsert(text,clipboard.text))
					state.cursor += clipboard.text.length;
			}
		}		

		if(keyboard.wasInput(Key.a) && keyboard.isModifiersDown(KeyModifiers.control))
		{
			state.selection.x = 0;
			state.selection.y = text.length;
			state.cursor      = text.length;
		}
	}

	void textfieldMouseSelection(ref EditText text)
	{
		if(mouse.isDown(MouseButton.left) && wasDown(rect))
		{
			float2 downLoc = mouse.state(MouseButton.left).lastDown - rect.xy - style.padding;
			float2 curLoc  = mouse.location - rect.xy - style.padding;

			state.selection.x = textfieldSelectionIndex(text, downLoc);
			state.cursor = state.selection.y = textfieldSelectionIndex(text, curLoc);
		} 
	}

	bool opCall(ref EditText text, const(char)[] hint)
	{
		handleControl(rect);

		Color textColor = style.font.color;
		if(error(this, text.array))
			textColor   = style.errorColor;

		
		auto font = style.font;
		font.color = textColor;

		gui.drawQuad(rect, style.bg);
		gui.drawText(text.array, rect.xy + style.padding, rect.padded(float2(style.padding.x, 0)), font);

		if(hasFocus())
		{
			state = gui.fetchState(HashID(rect), State(text.length, uint2(text.length,text.length)));

			import math;
			state.cursor	  = clamp(state.cursor, 0, text.length);
			state.selection.x = clamp(state.selection.x, 0, text.length);
			state.selection.y = clamp(state.selection.y, 0, text.length);

			textfieldMouseSelection(text);

			if(!state.hasSelection)
				textfieldEditNormal(text);
			else
				textfieldEditSelection(text);

			gui.state(bytesHash(rect), state);

			auto markerPos = (fonts[style.font.font].measure(text[0 .. state.cursor].array) * style.font.size + style.padding) * float2(1, 0);
			gui.drawLine(rect.xy + markerPos, rect.xy + markerPos + float2(0, rect.h), 2.0f, GuiFrame("pixel", Color.black));

			if(state.hasSelection)
			{
				import std.algorithm;
				size_t low  = min(state.selection.x, state.selection.y);
				size_t high = max(state.selection.x, state.selection.y);

				auto pos  = (fonts[style.font.font].measure(text[0 .. low].array) * style.font.size + style.padding).x;
				auto size = fonts[style.font.font].measure(text[low .. high].array) * style.font.size;
				Rect sel = Rect(rect.x + pos, rect.y + style.padding.y - 2, size.x, size.y);

				gui.drawQuad(sel, GuiFrame("pixel", style.selectionColor));
			}
		}

		return changed;
	}
}

private bool standardFilter(ref GuiTextfield textfield, const(char)[] input)
{
	import std.algorithm;
	auto style = textfield.style;
	auto size = textfield.fonts[style.font.font].measure(input) * style.font.size;
	return textfield.rect.w - style.padding.x * 2 >= size.x &&
		!input.canFind("\n");
}

float2 textfieldSize(ref Gui gui, ref EditText text, const(char[]) hint = "", HashID style = HashID("textfield"))
{
	auto st   = gui.fetchStyle!(GuiTextfield.Style)(style);
	auto size = gui.fonts.asset[st.font.font].measure(text.array) * st.font.size + st.padding * 2;
	return size;
}


bool textfield(ref Gui gui, Rect rect, ref EditText text, const(char[]) hint = "", HashID style = HashID("textfield"))
{
	static f(ref GuiTextfield, const(char)[]) { return false; }

	auto tf = GuiTextfield(&gui, rect, style, &standardFilter, &f);
	return tf(text, hint);
}

float2 numberfieldSize(T)(ref Gui gui, ref T number, HashID style = HashID("textfield")) if(isNumeric!T)
{
	import util.strings;
	auto t        = cast(char[])text1024(T.max);
	auto edittext = EditText(t.ptr, t.length, t.length);

	return textfieldSize(gui, edittext, "", style);
}

import std.traits;
bool numberfield(T)(ref Gui gui, 
					Rect rect, 
					ref T number, 
					T min_ = 0, 
					T max_ = 0, 
					HashID style = HashID("textfield")) if(isNumeric!T)
{

	import util.strings, util.exception;
	static struct State
	{
		align(1):

		char[27] text;
		byte length;

		this(const(char[]) text)
		{
			this.text[0 .. text.length] = text;
			this.length = cast(byte)text.length;
		}
	}

	static auto errorFilter(ref GuiTextfield tf, const(char)[] text)
	{
		T dummy;
		return !text.tryParse(dummy);

	}

	

	char[27] buffer = void;
	auto tf = GuiTextfield(&gui, rect, style, &standardFilter, &errorFilter);
	if(gui.nextHasFocus())
	{
		bool result = false;
		if(gui.keyboard.wasPressed(Key.up))
		{
			number += 1;
			result = true;
		} else if(gui.keyboard.wasPressed(Key.down))
		{
			number -= 1;
			result = true;
		}
		if(!(min_ == 0 && max_ == 0))
		{
			number = clamp(number, min_, max_);
		}

		if(result)
		{
			auto text_    = text(buffer, number);
			auto edittext = EditText(cast(char*)text_.ptr, text_.length, 27);
			tf(edittext, "");
			return true;
		}

		auto hash = bytesHash(rect, bytesHash("numberfield"));
		auto state = gui.fetchState(hash, State(text(buffer, number)));
		auto edittext = EditText(state.text.ptr, state.length, 27);
		result |= tf(edittext, "");

		state = State(edittext.array);
		gui.state(hash, state);

		if(edittext.length == 0)
		{
			T temp = number;
			number = 0;
			return temp != number;
		}
		else 
		{
			if(edittext.array.tryParse(number))
			{
				if(!(min_ == 0 && max_ == 0))
				{
					number = clamp(number, min_, max_);
				}

				return result;
			}

			return false;
		}
	}
	else 
	{
		auto tmp = cast(char[])text(buffer, number);
		auto edittext = EditText(tmp.ptr, tmp.length, 27);
		return tf(edittext, "");
	}
}

float2 vectorfieldSize(ref Gui gui, ref float2 number, HashID style = HashID("textfield"))
{
	auto first	  = numberfieldSize(gui, number.x, style);
	auto second   = numberfieldSize(gui, number.y, style);
	return float2(first.x + second.x, first.y);
}

import math.vector;
bool vectorfield(ref Gui gui, Rect rect, ref float2 vec, HashID style = HashID("textfield"))
{
	bool first = numberfield(gui, Rect(rect.x, rect.y, rect.w / 2 - 5, rect.h), vec.x, 0f, 0f, style);
	bool second = numberfield(gui, Rect(rect.x + rect.w / 2, rect.y, rect.w / 2, rect.h), vec.y, 0f, 0f, style);
	return first || second;
}

bool colorfield(ref Gui gui, Rect rect, ref Color color, HashID styleID = HashID("textfield"))
{
	int r = color.rbits, 
		g = color.gbits,
		b = color.bbits,
		a = color.abits;

	bool result = false;

	result |= numberfield(gui, Rect(rect.x,										 rect.y, rect.w / 4 - 5, rect.h), r, 0, 255, styleID);
	result |= numberfield(gui, Rect(rect.x + rect.w / 4,					     rect.y, rect.w / 4 - 5, rect.h), g, 0, 255, styleID);
	result |= numberfield(gui, Rect(rect.x + rect.w / 2,					     rect.y, rect.w / 4 - 5, rect.h), b, 0, 255, styleID);
	result |= numberfield(gui, Rect(rect.x + (rect.w  / 2) + rect.w / 4,         rect.y, rect.w / 4 - 5, rect.h), a, 0, 255, styleID);

	if(result)
	{
		color = Color(r, g, b, a);
	}

	return result;
}