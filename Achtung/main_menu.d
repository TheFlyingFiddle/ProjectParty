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
import game.debuging;
import types;
import logging;

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
	int playerCount = 0;
	int playersReady = 0;

	this(string title, AchtungGameData agd, int numOfPlayers)
	{
		this.title = title;
		this.agd = agd;
		layout = fromSDLFile!Layout(GC.it, "MainMenu.sdl");

	}

	void enter() 
	{
		font = FontManager.load("Blocked72");
		Game.router.connectionHandlers ~= &connection;
		Game.router.reconnectionHandlers ~= &connection;
		Game.router.disconnectionHandlers ~= &disconnection;
		Game.router.messageHandlers ~= &message;
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

		/**
		if(playerCount != 0 && playerCount == playersReady)
		{
			
		}
		*/
	}

	void connection(ulong id)
	{
		agd.data ~= PlayerData(id, Color(layout.colors[playerCount]), 0);
		playerCount ++;
	}

	void disconnection(ulong id)
	{
		auto playerData = agd.data.find!((x) => x.playerId == id)[0];
		agd.data.remove(playerData);
		layout.colors.remove(playerData.color.packedValue);
		layout.colors ~= playerData.color.packedValue;
		playerCount --;
		foreach(i, player; Game.players)if(player.id == id && player.ready)
		{
			playersReady --;
		}
	}

	void render()
	{
		char[1024] buffer = void;
		uint2 s = Game.window.size;
		gl.viewport(0,0, s.x, s.y);
		gl.clear(ClearFlags.color);

		auto size = font.messure(title);
		auto pos = float2(s.x / 2, s.y * 0.95);

		auto sb = Game.renderer;

		import std.stdio;
		auto playerReadyText = text(buffer, "Players: ", playerCount, "\t", "Ready");
		auto playerReadySize = font.messure(playerReadyText);
		sb.addText(font, title, pos, Color(0xFFFFCC00),float2(0.95,0.95),-size/2);	
		sb.addText(font, playerReadyText, float2(s.x/2,s.y * 0.75), 
				   Color(0xFFFFCC00), float2(0.4, 0.4), -font.messure(playerReadyText)/2);
		
		foreach(i, player; Game.players)
		{
			float2 textPos = float2(s.x/2 - font.messure(playerReadyText).x/2 * 0.4 + 5, s.y * 0.73 - (i + 1) * layout.playerSpacing);

			sb.addText(font, text(buffer, player.name), 
					   textPos, agd.data[i].color,float2(0.33, 0.33));
			
			

			if(player.ready)
				sb.addRect(float4(textPos.x + 200, textPos.y, 50, 15), Color.green, float2(0, 20));
			else
				sb.addRect(float4(textPos.x + 200, textPos.y,  50, 15), Color.red, float2(0, 20));
		}


		auto serverText = text(buffer, "Server: ", Game.server.listenerString);
		sb.addText(font, serverText, float2(2,2),Color.white,float2(0.5,0.5), float2(0, font.messure(serverText).y));
	}

	void message(ulong id, ubyte[] message)
	{
		if(message[0] == AchtungMessages.toggleReady)
		{
			playersReady ++;
			auto logChnl = LogChannel("toggle");
			logChnl.info("ready signal recieved");
			foreach(i, ref player; Game.players)if(player.id == id)
			{
				player.ready = !player.ready;
			}
		}
	}
}