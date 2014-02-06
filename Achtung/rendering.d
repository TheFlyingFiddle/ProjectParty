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
		auto snakeTex = TextureManager.load("textures\\pixel.png");
		font		  = FontManager.load("fonts\\Arial32.fnt");
		snakeFrame = Frame(snakeTex);
		
		fbo    = createSimpleFBO(mapWidth, mapHeight);
	}

	void clear(Color c)
	{
		gl.bindFramebuffer(FrameBufferTarget.framebuffer, fbo.glName);
		gl.clearColor(c.r, c.g, c.b, c.a);
		gl.clear(ClearFlags.color);
		gl.bindFramebuffer(FrameBufferTarget.framebuffer, 0);
	}

	void draw(ref mat4 transform, 
			  ref Table!Snake snakes, 
			  ref Table!int scores,
			  float size)
	{
		gl.bindFramebuffer(FrameBufferTarget.framebuffer, fbo.glName);

		
		auto buffer = Game.spriteBuffer;

		auto origin = float2(size / 2, size / 2);
		foreach(key, snake; snakes) {
			Color c = snake.visible ? key : key * 0.5f;

			buffer.addFrame(snakeFrame, 
			 		 float4(snake.pos.x, snake.pos.y, size, size), 
					        c, origin);
		}

		buffer.flush();
		buffer.draw(transform);
		buffer.clear();

		blitToBackbuffer(fbo, 
						 uint4(0,0, 600, 600),
						 uint4(0,0, 600, 600),
						 BlitMode.color,
						 BlitFilter.nearest);

		gl.bindFramebuffer(FrameBufferTarget.framebuffer, 0);
		
		uint2 winSize = Game.window.size;
		buffer.addFrame(snakeFrame,
						float4(winSize.x * 0.8, 0, 2, winSize.y), 
						Color.white, 
						origin);

		import derelict.opengl3.gl3;
		gl.enable(GL_BLEND);
		gl.BlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

		uint i = 0;
		foreach(c, score; scores){
			buffer.addText(font, score.to!string, //<-- This is a nono fix later.
						   float2(winSize.x * 0.9, (winSize.y - font.size) - i* (winSize.y /  scores.length)),
							      c);
			i++;
		}
		buffer.flush();
		buffer.draw(transform);
		buffer.clear();
	}
}