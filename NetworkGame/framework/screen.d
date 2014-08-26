module framework.screen;


public import framework.core;
import collections.list;

abstract class Screen
{
	private Application* _app; //Gives access to game. 
	@property Application* app() { return _app; }
	bool blockUpdate, blockRender;

	ScreenComponent owner() 
	{
		return app.locate!ScreenComponent;
	}


	this(bool blockUpdate, bool blockRender)
	{
		this.blockUpdate = blockUpdate;
		this.blockRender = blockRender;
	}	

	void initialize() { }
	void update(Time time) { }
	void render(Time time) { }
}

final class ScreenComponent : IApplicationComponent
{
	private List!Screen screens;

	this(A)(ref A allocator, size_t numScreens)
	{
		screens = List!Screen(allocator, numScreens);
	}

	void push(Screen screen)
	{
		screen._app = app;
		screen.initialize();
		screens ~= screen;
	}

	Screen pop()
	{
		assert(screens.length);
		auto r = screens[$ - 1];
		screens.length = screens.length - 1;
		return r;
	}

	override void step(Time time)
	{
		int uIndex = screens.countUntil!(x => x.blockUpdate);
		int rIndex = screens.countUntil!(x => x.blockRender);

		foreach(i, screen; screens)
		{
			int j = i;
			if(j > uIndex)
				screen.update(time);
		}

		foreach(i, screen; screens)
		{
			int j = i;
			if(j > rIndex)
				screen.render(time);
		}
	}
}