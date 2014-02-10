module main_menu;

import game;
import math;
import content;
import graphics;
import util.strings;

struct Layout
{
	float2 players;
	float  playerSpacing;
}

final class MainMenu : IGameState
{
	string title;
	FontID font;
	Layout layout;

	this(string title)
	{
		this.title = title;
		
		import content.sdl, allocation;
		layout = fromSDLFile!Layout(GC.it, "MainMenu.sdl");
	}

	void enter() 
	{
		font = FontManager.load("fonts\\Arial32.fnt");
	} 

	void exit()  
	{ 
	
	}

	void update()
	{
		if(Keyboard.isDown(Key.enter) && Game.players.length > 0)
			Game.gameStateMachine.transitionTo("Achtung");
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
						   Color.green, float2(0.5, 0.5));
		}

		sb.addText(font, text(buffer, "Server: ", Game.server.listenerString, 
							  " Players: ", Game.players.length), float2(100, 100));
	}
}