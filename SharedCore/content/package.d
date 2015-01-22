module content;

public import content.content;
public import content.textureatlas;
public import content.sdl;
public import content.font;
public import content.texture;

import allocation, graphics.font, graphics.textureatlas;
import graphics.frame;

alias FontHandle  = ContentHandle!FontAtlas;
alias AtlasHandle = ContentHandle!TextureAtlas;
alias FrameHandle = ContentHandle!Frame;

ContentLoader createStandardLoader(A)(ref A allocator, IAllocator itemAllocator,
									  size_t maxResources, string resourceFolder)
{
	auto c = ContentLoader(allocator, itemAllocator, maxResources, resourceFolder);
	
	//As time goes by we change this.
	c.addFileLoader(makeLoader!(TextureAtlasLoader, ".atlas"));
	c.addFileLoader(makeLoader!(FontLoader, ".fnt"));
	c.addFileLoader(makeLoader!(FrameLoader, ".png"));
	
	return c;
}