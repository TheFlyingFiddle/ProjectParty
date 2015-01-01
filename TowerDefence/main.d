module main;

import rendering;
import content;
import graphics, math, collections;
import allocation;

import concurency.task;
import content.sdl;
import content.reloading;
import framework;
import window.window;
import window.keyboard;

import external_libraries;
import log;

import core.sys.windows.windows;
import core.runtime;

extern(C) void _d_assert_msg(string msg, string file, uint line)
{
	import core.exception;
	Exception t = new Exception(msg, file, line);
	import std.stdio;
	writeln(t);
	readln;
}

extern(C) void _d_assert(string file, uint line) 
{
	import std.stdio;

	Exception t = new Exception("Assertion Failiure: ", file, line);
	writeln(t);
	readln;
}


void main()
{
	import std.stdio;
	initializeRemoteLogging("TowerDefence");
	scope(exit) termRemoteLogging();

	init_dlls();
	try
	{
		auto config = fromSDLFile!PhoneAppConfig(Mallocator.it, "config.sdl");
		logInfo("start");
		run(config);
	}
	catch(Throwable t) {
		logErr("Crash!\n", t);
		while(t.next) {
			t = t.next;
			logErr(t);
		}

	}
}

void run(PhoneAppConfig config) 
{
	RegionAllocator region = RegionAllocator(Mallocator.cit, 1024 * 1024 * 5);
	auto stack = ScopeStack(region);

	auto app = createPhoneApp(stack, config);

	import screen.loading;
	auto endScreen     = stack.allocate!(Screen1)();
	auto loadingScreen = stack.allocate!(LoadingScreen)(LoadingConfig(["Fonts.fnt", "Atlas.atlas"], "Fonts"), endScreen);

	FontRenderer renderer = FontRenderer(region, RenderConfig(0xFFFF, 3), vd_Source, fd_Source);
	app.addService(&renderer);

	auto s = app.locate!ScreenComponent;
	s.push(loadingScreen);

	gl.enable(Capability.blend);
	gl.BlendFunc(BlendFactor.srcAlpha, BlendFactor.oneMinusSourceAlpha);

	try
	{
		app.run();
	}
	catch(Throwable t) {
		logErr("Crash!\n", t);
		while(t.next) {
			t = t.next;
			logErr(t);
		}
	}
}
	
class Screen1 : Screen
{
	import rendering.combined;
	import ui, ui.controls;
	import network.server;
	import network.router;
	import network.message;
	import network_types;

	FontHandle font;
	AtlasHandle atlas;
	Renderer2D* renderer;
	
	Gui gui;
	SuperMenu sm;
	Menu m;
	
	EditText text;
	float number = 0;
	float2 vector;


	this() { super(false, false); }

	float rotation = 0;
	override void initialize() 
	{
		auto loader = app.locate!AsyncContentLoader;

		font	= loader.load!FontAtlas("Fonts");
		atlas	= loader.load!TextureAtlas("Atlas");

		auto router = app.locate!Router;
		router.setMessageHandler(&handleTestMessageA);	

		text = EditText(Mallocator.it, 128);
		text ~= "Hello World";



		buildGUI();
	}

