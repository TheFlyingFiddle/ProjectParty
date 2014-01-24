module rendering;

import graphics;
import math;
import collections;
import types;

/** Very simple renderer that stores everything that has been drawn into a rendertarget.
**/
struct AchtungRenderer
{
	private SpriteBuffer buffer;
	private Frame snakeFrame;
	private FBO fbo;

	this(Allocator)(ref Allocator allocator,
					size_t bufferSize, 
					size_t mapHeight,
					size_t mapWidth)
	{


		Color[4] c = [Color.white, Color.white, Color.white, Color.white];
		auto snakeTex = Texture2D.create(ColorFormat.rgba, ColorType.ubyte_, InternalFormat.rgba8,
									2, 2, c);
		snakeFrame = Frame(snakeTex);

		//auto vShader = Shader(ShaderType.vertex, achtungVS),
		//    fShader = Shader(ShaderType.fragment, achtungFS);
		//
		//this.program = Program(allocator, vShader, fShader);
		//
		//vShader.destroy();
		//fShader.destroy();
		//
		//vbo = VBO.create(BufferHint.streamDraw);
		//gl.bindBuffer(vbo.target, vbo.glName);
		//vbo.initialize(cast(uint)(bufferSize * Vertex.sizeof * 6));
		//
		//gl.useProgram(program.glName);
		//vao = VAO.create();
		//gl.bindVertexArray(vao.glName);
		//vao.bindAttributesOfType!Vertex(program);

		fbo = FBO.create();
		gl.bindFramebuffer(FrameBufferTarget.framebuffer, fbo.glName);
		auto tex = Texture2D.create(ColorFormat.rgba, 
											 ColorType.ubyte_,
											 InternalFormat.rgba8,
											 cast(uint)mapHeight,
											 cast(uint)mapWidth,
											 null);
		fbo.attachTexture(FrameBufferAttachement.color0, 
						  tex, 0);
		gl.bindFramebuffer(FrameBufferTarget.framebuffer, 0);

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

enum achtungVS =
"
#version 330
in vec2 pos;
in vec4 color;

out vec4 oColor;
uniform mat4 transform;
void main()
{
	gl_Position = transform * vec4(pos, 0 , 1);
		oColor = color;
}
	";

	enum achtungFS = 
		"
		#version 330
		in vec4 oColor;
		out vec4 fragColor;


		void main()
	{
		fragColor = oColor;
}
	";