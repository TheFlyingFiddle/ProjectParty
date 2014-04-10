module content;

public import content.sdl;
public import content.texture;
public import content.reloading;
public import content.font;
public import content.common;
public import content.sound;

struct ContentConfig
{
	uint maxTrackingResources;
	uint maxReloaders;
	uint maxTextures;
	uint maxFonts;
	uint maxSounds;
}

struct Content
{
	this(A)(ref A allocator, ContentConfig c)
	{
		ContentReloader.init(allocator, c.maxTrackingResources, c.maxReloaders, c.maxTrackingResources);
		TextureManager.init(allocator, c.maxTextures);
		SoundManager.init(allocator, c.maxSounds);

		import allocation;
		FontManager.init(allocator, GC.cit, c.maxFonts);
	}

	~this()
	{
		ContentReloader.shutdown();
		TextureManager.shutdown();
		FontManager.shutdown();
		SoundManager.shutdown();
	}

	void loadAsset(Asset asset)
	{
		import std.string;

		switch(asset.type) with(AssetType)
		{
			case texture:
				loadTexture(asset.path);
				break;
			case font:
				loadFont(asset.path);
				break;
			case sound:
				loadSound(asset.path);
				break;
			default:
				assert(0, format("Loading of assettype %s is not supported", asset.type));
		}
	}

	SoundID loadSound(const(char[]) path)
	{
		return SoundManager.load(path);
	}

	FontID loadFont(const(char[]) path) 
	{
		return FontManager.load(path);
	}

	FontID loadFont(string path)
	{
		return FontManager.load(path);
	}

	TextureID loadTexture(const(char[]) path)
	{
		return TextureManager.load(path);
	}

	TextureID loadTexture(string path)
	{
		return TextureManager.load(path);
	}

}