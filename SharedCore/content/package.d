module content;

public import content.content;
public import content.textureatlas;
public import content.sdl;
public import content.font;

import allocation, graphics.font, graphics.textureatlas;

alias FontHandle  = ContentHandle!Font;
alias AtlasHandle = ContentHandle!TextureAtlas;

ContentLoader createStandardLoader(A)(ref A allocator, IAllocator itemAllocator,
									  size_t maxResources, string resourceFolder)
{
	auto c = ContentLoader(allocator, itemAllocator, maxResources, resourceFolder);
	
	//As time goes by we change this.
	c.addFileLoader(makeLoader!(TextureAtlasLoader, ".atlas"));
	c.addFileLoader(makeLoader!(FontLoader, ".fnt"));
	
	return c;
}