module game_over;
import std.variant;
import game.game;
import content;
import graphics;
import collections;
import types;
import util.strings;
import math;
import types;
import achtung_game_data;

static places = ["first","second","third","fourth","fifth"];

struct PlayerRenderData
{
	char[50] name;
	uint nameLength;
	Color color;
	uint score;
}

class GameOverGameState : IGameState
{
	AchtungGameData agd;
	List!PlayerRenderData players;
	FontID titleFont;
	FontID font;
	float elapsed;
	float interval;

	this(A)(ref A allocator, AchtungGameData agd, float interval)
	{
		this.players	= List!PlayerRenderData(allocator, 5);
		this.agd		= agd;
		this.interval	= interval;
		this.titleFont	= FontManager.load("fonts\\Blocked72.fnt");
		this.font		= FontManager.load("fonts\\Megaman24.fnt");
	}

	void enter()
	{
		import std.algorithm;

		this.elapsed = 0;
		sort!("a.score > b.score")(this.agd.data.buffer[0 .. agd.data.length]);
		foreach(i;0..min(5,agd.data.length))
		{
			auto player = Game.players.find!(x => x.id == agd.data[i].playerId)[0];
			auto prd = PlayerRenderData();
			prd.name[0..player.name.length] = player.name[];
			prd.nameLength = player.name.length;
			prd.color = agd.data[i].color;
			prd.score = agd.data[i].score;
			players ~= prd;
		}

		foreach(i, player ; agd.data)
		{
			import network.message;
			Game.server.sendMessage(player.playerId, PositionMessage(cast(short)(i + 1)));
		}

		auto sound = Game.content.loadSound("halleluja");
		Game.sound.playSound(sound);
	}

	void exit() 
	{
		players.clear();
	}

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

		enum offset = 50f;
		enum gameOverString = "GAME OVER";
		auto size = titleFont.measure(gameOverString);
		auto pos = float2(Game.window.size.x/2, Game.window.size.y - offset);

		Game.renderer.addText(titleFont, gameOverString, pos, Color.blue, float2.one, float2(size.x/2,0));
		
		renderPlayerScores(offset + size.y + 100);
	}

	void renderPlayerScores(float offset)
	{
		char[128] buffer = void;

		float longestNameWidth = 0f;
		float longestScoreWidth = 0f;
		foreach(playerData; players)
		{
			auto size = font.measure(playerData.name[0..playerData.nameLength]);
			if(longestNameWidth<size.x)
				longestNameWidth = size.x;
			size = font.measure(text(buffer, playerData.score));
			if(longestScoreWidth<size.x)
				longestScoreWidth = size.x;
		}

		foreach(i, playerData; players)
		{
			auto str = text(buffer, playerData.name[0..playerData.nameLength]);
			auto size = font.measure(str);
			auto height = Game.window.size.y - offset - 75 * i;
			auto pos = float2(Game.window.size.x/2 + longestNameWidth/2, height);
			Game.renderer.addText(font, str, pos, playerData.color, float2.one, float2(size.x,0));

			str = text(buffer, i+1, ". ");
			size = font.measure(str);
			pos = float2(Game.window.size.x/2 - longestNameWidth/2 - font.measure("  ").x, height);
			Game.renderer.addText(font, str, pos, playerData.color, float2.one, float2(size.x,0));

			str = text(buffer, playerData.score);
			size = font.measure(str);
			pos = float2(Game.window.size.x/2 + longestNameWidth/2 + longestScoreWidth + font.measure("  ").x, height);
			Game.renderer.addText(font, str, pos, playerData.color, float2.one, float2(size.x,0));
		}
	}
}