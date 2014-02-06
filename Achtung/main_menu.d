module main_menu;

import derelict.glfw3.glfw3;
import derelict.opengl3.gl3;
import std.variant;
import main;
import game;

final class MainMenu : IGameState
{
	void enter() 
	{
	} 

	void exit()  { }

	void update()
	{
		if(Keyboard.isDown(Key.enter))
			Game.gameStateMachine.transitionTo("Achtung");
	}

	void render()
	{
	}
}