module game.states.lobby;

import graphics;
import game;
import math;
import content;
import collections;
import std.algorithm;

struct Layout
{
	float titleMargin;
	@Convert!intToColor() Color titleColor;
	float playerMargin;
	float rightLeftMargin;
	float playerSpacing;

	@Convert!stringToFont() FontID titleFont;
	@Convert!stringToFont() FontID playerFont;

	List!uint colors;

	string title;

	@Optional("") string allReadySound;
}

struct PlayerData
{
	bool ready;
}

final class LobbyState : IGameState
{
	Layout layout;

	string transitionTo;
	ubyte readyID;

	Table!(ulong, PlayerData) players;

	float elapsed;
	float countDown = 1;

	this(A)(ref A allocator, string layoutFile, string transitionTo, ubyte readyID)
	{
		layout = fromSDLFile!Layout(allocator, layoutFile);
		auto resolutionScale = Game.window.relativeScale;
		layout.titleMargin *= resolutionScale.x;
		layout.playerMargin *= resolutionScale.x;
		layout.rightLeftMargin *= resolutionScale.x;
		layout.playerSpacing *= resolutionScale.x;
		players = Table!(ulong, PlayerData)(allocator, Game.players.capacity);
		this.transitionTo = transitionTo;
		this.readyID = readyID;
	}

	void enter() 
	{
		Game.router.connectionHandlers ~= &connection;
		Game.router.reconnectionHandlers ~= &connection;
		Game.router.disconnectionHandlers ~= &disconnection;

		Game.router.setMessageHandler(readyID, &handleReady);

		elapsed = 0;
		players.clear();
		foreach(player; Game.players)
		{
			players[player.id] = PlayerData(false);
		}
	} 

	void exit()  
	{ 
		Game.router.connectionHandlers.remove(&connection);
		Game.router.reconnectionHandlers.remove(&connection);
		Game.router.disconnectionHandlers.remove(&disconnection);

		Game.router.setMessageHandler(readyID, null);
	}

	void update()
	{
		if(allPlayersReady())
		{
			elapsed += Time.delta;
			if(elapsed >= countDown)
			{
				Game.transitionTo(transitionTo);
			}
		}
	}

	void handleReady(ulong id, ubyte[] msg)
	{
		players[id].ready = !players[id].ready;

		if(allPlayersReady())
		{
			if(layout.allReadySound != "")
			{
				auto sound = Game.content.loadSound(layout.allReadySound);
				Game.sound.playSound(sound);
			}
			elapsed = 0;
		}
	}

	private bool allPlayersReady()
	{
		if(players.length == 0)
			return false;
		foreach(player; players)
		{
			if(!player.ready)
				return false;
		}
		return true;
	}

	void connection(ulong id)
	{
		import network.message;
		import std.random;
		while(true)
		{
			auto color = Color(layout.colors[uniform(0, layout.colors.length)]);
			auto index = Game.players.countUntil!(x=>x.color==color);
			if(index != -1)
				continue;
			index = Game.players.countUntil!(x=>x.id==id);
			Game.players[index].color = color;
			players[id] = PlayerData(false);
			break;
		}
	}

	void disconnection(ulong id)
	{
		players.remove(id);
	}

	void render()
	{
		import util.profile;

		import util.strings;
		auto resolutionScale = Game.window.relativeScale;
		char[1024] buffer = void;
		uint2 s = Game.window.size;
		gl.viewport(0,0, s.x, s.y);
		gl.clear(ClearFlags.color);

		auto titleSize = layout.titleFont.measure(layout.title);
		auto pos = float2(s.x / 2, s.y - layout.titleMargin*resolutionScale.y);

		auto sb = Game.renderer;
		sb.addText(layout.titleFont, layout.title, pos, layout.titleColor, resolutionScale, titleSize/2);

		foreach(i, player; Game.players)
		{
			auto nameSize = layout.playerFont.measure(player.name);
			float2 textPos = float2(s.x/2 - layout.rightLeftMargin, 
									pos.y - titleSize.y*resolutionScale.y - layout.playerMargin*resolutionScale.y - (i + 1) * (layout.playerSpacing*resolutionScale.y + nameSize.y));

			sb.addText(layout.playerFont, player.name, 
					   textPos, player.color,resolutionScale,float2(nameSize.x, 0));

			float2 readyPos = float2(s.x/2 + layout.rightLeftMargin*resolutionScale.x,textPos.y);

			if(players[player.id].ready)
				sb.addText(layout.playerFont, "Ready!", readyPos, Color.green, resolutionScale);
			else
				sb.addText(layout.playerFont, "not ready", readyPos, Color.red, resolutionScale);
		}

		if(allPlayersReady())
		{
			auto countDownText = text(buffer, "Starting in: ", countDown - elapsed);
			auto ctSize = layout.playerFont.measure(countDownText);

			sb.addText(layout.playerFont, countDownText, float2(0, ctSize.y), Color.white, resolutionScale);
		}

		//auto serverText = text(buffer, "Server: ", Game.server.listenerString);
		//sb.addText(font, serverText, float2(2,2),Color.white,float2(0.5,0.5), float2(0, font.messure(serverText).y));
	}
}