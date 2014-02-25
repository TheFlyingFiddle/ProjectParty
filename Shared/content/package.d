module content;

public import content.sdl;
public import content.texture;
public import content.reloading;
public import content.font;
public import content.common;

struct ContentConfig
{
	uint maxTrackingResources;
	uint maxReloaders;
	uint maxTextures;
	uint maxFonts;
}

struct Content
{
	this(A)(ref A allocator, ContentConfig c)
	{
		ContentReloader.init(allocator, c.maxTrackingResources, c.maxReloaders);
		TextureManager.init(allocator, c.maxTextures);

		import allocation;
		FontManager.init(allocator, GC.cit, c.maxFonts);
	}

	~this()
	{
		ContentReloader.shutdown();
		TextureManager.shutdown();
		FontManager.shutdown();
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
			default:
				assert(0, format("Loading of assettype %s is not supported", asset.type));
		}
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