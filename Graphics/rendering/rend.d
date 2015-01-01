module rendering.rend;

//more to come perhaps
struct Vertex
{
	float2 pos;
	float2 coords;
	@Normalized Color color;
}	

struct RenderUniform
{
	float2 invViewport;
	int sampler;
	int type;

	//Could be something else i guess.
	float2 thresholds;
}

struct RenderMaterial
{
	Texture2D texture;
	float2    thresholds;
}


struct Rend
{
	struct RenderInfo
	{
		int start, count, order;
		RenderMaterial material;
	}

	List!RenderInfo renderInfos;
	uint count;

	Program!(RenderUniform, Vertex) spriteProgram;
	Sampler sampler;

	private AsyncRenderBuffer!V renderBuffer;
	
	this(A)(ref A allocator, RenderConfig config)
	{
		renderInfos = List!RenderInfo(allocator, config.maxBatchSize / 6);
		Shader vShader = Shader(ShaderType.vertex, v_Source),
			   fShader = Shader(ShaderType.fragment, f_Source);

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

	void addItems(V[] vertices, uint[] indecies, ref RenderMaterial material)
	{
		renderBuffer.additems(vertices, indecies);
		if(renderInfos.back.material == material)
			renderData.back.count += cast(int)indecies.length;
		else
			renderData ~= RenderInfo(count, cast(int)indecies.length, material);

		count += indecies.length;
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

enum fd_Source = q{
	#version 330
	uniform sampler2D sampler;
	uniform vec3	  thresholds;
	uniform int		  type;

	in vertAttrib 
	{
		vec2 coords;
		vec4 color;
	} vertIn;

	out vec4 fragColor;

	void main()
	{
		vec4 color = texture2D(sampler, vertIn.coords);
		if(type == 0)
		{
			fragColor = color * vertIn.color;
		}
		else 
		{
			float sample = color[int(thresholds.x)];
			if(sample < thresholds.y) discard;

			fragColor = vertIn.color;
			fragColor.a = smoothstep(thresholds.y, thresholds.z, sample);
		}
	}
};