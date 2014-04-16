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
		import std.algorithm;

		gl.clear(ClearFlags.color);
		
		char[128] buffer = void;
		
		float2 base = float2(0, 500);
		foreach(i, playerData; agd.data)
		{
			auto player = Game.players.find!(x => x.id == playerData.playerId)[0];
			auto str = text(buffer, "Player ", player.name, " Place ", i + 1,  " Score ", playerData.score);
			Game.renderer.addText(font, str, base + float2(0, -100) * i, playerData.color, float2(0.5, 0.5));
		}
		
		auto msg = text(buffer, "Transitioning to start in: ", interval - elapsed);

		auto size    = font.measure(msg);
		auto fsize   = float2(Game.window.fboSize);
		
		Game.renderer.addText(font, msg, float2(0, size.y), Color.white, float2(1,1));
	}

}