	void buildGUI()
	{
		auto all = Mallocator.it;

		renderer = all.allocate!Renderer2D(all, RenderConfig(0xFFFF, 3));
		
		renderer.viewport(float2(app.locate!(Window).size));

		auto skin = VariantTable!(64)(all, 20);

		GuiButton.Style style;
		style.up		= GuiFrame("pixel", Metro.purple);
		style.down		= GuiFrame("pixel", Metro.darkPurple);
		style.highlight = GuiFrame("pixel", Metro.lightPurple);
		style.downHl	= GuiFrame("pixel",	Metro.blue);
		style.font		= GuiFont("segoeui", Metro.lightBlue, 
								  float2(15, 15), float2(0.12, 0.55));
		style.vertical  = VerticalAlignment.center;
		style.horizontal = HorizontalAlignment.center;

		skin.button = style;

		GuiButton.Style selected = style;
		selected.up = GuiFrame("pixel", Metro.green);
		skin.toolbarButton = selected;

		GuiToolbar.Style toolbar;
		toolbar.toggleID   = "toggle";
		toolbar.padding	   = 2;
		skin.toolbar = toolbar;

		GuiToggle.Style toggle;
		toggle.toggled   = "toolbarButton";
		toggle.untoggled = "button";
		skin.toggle = toggle;

		GuiSlider.Style slider;
		slider.bg = GuiFrame("pixel", Metro.darkGreen);
		slider.fg = GuiFrame("pixel", Metro.lightBlue);
		skin.slider = slider;

		GuiSlider.Style scrollbar;
		scrollbar.bg = GuiFrame("pixel", Color(0xFF666666));
		scrollbar.fg = GuiFrame("pixel", Color(0xFFbbbbbb));
		skin.scrollbar = scrollbar;

		skin.tooltip = GuiTooltipStyle(GuiFont("consola", Metro.darkOrange, float2(20, 16), float2(0.15, 0.65)));

		GuiTextfield.Style textfield;
		textfield.bg				= GuiFrame("pixel", Color(0xFFaaaaaa));
		textfield.cursorColor		= Metro.darken;
		textfield.selectionColor	= Color(0xaa83aa32);
		textfield.flashSpeed		= 1.0f; //In seconds i guess;
		textfield.font				= GuiFont("segoeuil", Color(0xFFFFFFFF), float2(15, 15), float2(0.1, 0.7));
		textfield.padding			= float2(4, 5);
		textfield.errorColor		= Metro.darkPurple;
		skin.textfield = textfield;


		GuiTabs.Style tabs;
		tabs.pageBg		  = GuiFrame("pixel", Metro.darken);
		tabs.toolbarStyle = "toolbar"; 
		tabs.toolbarSize  = 25;
		skin.tabs = tabs;

		GuiScrollArea.Style scrollarea;
		scrollarea.bg = GuiFrame("pixel", Color(0xFFbbbbbb));
		scrollarea.scrollWidth = 12;
		scrollarea.scrollID    = "scrollbar";
		skin.scrollarea = scrollarea;


		GuiScrollArea.Style windowarea;
		windowarea.bg = GuiFrame("pixel", Color(0xFFFFFFFF));
		windowarea.scrollWidth = 12;
		windowarea.scrollID    = "scrollbar";
		skin.windowarea = windowarea;

		GuiLabel.Style label;
		label.font = GuiFont("segoeui", Metro.darken, float2(20, 20), float2(0.12, 0.7));
		skin.label = label;

		GuiImage.Style image;
		image.bg = GuiFrame("pixel", Metro.white);
		skin.image = image;


		GuiEnum.Style enum_;
		enum_.bg   = GuiFrame("pixel", Color(0xFFbbbbbb));
		enum_.font = GuiFont("segoeui", Metro.darken, float2(15, 15), float2(0.12, 0.7));
		enum_.highlight = GuiFrame("pixel", Color(0xFFcccccc));
		enum_.padding   = float2(4, 4);
		enum_.spacing   = 2;
		skin.enumfield = enum_;

		GuiWindow.Style guiwindow;
		guiwindow.focusColor    = Metro.darken;
		guiwindow.nonFocusColor = Color(0xFF544554);
		guiwindow.bg			= GuiFrame("pixel", Metro.orange);
		guiwindow.closeButton   = "button";
		guiwindow.padding       = ubyte4(4, 4, 4, 4);
		guiwindow.titleHeight   = 32;
		guiwindow.font			= GuiFont("segoeui", Color(0xFF000000), float2(15, 15), float2(0.12, 0.7));

		skin.guiwindow = guiwindow;

		GuiWindow.Style guiwindow2;
		guiwindow2.focusColor    = Metro.darken;
		guiwindow2.nonFocusColor = Color(0xFF544554);
		guiwindow2.bg			= GuiFrame("pixel", Metro.blue);
		guiwindow2.closeButton   = "button";
		guiwindow2.padding       = ubyte4(4, 4, 4, 4);
		guiwindow2.titleHeight   = 32;
		guiwindow2.font			= GuiFont("segoeui", Color(0xFF000000), float2(15, 15), float2(0.12, 0.7));

		skin.bluewindow = guiwindow2;

		GuiWindow.Style guiwindow3;
		guiwindow3.focusColor    = Metro.darken;
		guiwindow3.nonFocusColor = Color(0xFF544554);
		guiwindow3.bg			= GuiFrame("pixel", Metro.green);
		guiwindow3.closeButton   = "button";
		guiwindow3.padding       = ubyte4(4, 4, 4, 4);
		guiwindow3.titleHeight   = 32;
		guiwindow3.font			= GuiFont("segoeui", Color(0xFF000000), float2(15, 15), float2(0.12, 0.7));

		skin.greenwindow = guiwindow3;

		GuiWindow.Style menuwindow;
		menuwindow.focusColor    = Metro.darken;
		menuwindow.nonFocusColor = Color(0xFF544554);
		menuwindow.bg			 = GuiFrame("pixel", Color(0xFF666666));
		menuwindow.closeButton   = "button";
		menuwindow.padding       = ubyte4(4, 4, 4, 4);
		menuwindow.titleHeight   = 0;
		menuwindow.font			 = GuiFont("segoeui", Color(0xFF000000), float2(15, 15), float2(0.12, 0.7));

		skin.menuwindow = menuwindow;

		GuiMenu.Style gmenu;
		gmenu.font  = GuiFont("segoeuil", Color(0xFF000000), float2(15, 15), float2(0.12, 0.7));
		gmenu.size  = 25;
		gmenu.width = 100;
		gmenu.iconSpace = 25;
		gmenu.padding = ubyte4(4, 0, 4, 4);
		gmenu.windowID = "menuwindow";
		gmenu.submenuIcon = "baws";

		gmenu.focus		 = GuiFrame("pixel", Color(0xFF666666));
		gmenu.highlight  = GuiFrame("pixel", Color(0xFFcccccc));
		gmenu.idle		 = GuiFrame("pixel", Color(0xFFaaaaaa));

		skin.menu   = gmenu;

		auto window = app.locate!Window;
		gui = Gui(all, atlas, font, skin, renderer, 
				  app.locate!Keyboard, 
				  app.locate!Mouse,
				  app.locate!Clipboard,
				  Rect(0,0, window.size.x, window.size.y));


		m = Menu(all, &sm, 200);

		foreach(item; m.items)
		{
			logInfo(item.name);
		}	
	}

