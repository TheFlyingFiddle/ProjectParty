module distance_renderer;

import graphics.color, 
	   graphics.enums, 
	   graphics.buffer, 
	   graphics.texture,   
	   graphics.context,
  	   math, 
	   content : TextureID;

import graphics.program2;

struct Vertex
{
	float2 pos;
	float2 coords;
	@Normalized
	Color  color;
}

struct Uniform
{
	mat4 transform;
	int sampler;
	float2 tex;
}

struct Renderer
{
	private VertexArrayObject!Vertex vao;
	private Program!(Uniform, Vertex) program;

	private VBO vbo;
	private Sampler sampler;

	int effect;
	mat4 transform;

	this(A)(ref A allocator, size_t bufferSize)
	{
		this.vbo = VBO.create(BufferHint.streamDraw);
		this.vao = VertexArrayObject!Vertex.create();

		vbo.bind();
		vbo.initialize(cast(uint)(bufferSize * Vertex.sizeof));

		auto vShader = Shader(ShaderType.vertex,   vs),
			 fShader = Shader(ShaderType.fragment, fs);

		this.program = Program!(Uniform, Vertex)(vShader, fShader);

		vShader.destroy();
		fShader.destroy();

		sampler = Sampler.create();
		sampler.magFilter(TextureMagFilter.nearest);
		setupVertexBindings(vao, program, vbo);
	}

	void drawRect(TextureID texture, float4 rect, Color color)
	{
		Vertex[6] vertices;
		float w = texture.width, h = texture.height;
		float4 coords;
		coords.x = 425 / w;
		coords.y = (h - 376 - 82) / h;
		coords.z = coords.x + 67 / w;
		coords.w = coords.y + 82 / h;

		vertices[0] = Vertex(rect.xy, coords.xy, color);
		vertices[1] = Vertex(rect.zy, coords.zy, color);
		vertices[2] = Vertex(rect.zw, coords.zw, color);

		vertices[3] = Vertex(rect.xy, coords.xy, color);
		vertices[4] = Vertex(rect.zw, coords.zw, color);
		vertices[5] = Vertex(rect.xw, coords.xw, color);

		vbo.bind();
		vbo.bufferSubData!Vertex(vertices[], 0);

		vao.bind();

		program.uniforms.transform	= transform;
		program.uniforms.sampler	= 0;
		program.uniforms.tex		= float2(w,h);

		program.use();

		auto tex = texture.texture;
		context[TextureUnit.zero] = tex;
		context[TextureUnit.zero] = sampler;
		gl.drawArrays(PrimitiveType.triangles, 0, 6);
	}

	@disable this(this);
}

enum vs = q{
	#version 330 
	in vec2 coords;
	in vec2 pos;
	in vec4 color;

	uniform mat4 transform;

	out vec2 out_coords;
	out vec4 out_color;

	void main()
	{
		out_coords  = coords;
		out_color   = color;
		gl_Position = transform * vec4(pos, 0, 1);
	}
};

enum fs = q{
	#version 330
	uniform sampler2D sampler;
	uniform vec2 tex;


	in vec2 out_coords;
	in vec4 out_color;
	out vec4 fragColor;

	float aastep(float threshold, float dist)
	{
		float afwidth = 0.7f * length(vec2(dFdx(dist), dFdy(dist)));
		return smoothstep(threshold - afwidth, threshold + afwidth, dist);
	}

	vec4 outline(in float D, in vec4 inner, in vec4 outline)
	{
		float ND = D;
		if(ND >= 0.0 && ND <= 0.9)
		{
			float NND = ND * (1.0 / 0.3);
			float factor = smoothstep(0, 1, NND);
			return mix(inner, outline, factor);
		}

		return vec4(0);
	}


	float distance(in vec2 coords)
	{
		vec2 uv = coords * tex;
		vec2 uv00 = floor(uv - vec2(0.5));
		vec2 uvlerp = uv - uv00 - vec2(0.5);

		vec2 st00 = (uv00 + vec2(0.5)) * vec2(1 / tex.x, 1 / tex.y);

		float offset = 0.5 * (1 / tex.x);
		vec4 D00 = texture2D(sampler, st00);
		vec4 D10 = texture2D(sampler, st00 + vec2(offset, 0.0));
		vec4 D01 = texture2D(sampler, st00 + vec2(0.0, offset));
		vec4 D11 = texture2D(sampler, st00 + vec2(offset, offset));

		vec2 D00_10 = vec2(D00.r, D10.r);// *255.0-128.0;// + vec2(D00.g, D10.g)*(255.0/256.0);
		vec2 D01_11 = vec2(D01.r, D11.r);// *255.0-128.0;// + vec2(D01.g, D11.g)*(255.0/256.0);

		vec2 D0_1 = mix(D00_10, D01_11, uvlerp.y);
		float D   = mix(D0_1.x, D0_1.y, uvlerp.x);
		return D;
	}

	void main()
	{
		float D = distance(out_coords);
		float step = aastep(0.5, D);
		float alpha = 1;
		
		if(D < 0.15) discard;
	
		vec4 inner = vec4(vec3(aastep(0.7, D)), 0);
		vec4 outer = vec4(0.3, 0.7, 0.1, 0);

		fragColor = vec4(1,1,1, 1) + outline(D, inner, outer) ; 
	}
};