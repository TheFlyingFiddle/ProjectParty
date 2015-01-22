module mainscreen;

import framework;
import ui;
import skin;
import util.strings;
import graphics;
import std.algorithm;
import collections.list;

import world_renderer;
import state;
import do_undo;
import commands;
import allocation;
import tools;

class MainScreen : Screen
{
	Gui gui;
	Menu m;
	EditorState   state;
	Toolbox		  toolBox;

	bool moving;
	EntityPanel   ep;
	WorldRenderer renderer;


	int timerID;

	this() { super(false, false); }
	override void initialize() 
	{
		auto all = Mallocator.it;
		gui = loadGui(all, app, "guiconfig.sdl");

		import common.bindings;
		auto c = fromSDLFile!EditorStateContent(Mallocator.it, "arch.sdl", CompContext());

		state		   = EditorState(c, &onSelectedChanged);	
		renderer       = WorldRenderer(&state);
		toolBox		   = Toolbox(Mallocator.it, &state, &gui);

		
		//Make menu
		m = Menu(all, 100); 
		int file = m.addSubmenu("File");
		int new_ = m.addSubmenu("New", file);
		int entity_ = m.addSubmenu("Entity");
		m.addItem("As Archetype", &asArch, entity_);
	
		ep = EntityPanel(Mallocator.cit, &state);
		auto keeper = app.locate!(TimeKeeper);
		timerID = keeper.startTimer(5, &onAutoSave);
		components = List!Component(all, 20);
	}

	void asArch()
	{
		auto item = state.item(state.selected);
		if(item)
		{
			state.archetypes ~= item.clone();
		}
	}

	override void update(Time time)
	{
		toolBox.use();
	
		auto kboard = gui.keyboard;
		auto mouse  = gui.mouse;
		if(kboard.wasPressed(Key.z))
		{
			if(kboard.isModifiersDown(KeyModifiers.control | KeyModifiers.shift))
			{
				state.doUndo.redo(&state);
			}
			else if(kboard.isModifiersDown(KeyModifiers.control))
			{
				state.doUndo.undo(&state);
			}

			updateComponents();
		}

		if(kboard.wasPressed(Key.c))
		{
			if(kboard.isModifiersDown(KeyModifiers.control))
			{
				auto item = state.item(state.selected);
				if(item)
				{
					if(!state.clipboard.empty)
						state.clipboard.item.deallocate();

					state.clipboard.item = item.clone();
				}
			}
		}

		if(kboard.wasPressed(Key.v))
		{
			if(kboard.isModifiersDown(KeyModifiers.control))
			{
				state.items ~= state.clipboard.item.clone();
			}
		}
		
		if(kboard.wasPressed(Key.n))
		{
			if(kboard.isModifiersDown(KeyModifiers.control))
			{
				addItem();
			}
		}


		import common.components;
		
		if(state.selected != -1)
		{
			if(state.item(state.selected).components.length != components.length)
				updateComponents();
		}
	}	

	void addItem()
	{
		state.doUndo.apply(&state, AddItem(&state));
	}

	void removeItem()
	{
		state.doUndo.apply(&state, RemoveItem(&state));
	}

