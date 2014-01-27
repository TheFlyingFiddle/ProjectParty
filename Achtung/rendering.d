module rendering;

import graphics;
import graphics.convinience;
import math;
import collections;
import content;
import types;

/** Very simple renderer that stores everything that has been drawn into a rendertarget. **/
struct AchtungRenderer
{
	private SpriteBuffer buffer;
	private Frame snakeFrame;
	private Font font;
	private FBO fbo;

	this(Allocator)(ref Allocator allocator,
					uint bufferSize, 
					uint mapWidth,
					uint mapHeight)
	{
		//Color[4] c = [Color.white, Color.white, Color.white, Color.white];
		//auto snakeTex = createStandardTexture(2, 2, c);
		
		auto snakeTex = TextureManager.load("textures\\pixel.png");
		font = loadFont(allocator, "..\\resources\\fonts\\Arial32.fnt");

		snakeFrame = Frame(snakeTex);

		fbo = createSimpleFBO(mapWidth, mapHeight);
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

		foreach(i; 0..scores.length){
			buffer.addText(font, scores[i].score.to!string, float2(620, (550 - i*100)), scores[i].color);
		}
		buffer.flush();
		buffer.draw(transform);
		buffer.clear();
	}
}