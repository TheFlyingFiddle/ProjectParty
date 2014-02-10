module game_over;
import std.variant;
import game.game;
import graphics;
import collections;
import types;

class GameOverGameState : IGameState
{

	void enter()
	{
	//	auto list = x.get!(List!Score);
	}

	void exit() {}

	void update() {}

	void render() 
	{
		gl.clear(ClearFlags.color);

	}

}