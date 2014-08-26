module screen.loading;
import framework.screen;
import content;
import rendering;

struct LoadingConfig
{
	string[] toLoad;
	string font;
}

class LoadingScreen : Screen
{
	LoadingConfig config;
	FontHandle font;
	AsyncContentLoader* loader;
	Screen next;

	this(LoadingConfig config, Screen next)
	{
		super(false, false);
		this.config = config;
		this.next   = next;
	}

	override void initialize()
	{
		import content;
		loader = app.locate!AsyncContentLoader;

		font = loader.load!FontAtlas(config.font);

		foreach(item; config.toLoad)
			loader.asyncLoad(item);
	}

	override void update(Time time)
	{
		if(loader.areAllLoaded)
		{
			owner.pop();
			owner.push(next);
		}
	}

	uint frame = 0;
	override void render(Time time)
	{
		import std.range, util.strings, window.window;

		auto screen   = app.locate!Window;
		auto renderer = app.locate!FontRenderer;
		renderer.viewport(float2(screen.size));
		renderer.begin();
		
		frame++;

		string msg = cast(string)text1024("Loading", '.'.repeat(frame % 20));		
		renderer.drawText(msg, float2(0,0),float2(50,50), font.asset.fonts[0], Color.white, float2(0.4, 0.5));
		
		renderer.end();
	}
}