module skin;

import graphics, framework, math, ui, content, std.algorithm;

struct GuiConfig
{
	string images;
	string fonts;
	GuiFontContent tooltip;
	ColorContent[] palette;
	

	@Optional(cast(TypeFieldContent[])null)  TypeFieldContent[]     typefields;
	@Optional(cast(LabelStyleContent[])null) LabelStyleContent[]	labels;
	@Optional(cast(ButtonStyleContent[])null) ButtonStyleContent[]	buttons;
	@Optional(cast(ToolbarStyleContent[])null) ToolbarStyleContent[]	toolbars;
	@Optional(cast(ToggleStyleContent[])null) ToggleStyleContent[]	toggles;
	@Optional(cast(SilderStyleContent[])null) SilderStyleContent[]	sliders;
	@Optional(cast(TextfieldStyle[])null) TextfieldStyle[]		textfields;
	@Optional(cast(TabsStyleContent[])null) TabsStyleContent[]	tabs;
	@Optional(cast(ScrollAreaContent[])null) ScrollAreaContent[]	scrollareas;

	@Optional(cast(EnumStyleContent[])null) EnumStyleContent[]	enums;
	@Optional(cast(WindowStyleContent[])null) WindowStyleContent[]	windows;
	@Optional(cast(MenuStyleContent[])null) MenuStyleContent[]	menus;
	
	@Optional(cast(ListBoxContent[])null) ListBoxContent[]	listboxes;
}

struct ColorContent
{
	string id;
	int	   value;
}

struct GuiFrameContent
{
	string id; 
	string color;

	GuiFrame toFrame(ColorContent[] palette)
	{
		auto color = palette.find!(x => x.id == this.color)[0];
		return GuiFrame(HashID(id), Color(color.value));
	}
}

struct GuiFontContent
{
	string id;
	string color;
	float2 size;
	float2 thresh;

	alias toFont this;

	GuiFont toFont(ColorContent[] palette)
	{
		auto color = palette.find!(x => x.id == this.color)[0];
		return GuiFont(id, Color(color.value), size, thresh);
	}
}

struct LabelStyleContent
{
	string name;
	GuiFontContent font;
}

struct ToggleStyleContent
{
	string name;
	string toggled, untoggled;
}

struct ButtonStyleContent
{
	string name;
	GuiFrameContent up, down, hl, downHl;
	GuiFontContent font;

	HorizontalAlignment horizontal;
	VerticalAlignment	vertical;
}

struct ToolbarStyleContent
{
	string name;
	string id;
	float padding;
}

struct SilderStyleContent
{
	string name;
	GuiFrameContent bg, fg;
}

struct TextfieldStyle 
{
	string name;
	GuiFrameContent frame;
	GuiFontContent  font;
	float2			padding;
	int			cursorColor;
	int			selectionColor;
	int			errorColor;
	float			flashSpeed;
}

struct TypeFieldContent
{
	string name;
	float itemSpacing;
	float fieldSize;
	float nameWidth;
	bool  topDown;
}

struct TabsStyleContent
{
	string name;
	GuiFrameContent pageBg;
	string	 toolbarStyle; 
	float	 toolbarSize;
}

struct ScrollAreaContent
{
	string name;
	GuiFrameContent bg;
	string scrollID;
	float scrollWidth;
}

struct EnumStyleContent
{
	string name;

	GuiFrameContent bg, hl;
	GuiFontContent font;
	float2 padding;
	float spacing;
}

struct WindowStyleContent
{
	string name;

	int focusColor, nonFocusColor;
	GuiFrameContent bg;
	GuiFontContent font;
	float titleHeight;

	string closeButton;
	ubyte4 padding;
}

struct MenuStyleContent
{
	string name;

	ubyte size, width, iconSpace;
	string windowID, submenuIcon;
	ubyte4 padding;

	GuiFontContent font;
	GuiFrameContent focus, highlight, idle;	
}


struct ListBoxContent
{
	string name;
	string scrollID;
	GuiFrameContent selected, stripe0, stripe1, bg;
	GuiFontContent	font;
	float			itemSize;
}