	override void render(Time time)
	{
		import window.window;

		auto w = app.locate!Window;
		gui.renderer.viewport(float2(w.size));


		gl.viewport(0,0, cast(int)w.size.x, cast(int)w.size.y);

		gui.area = Rect(0,0, w.size.x, w.size.y);
		gui.begin();

		gui.renderer.drawQuad(Rect(0,0, w.size.x, w.size.y), gui.atlas["pixel"], Color(0xFFE7E4E3));

		import std.range : repeat, take;


		auto wr =  Rect(200, 5, w.size.x - 500, w.size.y - 65);
		state.worldRect = wr;


		float2 p = float2.zero;
		gui.scrollarea(wr, p, &guiTest, wr);
		gui.toolbar(Rect(wr.x, wr.y + wr.h + 10, wr.w, 30), toolBox.selected, toolBox.toolIDs);
		

		Rect lp = Rect(5, wr.y, 190, wr.h);

		Rect newItemBox    = Rect(lp.x, lp.y, lp.w / 2 - 5, 25);
		Rect deleteItemBox = Rect(newItemBox.right + 10, lp.y, newItemBox.w, 25);
		Rect proto		   = Rect(lp.x, newItemBox.top + 5, lp.w, 25);
		Rect itemBox = Rect(lp.x, proto.top + 5, lp.w, lp.h - (proto.top + 5 - lp.y));

		gui.selectionfield(proto, state.archetype, state.archetypes.array.map!(x => x.name));
		int sel = state.selected;
		if(gui.listbox(itemBox, sel, state.itemNames))
		{
			state.selected = sel;
		}

		itemBox.y -= 50;
		//gui.typefield(itemBox, t);

		if(gui.button(newItemBox, "New"))
		{
			addItem();
		}

		if(gui.button(deleteItemBox, "Delete"))
		{
			removeItem();
		}

		Rect panel = Rect(wr.right + 5, wr.y, 290, wr.h);
		ep.onGui(gui, panel);

		gui.menu(m);
		gui.end();
	}

	void guiTest(ref Gui gui)
	{
		renderer.renderWorld(gui);
	}

	int oldItem  = -1;
	List!Component components;

	void updateComponents()
	{
		import common;

		components.clear();
		oldItem = state.selected;
		auto item = state.item(oldItem);
		if(!item) return;

		foreach(i, ref comp; item.components)
		{	
			foreach(c; Components)
			{
				import util.traits;
				enum id = cHash!c;
				if(id == comp.type)
				{
					static if(hasMember!(c, "clone"))
						components ~= Component((cast(c*)comp.data.ptr).clone());
					else 
						components ~= comp;
				}
			}
		}
	}

	void onSelectedChanged(EditorState* s)
	{
		if(oldItem == s.selected) return;
		else if(oldItem != -1) 
		{
			onAutoSave();
		}
		
		updateComponents();
	}

	Changed[] findChanged(WorldItem* item)
	{
		import common;

		Changed[] changed;
		foreach(i; 0 .. components.length)
		{
			foreach(c; Components)
			{
				import util.traits;
				enum id = cHash!c;
				if(id == components[i].type)
				{
					auto fst = cast(c*)components[i].data.ptr;
					auto snd = cast(c*)item.components[i].data.ptr;
					
					if(*fst != *snd)
					{
						changed ~= Changed(i, components[i]);
						
						static if(hasMember!(c, "clone"))
							components[i] = Component(snd.clone());
						else 
							components[i] = item.components[i];
					}
				}
			}
		}

		return changed;
	}

	void onAutoSave()
	{
		auto item = state.item(oldItem);
		if(item)
		{			
			auto changed = findChanged(item);			
			if(changed.length > 0)
			{
				import log;
				logInfo("Adding a changed undoRedo command! For entity ", oldItem);
				state.doUndo.add(&state, ComponentsChanged(oldItem, changed));
			}
		}
	}
}


struct EntityPanel
{
	import common;

	EditorState* state;
	EditText textData;

	float2 scroll;
	float2 area;

	int selectedComponent;
	List!bool active;

	this(IAllocator all, EditorState* state, )
	{
		this.state = state;
		textData   = EditText(all, 50);

		this.scroll = float2.zero;
		this.area   = float2.zero;
		this.active = List!bool(all, 20);
		this.active.length = 20;
		this.active[] = false;
	}
	
	void onGui(ref Gui gui, Rect panel)
	{
		Rect area = panel;
		area.h    = panel.h;

		this.area = float2(area.w, area.h);
		gui.scrollarea(panel, scroll, &onGui2);
	}

