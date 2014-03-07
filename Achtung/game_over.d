module game_over;
import std.variant;
import game;
import content;
import graphics;
import collections;
import types;
import util.strings;
import math;
import types;
import achtung_game_data;

class GameOverGameState : IGameState
{
	AchtungGameData agd;
	FontID font;
	float elapsed;
	float interval;

	this(AchtungGameData agd, float interval)
	{
		this.agd		= agd;
		this.interval	= interval;
		this.font		= FontManager.load("fonts\\Blocked72.fnt");
	}

	void enter()
	{
		import std.algorithm;

		this.elapsed = 0;
		sort!("a.score > b.score")(this.agd.data.buffer[0 .. agd.data.length]);
		foreach(i, player ; agd.data)
		{
			import network.message;
			Game.server.sendMessage(player.playerId, PositionMessage(cast(short)(i + 1)));
		}
	}

	void exit() {}

	void update() 
	{
		elapsed += Time.delta;
		if(elapsed >= interval)
		{
			Game.transitionTo("MainMenu");
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