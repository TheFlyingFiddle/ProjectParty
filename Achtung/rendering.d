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

/** Very simple renderer that stores everything that has been drawn into a rendertarget. **/
struct AchtungRenderer
{
	private SpriteBuffer buffer;
	private Frame        snakeFrame;
	private FontID       font;
	private FBO	         fbo;

	this(Allocator)(ref Allocator allocator,
					uint bufferSize, 
					uint mapWidth,
					uint mapHeight)
	{
		//Color[4] c = [Color.white, Color.white, Color.white, Color.white];
		//auto snakeTex = createStandardTexture(2, 2, c);
		
		auto snakeTex = TextureManager.load("textures\\pixel.png");
		font		  = FontManager.load("fonts\\Arial32.fnt");

		snakeFrame = Frame(snakeTex);


		fbo    = createSimpleFBO(mapWidth, mapHeight);
		buffer = SpriteBuffer(512, allocator);
	}

	void clear(Color c)
	{
		gl.bindFramebuffer(FrameBufferTarget.framebuffer, fbo.glName);
		gl.clearColor(c.r, c.g, c.b, c.a);
		gl.clear(ClearFlags.color);
		gl.bindFramebuffer(FrameBufferTarget.framebuffer, 0);
	}

	void draw(ref mat4 transform, ref List!Snake snakes, float size, ref List!Score scores)
	{
		gl.bindFramebuffer(FrameBufferTarget.framebuffer, fbo.glName);

		auto origin = float2(size / 2, size / 2);
		foreach(i, snake; snakes) {
			buffer.addFrame(snakeFrame, 
			 		 float4(snake.pos.x, snake.pos.y, size, size), 
					        snake.color, 
							origin);
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

		int x,y;
		glfwGetWindowSize(window, &x, &y);
		buffer.addFrame(snakeFrame,
						float4(x * 0.8, 0, 2, y), 
						Color.white, 
						origin);

		import derelict.opengl3.gl3;
		gl.enable(GL_BLEND);
		gl.BlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

		foreach(i; 0..scores.length){
			buffer.addText(font, scores[i].score.to!string, float2(x * 0.9, (y- font.size) - i*(y/scores.length)), scores[i].color);
		}
		buffer.flush();
		buffer.draw(transform);
		buffer.clear();
	}
}