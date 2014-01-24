module rendering;

import graphics;
import graphics.convinience;
import math;
import collections;
import types;

/** Very simple renderer that stores everything that has been drawn into a rendertarget. **/
struct AchtungRenderer
{
	private SpriteBuffer buffer;
	private Frame snakeFrame;
	private FBO fbo;

	this(Allocator)(ref Allocator allocator,
					size_t bufferSize, 
					size_t mapWidth,
					size_t mapHeight)
	{
		Color[4] c = [Color.white, Color.white, Color.white, Color.white];
		auto snakeTex = createStandardTexture(2, 2, c);
		snakeFrame = Frame(snakeTex);

		fbo = createSimpleFBO(mapWidth, mapHeight);
		buffer = SpriteBuffer(bufferSize, allocator);
	}

	void clear(Color c)
	{
		gl.bindFramebuffer(FrameBufferTarget.framebuffer, fbo.glName);
		gl.clearColor(c.r, c.g, c.b, c.a);
		gl.clear(ClearFlags.color);
		gl.bindFramebuffer(FrameBufferTarget.framebuffer, 0);
	}

	void draw(ref mat4 transform, ref List!Snake snakes, float size)
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

		blitToBackbuffer(fbo, uint4(0,0, 800, 600),
						 uint4(0,0, 800, 600),
						 BlitMode.color,
						 BlitFilter.nearest);

		gl.bindFramebuffer(FrameBufferTarget.framebuffer, 0);
	}
}