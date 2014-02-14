module main_menu;

import game;
import math;
import content;
import graphics;
import util.strings : text;
import achtung_game_data;
import collections.list;
import graphics.color;
import content.sdl, allocation;
import std.algorithm : find;

struct Layout
{
	float2 players;
	float  playerSpacing;
	List!uint colors;
}

final class MainMenu : IGameState
{
	string title;
	FontID font;
	Layout layout;
	AchtungGameData agd;
	int colorCount = 0;

	this(string title, AchtungGameData agd, int numOfPlayers)
	{
		this.title = title;
		this.agd = agd;
		layout = fromSDLFile!Layout(GC.it, "MainMenu.sdl");

	}

	void enter() 
	{
		font = FontManager.load("fonts\\Arial32.fnt");

		Game.router.connectionHandlers ~= &connection;
		Game.router.reconnectionHandlers ~= &connection;
		Game.router.disconnectionHandlers ~= &disconnection;
	} 

	void exit()  
	{ 
		Game.router.connectionHandlers.remove(&connection);
		Game.router.reconnectionHandlers.remove(&connection);
		Game.router.disconnectionHandlers.remove(&disconnection);

	}

	void update()
	{
		if(Keyboard.isDown(Key.enter) && Game.players.length > 0)
			Game.gameStateMachine.transitionTo("Achtung");
	}

	void connection(ulong id)
	{
		agd.data ~= PlayerData(id, Color(layout.colors[colorCount]), 0);
		colorCount ++;
	}

	void disconnection(ulong id)
	{

		auto playerData = agd.data.find!((x) => x.playerId == id)[0];
		agd.data.remove(playerData);
		layout.colors.remove(playerData.color.packedValue);
		layout.colors ~= playerData.color.packedValue;
		colorCount --;
	}


	void render()
	{
		uint2 s = Game.window.size;
		gl.viewport(0,0, s.x, s.y);
		gl.clear(ClearFlags.color);


		auto size = font.messure(title);
		auto pos = float2(s.x / 2 - size.x / 2, s.y - size.y);

		auto sb = Game.renderer;

		import std.stdio;
		
		sb.addText(font, title, pos);	
		sb.addText(font, "Connected Players", layout.players, Color.green, float2(0.6, 0.6));

		char[1024] buffer = void;

		foreach(i, player; Game.players)
		{
			sb.addText(font, text(buffer, "Player: ", player.name), 
						   float2(layout.players.x, layout.players.y - (i + 1) * layout.playerSpacing), 
						   agd.data[i].color, float2(0.5, 0.5));
		}

		sb.addText(font, text(buffer, "Server: ", Game.server.listenerString, 
							  " Players: ", Game.players.length), float2(100, 100));
	}
}