	void handleMenu()
	{
		logInfo("A menuItem was clicked!");
	}

	void handleTestMessageA(ulong id, TestMessageA message)
	{

	}

	override void update(Time time) 
	{	
		rotation += time.delta.to!("seconds", float);	

		auto keyboard = app.locate!Keyboard;	
		
		if(keyboard.isDown(Key.a))
			thresh.x += 0.01;
		else if(keyboard.isDown(Key.s))
			thresh.x -= 0.01;
		else if(keyboard.isDown(Key.z))
			thresh.y += 0.01;
		else if(keyboard.isDown(Key.x))
			thresh.y -= 0.01;

		import std.algorithm;

		thresh.x = clamp(thresh.x,0,1);
		thresh.y = clamp(thresh.y,0,1);

		auto server = app.locate!Server;
		if(server.activeConnections.length > 0)
		{
			server.sendMessage(server.activeConnections[0].id, TestMessageB(10, 100.0));
		}
	}
	
	enum TestEnum { Once, Upon, A, Time, Hue, Hua, Huer, Garht, Garther, Mastor,
					Life, Is, But, Two, Thriefelr, Ing, Ar, Thingr, Burbur, Murcar,
					Little, Burdoodle, In, Garlg, Garmn, Garthir, aweqq, adwat,
					Awdpok, awenqi, ascopi, qweiuh, qweawreq, jkahweqe, qpweidad}
	
	
	TestEnum tEnum;

	float2 thresh = float2(0,1);
	override void render(Time time)
	{
		auto chnl = LogChannel("Lame");
	
		auto window = app.locate!Window;
		renderer.viewport(float2(window.size));


		gl.viewport(0,0, cast(int)window.size.x, cast(int)window.size.y);

		gui.area = Rect(100,100, window.size.x - 200, window.size.y - 200);
		gui.begin();

		gui.menu(m);
		gui.enumField(Rect(100, 600, 200, 30), tEnum);

		Rect mainWindow = Rect(0,0, window.size.x, window.size.y);
		scrollgui(mainWindow, gui);

		gui.end();

	}


