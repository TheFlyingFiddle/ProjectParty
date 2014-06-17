module rendering.renderer;

import graphics, collections.list, math;
import rendering.asyncrenderbuffer;

//Supports sorting on texture?
struct Renderer
{
	struct Vertex
	{
		float2 position;
		float2 coords;

		@Normalized
			Color  color;
	}

	struct Uniform
	{
		float2 invViewport;
		int sampler;
	}

	struct RenderData
	{
		uint count;
		Texture2D texture;
	}
	private AsyncRenderBuffer!Vertex renderBuffer;
	private Program!(Uniform, Vertex) program;
	private List!RenderData renderData;

	this(A)(ref A allocator, size_t maxBatchSize, size_t batchCount)
	{
		this.renderData	  = List!RenderData(allocator, maxBatchSize / 6);
		Shader vShader = Shader(ShaderType.vertex, vSource),
			   fShader = Shader(ShaderType.fragment, fSource);

		program = Program!(Uniform, Vertex)(vShader, fShader);
		program.uniforms.sampler = 0;

		renderBuffer = AsyncRenderBuffer!Vertex(maxBatchSize, batchCount, program);
	}

	void viewport(float2 viewport)
	{
		float2 invViewport = float2(1 / viewport.x, 1 / viewport.y);
		program.uniforms.invViewport = invViewport;
	}

	void addItems(Vertex[] vertices, uint[] indecies, ref Texture2D texture)
	{
		renderBuffer.addItems(vertices, indecies);
		if(renderData.back.texture == texture)
			renderData.back.count += cast(int)indecies.length;
		else
			renderData ~= RenderData(cast(ushort)indecies.length, texture);
	}

	void begin() 
	{		
		renderBuffer.map();
	}

	private void draw(int start)
	{
		foreach(data; renderData)
		{
			context[TextureUnit.zero] = data.texture;
			renderBuffer.render(start, data.count, program);
			start += data.count;
		}
	}

	void end()
	{
		int start = renderBuffer.unmap();
		draw(start);
		renderData.clear();
	}
}

enum vSource =  q{
	#version 330
	in vec2 position;
	in vec2 coords;
	in vec4 color;

	uniform vec2 invViewport;

	out vertAttrib 
	{
		vec2 coords;
		vec4 color;
	} vertOut;

	void main()
	{
		vertOut.color  = color;
		vertOut.coords = coords;
		gl_Position    = vec4(position * invViewport * 2 - vec2(1, 1), 0.0, 1.0);
	}
};

enum fSource = q{
	#version 330
	uniform sampler2D sampler;
	in vertAttrib 
	{
		vec2 coords;
		vec4 color;
	} vertIn;

	out vec4 fragColor;

	void main()
	{
		vec4 color = texture2D(sampler, vertIn.coords) * vertIn.color;
		if(color.a < 0.01) discard;

		fragColor = color;
	}
};