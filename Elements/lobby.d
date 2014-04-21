module lobby;

import game;
import math;
import content;
import graphics;
import util.strings : text;
import collections;
import graphics.color;
import content.sdl, allocation;
import std.algorithm : find;
import game.debuging;
import types;
import logging;
import network_types;

struct Layout
{
	float2 players;
	float  playerSpacing;
	List!uint colors;
}

struct PlayerData
{
	Color color;
}

final class LobbyState : IGameState
{
	string title;
	FontID font;
	Layout layout;
	int playerCount = 0;
	int playersReady = 0;

	Table!(ulong, PlayerData) players;

	this(A)(ref A allocator, string title)
	{
		this.title = title;
		layout = fromSDLFile!Layout(allocator, "lobby.sdl");
		players = Table!(ulong, PlayerData)(allocator, 10);
	}

	void enter() 
	{
		foreach(ref player ; Game.players) player.ready = false;

		playerCount = Game.players.length;
		playersReady = 0;

		font = FontManager.load("SegoeUILight72");
		Game.router.connectionHandlers ~= &connection;
		Game.router.reconnectionHandlers ~= &connection;
		Game.router.disconnectionHandlers ~= &disconnection;
		
		Game.router.setMessageHandler(IncomingMessages.readyMessage, &handleReady);
	} 

	void exit()  
	{ 
		Game.router.connectionHandlers.remove(&connection);
		Game.router.reconnectionHandlers.remove(&connection);
		Game.router.disconnectionHandlers.remove(&disconnection);

		Game.router.setMessageHandler(IncomingMessages.readyMessage, null);
	}

	void update()
	{
		if(playerCount != 0 && playerCount == playersReady)
		{	
		}
	}

	void handleReady(ulong id, ubyte[] msg)
	{
		auto logChnl = LogChannel("toggle");
		logChnl.info("ready signal recieved");
		foreach(i, ref player; Game.players)if(player.id == id)
		{
			player.ready ? playersReady-- : playersReady++;
			player.ready = !player.ready;
		}
		if(allPlayersReady())
			Game.transitionTo("GamePlay");
	}

	private bool allPlayersReady()
	{
		foreach(player; Game.players)
		{
			if(!player.ready)
				return false;
		}
		return true;
	}

	void connection(ulong id)
	{
		import network.message;
		auto color = Color(layout.colors[playerCount++]);
		players[id] = PlayerData(color);
	}

	void disconnection(ulong id)
	{
		players.remove(id);
	}

	void render()
	{
		char[1024] buffer = void;
		uint2 s = Game.window.size;
		gl.viewport(0,0, s.x, s.y);
		gl.clear(ClearFlags.color);

		auto size = font.measure(title);
		auto pos = float2(s.x / 2, s.y * 0.95);

		auto sb = Game.renderer;

		import std.stdio;
		auto playerReadyText = text(buffer, "Players: ", playerCount, "\t", "Ready");
		auto playerReadySize = font.measure(playerReadyText);
		sb.addText(font, title, pos, Color(0xFFFFCC00),float2(0.95,0.95),-size/2);	
		sb.addText(font, playerReadyText, float2(s.x/2,s.y * 0.75), 
				   Color(0xFFFFCC00), float2(0.4, 0.4), -font.measure(playerReadyText)/2);

		foreach(i, player; Game.players)
		{
			float2 textPos = float2(s.x/2 - font.measure(playerReadyText).x/2 * 0.4 + 5, s.y * 0.73 - (i + 1) * layout.playerSpacing);

			sb.addText(font, text(buffer, player.name), 
					   textPos, players[player.id].color,float2(0.33, 0.33));

			if(player.ready)
				sb.addRect(float4(textPos.x + 200, textPos.y, 50, 15), Color.green, float2(0, 20));
			else
				sb.addRect(float4(textPos.x + 200, textPos.y,  50, 15), Color.red, float2(0, 20));
		}


		//auto serverText = text(buffer, "Server: ", Game.server.listenerString);
		//sb.addText(font, serverText, float2(2,2),Color.white,float2(0.5,0.5), float2(0, font.messure(serverText).y));
	}
}