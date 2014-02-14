module rendering;

import graphics;
import graphics.convinience;
import math;
import collections;
import content;
import types;
import content.sdl;
import derelict.glfw3.glfw3;
import main;
import game;
import achtung_game_data;

/** Very simple renderer that stores everything that has been drawn into a rendertarget. **/
struct AchtungRenderer
{
	private Frame        snakeFrame;
	private FontID       font;
	private FBO	         fbo;

	this(Allocator)(ref Allocator allocator,
					uint bufferSize, 
					uint mapWidth,
					uint mapHeight)
	{
		auto snakeTex = Game.content.loadTexture("textures\\pixel.png");
		font		  = Game.content.loadFont("fonts\\Arial32.fnt");
		snakeFrame = Frame(snakeTex);
		
		fbo    = createSimpleFBO(mapWidth, mapHeight);
		//fbo    = createMultisampleFBO(mapWidth, mapHeight, 4);

	}

	void clear(Color c)
	{
		gl.bindFramebuffer(FrameBufferTarget.framebuffer, fbo.glName);
		gl.clearColor(c.r, c.g, c.b, c.a);
		gl.clear(ClearFlags.color);
		gl.bindFramebuffer(FrameBufferTarget.framebuffer, 0);
	}

	void draw(ref Table!Snake snakes, 
			  AchtungGameData agd,
			  float size)
	{
		gl.bindFramebuffer(FrameBufferTarget.framebuffer, fbo.glName);

		
		auto buffer = Game.renderer;

		auto origin = float2(size / 2, size / 2);
		foreach(key, snake; snakes) {
			Color c = snake.visible ? key : key * 0.5f;

			buffer.addFrame(snakeFrame, 
			 		 float4(snake.pos.x, snake.pos.y, size, size), 
					        c, origin);
		}

		buffer.draw();

		uint2 winSize = Game.window.fboSize;
		blitToBackbuffer(fbo, 
						 uint4(0,0, winSize.x - 100, winSize.y),
						 uint4(0,0, winSize.x - 100, winSize.y),
						 BlitMode.color,
						 BlitFilter.nearest);

		gl.bindFramebuffer(FrameBufferTarget.framebuffer, 0);
		
		buffer.addFrame(snakeFrame,
						float4(winSize.x - 100, 0, 2, winSize.y), 
						Color.white, 
						origin);


		import util.strings;
		char[32] scoreBuffer = void;

		uint i = 0;
		foreach(playerData; agd.data){
			buffer.addText(font, text(scoreBuffer, playerData.score),
						   float2(winSize.x - 80, (winSize.y - font.size) - i* (winSize.y /  agd.data.length)),playerData.color);
			i++;
		}
		buffer.draw();
	}
}