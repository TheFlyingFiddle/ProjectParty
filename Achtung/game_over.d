module game_over;
import std.variant;
import game.state;
import graphics;
import collections;
import types;

class GameOverGameState : IGameState
{
	//Maby theses shoul do someting?
	void init() { }
	void handleInput() { }
	
	void enter(Variant x)
	{
		auto list = x.get!(List!Score);
	}

	void exit() {}

	void update() {}

	void render() 
	{
		gl.clear(ClearFlags.color);

	}

}