auto loadGui(A)(ref A all, Application* app, string file)
{
	import ui, allocation, window;
	import content.sdl;

	auto config = fromSDLFile!GuiConfig(all, file);

	auto skin = VariantTable!(64)(all, 
								  config.labels.length +
								  config.buttons.length +
								  config.textfields.length +
								  config.toggles.length +
								  config.toolbars.length + 
								  config.sliders.length + 
								  config.tabs.length + 
								  config.scrollareas.length +
								  config.enums.length +
								  config.windows.length +
								  config.menus.length + 
								  config.listboxes.length + 20);
	foreach(l; config.labels)
	{
		skin.add(l.name, GuiLabel.Style(l.font.toFont(config.palette)));
	}

	foreach(b; config.buttons)
	{
		skin.add(b.name, GuiButton.Style(b.up.toFrame(config.palette), 
										 b.down.toFrame(config.palette), 
										 b.hl.toFrame(config.palette), 
										 b.downHl.toFrame(config.palette), 
										 b.font.toFont(config.palette), 
										 b.horizontal, b.vertical));
	}

	foreach(t; config.textfields)
	{
		skin.add(t.name, GuiTextfield.Style(t.frame.toFrame(config.palette), 
											t.font.toFont(config.palette), t.padding, 
											Color(t.cursorColor), 
											Color(t.selectionColor),
											Color(t.errorColor), 
											t.flashSpeed));
	}

	foreach(t; config.toggles)
	{
		skin.add(t.name, GuiToggle.Style(HashID(t.toggled), HashID(t.untoggled)));
	}

	foreach(t; config.toolbars)
	{
		skin.add(t.name, GuiToolbar.Style(HashID(t.id), t.padding));
	}

	foreach(s; config.sliders)
	{
		skin.add(s.name, GuiSlider.Style(s.bg.toFrame(config.palette), s.fg.toFrame(config.palette)));
	}

	foreach(t; config.tabs)
	{
		skin.add(t.name, GuiTabs.Style(t.pageBg.toFrame(config.palette), HashID(t.toolbarStyle), t.toolbarSize));
	}

	foreach(s; config.scrollareas)
	{
		skin.add(s.name,GuiScrollArea.Style(s.bg.toFrame(config.palette), HashID(s.scrollID), s.scrollWidth));
	}

	foreach(e; config.enums)
	{
		skin.add(e.name, GuiEnum.Style(e.bg.toFrame(config.palette), e.hl.toFrame(config.palette), e.font.toFont(config.palette), e.padding, e.spacing));
	}

	foreach(w; config.windows)
	{
		skin.add(w.name, GuiWindow.Style(Color(w.focusColor), 
										 Color(w.nonFocusColor),
										 w.bg.toFrame(config.palette), w.font.toFont(config.palette), w.titleHeight,
										 HashID(w.closeButton), w.padding));
	}

	foreach(m; config.menus)
	{
		skin.add(m.name, GuiMenu.Style(m.size, m.width, m.iconSpace, 0,
									   HashID(m.windowID),
									   HashID(m.submenuIcon),
									   m.padding,
									   m.font.toFont(config.palette),
									   m.focus.toFrame(config.palette), 
									   m.highlight.toFrame(config.palette),
									   m.idle.toFrame(config.palette)));
	}

	foreach(m; config.listboxes)
	{
		skin.add(m.name, GuiListBox.Style(m.font.toFont(config.palette),
										  m.stripe0.toFrame(config.palette),
										  m.stripe1.toFrame(config.palette),
										  m.selected.toFrame(config.palette),
										  m.bg.toFrame(config.palette),
										  m.itemSize,
										  HashID(m.scrollID)));
	}

	foreach(t; config.typefields)
	{
		skin.add(t.name, GuiTypeField.Style(t.itemSpacing,
											t.fieldSize,
											t.nameWidth,
											t.topDown));
	}

	skin.tooltip = GuiTooltipStyle(config.tooltip.toFont(config.palette));

	auto loader = app.locate!AsyncContentLoader;
	auto font	= loader.load!FontAtlas(config.fonts);
	auto atlas  = loader.load!TextureAtlas(config.images);
	auto renderer = all.allocate!Renderer2D(all, RenderConfig(0xFFFF, 3));
	auto wind   = app.locate!Window;
	return Gui(all, atlas, font, skin, renderer, 
			   app.locate!Keyboard, 
			   app.locate!Mouse,
			   app.locate!Clipboard,
			   Rect(0,0, wind.size.x, wind.size.y));
}