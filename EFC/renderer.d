module renderer;

import graphics.program2, graphics.buffer, graphics.enums, 
	   graphics.color, graphics.shader, graphics.texture,  
	   graphics.context, collections.list, math;

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

	private Program!(Uniform, Vertex) program;
	private VAO!Vertex vao;
	private VBO vbo;
	private IBO ibo;

	private Vertex* mappedPtr;
	private uint*   mappedIndexPtr;

	private const int batchSize, batchCount;
	private int mappedStart;

	private int elements;
	private int numVertices;

	private List!RenderData renderData;

	this(A)(ref A allocator, size_t maxBatchSize, size_t batchCount)
	{
		this.elements	  = 0;
		this.mappedStart  = 0;
		this.batchSize	  = maxBatchSize;
		this.batchCount	  = batchCount;
		this.renderData	  = List!RenderData(allocator, maxBatchSize / 6);

		Shader vShader = Shader(ShaderType.vertex, vSource),
			   fShader = Shader(ShaderType.fragment, fSource);

		program = Program!(Uniform, Vertex)(vShader, fShader);
		program.uniforms.sampler = 0;

		this.vbo = VBO.create(BufferHint.streamDraw);
		vbo.bind();
		vbo.initialize(Vertex.sizeof * maxBatchSize * batchCount);
		
		this.ibo = IBO.create(BufferHint.streamDraw);
		ibo.bind();
		ibo.initialize(maxBatchSize * 3 * 4 * batchCount);

		this.vao = VAO!Vertex.create();
		setupVertexBindings(vao, program, vbo, &ibo);
	}

	void viewport(float2 viewport)
	{
		float2 invViewport = float2(1 / viewport.x, 1 / viewport.y);
		program.uniforms.invViewport = invViewport;
	}

	void addItems(Vertex[] vertices, uint[] indecies, ref Texture2D texture)
	{
		assert(mappedPtr !is null);
		assert(elements + indecies.length <= (mappedStart + batchSize) * 3);
		assert(numVertices + vertices.length < mappedStart + batchSize);

		mappedPtr[0 .. vertices.length] = vertices[];
		mappedPtr += vertices.length;

		mappedIndexPtr[0 .. indecies.length] = indecies[] + numVertices;
		mappedIndexPtr += indecies.length;

		elements += cast(int)indecies.length;
		numVertices += cast(int)vertices.length;

		if(renderData.back.texture == texture)
			renderData.back.count += cast(int)indecies.length;
		else
			renderData ~= RenderData(cast(ushort)indecies.length, texture);
	}

	void begin() 
	{		
		assert(mappedPtr is null, "Can only begin rendering if we are not already rendering!");

		vbo.bind();
		mappedPtr = vbo.mapRange!Vertex(mappedStart,
										batchSize, 
										BufferRangeAccess.unsynchronizedWrite);

		ibo.bind();
		mappedIndexPtr = ibo.mapRange!uint(mappedStart * 3,
										   batchSize * 3,
										   BufferRangeAccess.unsynchronizedWrite);
	}

	private void draw(int start)
	{
		foreach(data; renderData)
		{
			context[TextureUnit.zero] = data.texture;
			drawElements!(uint, Vertex, Uniform)(this.vao, this.program, 
							  PrimitiveType.triangles,
							  start, data.count);

			start += data.count;
		}
	}

	void end()
	{
		vbo.bind();
		vbo.unmapBuffer();
		mappedPtr = null;

		ibo.bind();
		ibo.unmapBuffer();
		mappedIndexPtr = null;

		
		int start  = mappedStart * 3;
		mappedStart = (mappedStart + batchSize) % (batchSize * batchCount);
		elements    = mappedStart * 3; 
		numVertices = mappedStart;

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