	void onGui2(ref Gui gui)
	{
		auto item = state.item(state.selected);
		if(item)
		{
			Rect nameBox = Rect(5, area.y - 25, gui.area.w - 15, 20);
			textData ~= item.name;
			gui.name(nameBox, "Name", 60);
			if(gui.textfield(nameBox, textData))
			{
				state.doUndo.apply(state, ChangeItemName(state, textData.array));
			}
			textData.clear();

			float offset = area.y - 65;	
			Rect addBox		 = Rect(5, offset - 5, 100, 25);
			Rect compTypeBox = addBox;
			compTypeBox.x  = addBox.right + 5;
			compTypeBox.w  = gui.area.w - 20 - addBox.w ;

			import std.algorithm;
			gui.selectionfield(compTypeBox, selectedComponent, ComponentIDs);
			if(gui.button(addBox, "AddComp"))
			{
				foreach(c; Components)
				{
					import util.traits;
					enum id = Identifier!c;
					if(id == ComponentIDs[selectedComponent])
					{
						if(!item.hasComp!c)
						{
							state.doUndo.apply(state, AddComponent(state, c.ident));
						}
					}
				}
			}

			offset -= 15;

			int toRemove = -1;
			foreach(i, ref component; item.components)
			{
				import util.traits;
				foreach(c; Components)
				{
					enum id = cHash!c;
					if(id == component.type)
					{
						auto value = cast(c*)component.data.ptr;
						offset -= 25;
						Rect r = Rect(5, offset, gui.area.w - 15, 20);
						gui.label(r, Identifier!c, HorizontalAlignment.center);
						r.x += 2;
						r.y += 2;
						r.w = 16;
						r.h -= 4;
						gui.toggle(r, active[i], "", HashID("arrowToggle"));
						
						r.x = gui.area.w - 35;
						if(gui.button(r, "", HashID("deleteButton")))
							toRemove = i;
					
						if(active[i])
							comp(gui, *value, offset, gui.area.w - 15);

						offset -= 25;
						r = Rect(5, offset, gui.area.w - 15, 20);
						gui.separator(r, Color(0xFFB3B0A9));
					}
				}
			}

			if(toRemove != -1)
				state.doUndo.apply(state, RemoveComponent(state, toRemove));
		}
	}

	bool comp(T)(ref Gui gui, ref T t, ref float offset, float width)
	{
		auto size = gui.typefieldHeight(t);
		offset -= size + 5;
		return gui.typefield(Rect(5, offset, width, size), t, &this);
	}

	bool comp(ref Gui gui, ref Box2DConfig config, ref float offset, float width)
	{
		return false;
	}

	bool comp(ref Gui gui, ref Shape config, ref float offset, float width)
	{
		return false;
	}

	alias Handler = FromItems;
	bool handle(T)(ref Gui gui, FromItems f, Rect r, ref T t, HashID styleID)
	{
		auto var = state.variables[f.name].get!(string[]);

		import std.algorithm;
		auto idx = var.countUntil!(x => x == t);
		if(idx == -1)
			idx = 0;

		if(gui.selectionfield(r, idx, var)) 
		{
			t = var[idx];
			return true;
		}

		return false;
	}
}

void name(ref Gui gui, ref Rect r, string name, int size)
{
	gui.label(Rect(r.x, r.y, size, r.h), name);
	
	r.x += size + 5;
	r.w -= size + 5;
}

struct Toolbox
{
	EditorState* state;
	Gui*		 gui;

	int			 selected;
	private List!Tool		 tools_;
	private List!Tool	 activeTools;	

	this(A)(ref A allocator, EditorState* s, Gui* gui)
	{
		this.state		 = s;
		this.gui		 = gui;
		this.activeTools = List!Tool(allocator, 10);
		this.tools_		 = List!Tool(allocator, 10);
	
		this.tools_ ~= allocator.allocate!SelectTool(s, gui);
		this.tools_ ~= allocator.allocate!ChainTool(s, gui);

	}

	void use()
	{
		activeTools.clear();
		foreach(tool; tools_)
		{
			if(tool.canUse())
			{
				activeTools ~= tool;
			}
		}

		if(selected < 0 || selected >= activeTools.length)
		{
			selected = 0;
		}

		activeTools[selected].use();
	}

	auto toolIDs()
	{
		import std.algorithm;
		return activeTools.map!(x => x.name());
	}
}