	void scrollgui(Rect area, ref Gui g)
	{
		if(gui.button(Rect(50,50,100,60), GuiElement("Hello", "This is a tooltip")))
		{
			//logInfo("WindowHandle: ", window.nativeHandle);
		}

		if(gui.textfield(Rect(50, 400, 400, 22), text, ""))
			logInfo("Text Changed!");


		if(gui.textfield(Rect(50, 440, 100, 22), text, ""))
			logInfo("Text Changed!");

		if(gui.numberfield(Rect(50, 300, 400, 20), number))
			logInfo("Text Changed!");

		if(gui.vectorfield(Rect(50, 200, 400, 20), vector))
			logInfo("Vector changed!");

		if(gui.slider(Rect(50, 500, 200, 12), slid))
		{
			logInfo("Slider Changed!: ", slid);
		}

		if(gui.repeatButton(Rect(200, 50, 100, 60), GuiElement("Repeat")))
			logInfo("Repeat Button Pressed!");

		if(gui.repeatButton(Rect(1200, 50, 100, 60), GuiElement("Repeat")))
			logInfo("Repeat Button Pressed!");

		gui.label(Rect(1000, 150, 200, 100), "This is a label!");
		gui.image(Rect(1000, 50, 100, 100), atlas.asset.orange);


		//gui.scrollarea(Rect(500, 100, 400, 500), scroll2, &scrollgui2);
		
		foreach(ref w; wind)
		{
			if(w.active)
				gui.guiwindow(w.id, w.area, &scrollgui3, w.style);
		}
	}

	struct Wind
	{
		int id;
		Rect area;
		bool active;
		HashID style;
	}

	Wind[2] wind =
	[
		Wind(2, Rect(500, 100, 400, 300), true, HashID("greenwindow")),
		Wind(3, Rect(500, 500, 400, 300), true, HashID("bluewindow")),
	];

	void winGui2(Rect client, ref Gui g)
	{
		g.button(Rect(20, 20, 50, 50), "A");
		g.button(Rect(120, 120, 50, 50), "B");
		g.button(Rect(220, 170, 50, 50), "C");
		g.button(Rect(270, 220, 250, 50), "D");
		//g.scrollarea(client, scroll3, &scrollgui2);
	}

	void scrollgui2(ref Gui g)
	{
		g.button(Rect(20, 20, 50, 50), "A");
		g.button(Rect(120, 120, 50, 50), "B");
		g.button(Rect(220, 170, 50, 50), "C");
		g.button(Rect(270, 220, 250, 50), "D");
	}
	
	void scrollgui3(ref Gui g, ref GuiWindow window)
	{
		g.button(Rect(20, 20, 50, 50), "A");
		g.button(Rect(120, 120, 50, 50), "B");
		g.button(Rect(220, 170, 50, 50), "C");
		g.button(Rect(270, 220, 250, 50), "D");


		g.windowContent("This be a window man!", GuiFrame("baws", Color.white));
		if(g.closeWindow())
		{
			auto windowID = g.activeWindowID();
			auto index = wind[].countUntil!(x => x.id == windowID);
			wind[index].active = false;
		}

		g.resizeWindow();
		g.dragWindow();
	}

	void nothing(ref Gui gui) 
	{
		if(gui.button(Rect(50,50, 100, 20), "Hello There"))
		{

		}
	}

	void something(ref Gui gui)
	{		
		if(gui.button(Rect(50,50, 400, 20), "H124125125125125125125ello There"))
		{

		}

		if(gui.button(Rect(50, 100, 100, 20), "Hello There"))
		{

		}
	}
	
	float2 scroll  = float2.zero;
	float2 scroll2 = float2.zero;
	float2 scroll3 = float2.zero;
	float2 scroll4 = float2.zero;

	float slid = 0;
	int sel = 0;
}

struct SuperMenu
{
	void Edit()
	{

	}

	FileMenu File;

}

struct FileMenu 
{
	NewMenu New;
	void Save()		{ }
	void SaveAs()	{ } 

	void Exit()
	{
		import std.c.stdlib;
		exit(-1);
	}
}

struct NewMenu
{
	void Txt() { } 
	void Png() { }
	void Project() { }

	TestMenu Test;
}

struct TestMenu
{
	void DoSomething() { }
	void DoSomethingElse() { }
	void DoSomethingDiffrent() { }
}