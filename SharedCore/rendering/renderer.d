module rendering.renderer;

import graphics, collections.list, math;
import rendering.asyncrenderbuffer;

struct RenderConfig
{
	size_t maxBatchSize;
	size_t batchCount;
}

struct Vertex
{
	float2 position;
	float2 coords;

	@Normalized Color  color;
}

struct DistVertex
{
	float2 position;
	float2 coords;
	float3 thresholds;

	@Normalized Color color;
}

alias SpriteRenderer = Renderer!Vertex;
alias FontRenderer	 = Renderer!DistVertex;

//Supports sorting on texture?
struct Renderer(V)
{
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

	private AsyncRenderBuffer!V renderBuffer;
	private Program!(Uniform, V) program;
	private List!RenderData renderData;

	private Sampler sampler;

	this(A)(ref A allocator, RenderConfig config, string vSource, string fSource)
	{
		this.renderData	  = List!RenderData(allocator, config.maxBatchSize / 6);
		Shader vShader = Shader(ShaderType.vertex, vSource),
			fShader = Shader(ShaderType.fragment, fSource);

		program = Program!(Uniform, V)(vShader, fShader);
		program.uniforms.sampler = 0;

		sampler = Sampler.create();
		sampler.minFilter(TextureMinFilter.linear);
		sampler.magFilter(TextureMagFilter.linear);

		renderBuffer = AsyncRenderBuffer!V(config.maxBatchSize, config.batchCount, program);
	}

	void viewport(float2 viewport)
	{
		float2 invViewport = float2(1 / viewport.x, 1 / viewport.y);
		program.uniforms.invViewport = invViewport;
	}

	void addItems(V[] vertices, uint[] indecies, ref Texture2D texture)
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
		context[TextureUnit.zero] = sampler;
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

enum v_Source =  q{
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
enum f_Source = q{
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
		fragColor = texture2D(sampler, vertIn.coords) * vertIn.color;
	}
};
enum vd_Source =  q{
	#version 330
	in vec2 position;
	in vec3 thresholds;
	in vec2 coords;
	in vec4 color;

	uniform vec2 invViewport;

	out vertAttrib 
	{
		vec2 coords;
		vec4 color;
		vec3 thresholds;
	} vertOut;

	void main()
	{
		vertOut.color  = color;
		vertOut.coords = coords;
		vertOut.thresholds = thresholds;
		gl_Position    = vec4(position * invViewport * 2 - vec2(1, 1), 0.0, 1.0);
	}
};
enum fd_Source = q{
	#version 330
	uniform sampler2D sampler;
	in vertAttrib 
	{
		vec2 coords;
		vec4 color;
		vec3 thresholds;
	} vertIn;

	out vec4 fragColor;

	void main()
	{
		vec4 color = texture2D(sampler, vertIn.coords);
		float sample = color[int(vertIn.thresholds.x)];
		if(sample < vertIn.thresholds.y) discard;

		fragColor = vertIn.color;
		fragColor.a = smoothstep(vertIn.thresholds.y, vertIn.thresholds.z, sample);
	}
};