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
		loader = game.locate!AsyncContentLoader;

		font = loader.load!FontAtlas(config.font);

		foreach(item; config.toLoad)
			loader.asyncLoad(item);
	}

	override void update(GameTime time)
	{
		if(loader.areAllLoaded)
		{
			owner.pop();
			owner.push(next);
		}
	}

	uint frame = 0;
	override void render(GameTime time)
	{
		import std.range, util.strings;

		frame++;
		auto renderer = game.locate!(Renderer!Vertex);
		string msg = cast(string)text1024("Loading", '.'.repeat(frame % 20));		
		//renderer.drawText(msg, float2(0,0),50, font.asset(), Color.white);
	}
}