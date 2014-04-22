module game.conversions;
import game;
import content;
import graphics;
import allocation;

auto stringToFrame(string ID)
{
	return Frame(Game.content.loadTexture(ID));
}

auto stringToFont(string ID)
{
	return Game.content.loadFont(ID);
}

auto stringToParticle(string ID)
{
	import std.path;
	return fromSDLFile!ParticleEffectConfig(GC.it, buildPath(resourceDir, ID));
}

auto stringToSound(string ID)
{
	return Game.content.loadSound(ID);
}

auto stringToSprite(string ID)
{
	return Game.content.loadSprite(ID);
}

auto intToColor(uint i)
{
	return Color(i);
}