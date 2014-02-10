module game_over;
import std.variant;
import game;
import content;
import graphics;
import collections;
import types;
import util.strings;
import math;

class GameOverGameState : IGameState
{
	FontID font;
	float elapsed;
	float interval;

	this(float interval)
	{
		this.interval	= interval;
		this.font		= FontManager.load("fonts\\Arial32.fnt");
	}

	void enter()
	{
		this.elapsed = 0;
	}

	void exit() {}

	void update() 
	{
		elapsed += Time.delta;
		if(elapsed >= interval)
		{
			Game.gameStateMachine.transitionTo("MainMenu");
		}
	}

	void render() 
	{
		gl.clear(ClearFlags.color);
		
		char[128] buffer = void;
		auto msg = text(buffer, "Game Over! Transitioning to start in: ", interval - elapsed);

		auto size    = font.messure(msg);
		auto fsize   = float2(Game.window.fboSize);
		
		Game.renderer.addText(font, msg, fsize / 2, Color.white, float2(1,1),  -size / 2);
	}

}