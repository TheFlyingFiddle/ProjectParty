module curve_renderer;
import graphics, math;

struct Renderer
{
	struct Vertex
	{
		float2 coords;
		float2 pos;
		Color  color;
		int side;
	}

	Program program;
	VBO vbo;
	VAO vao;
	mat4 matrix;

	this(A)(ref A allocator, size_t bufferSize)
	{
		
		this.vbo = VBO.create(BufferHint.streamDraw);
		this.vao = VAO.create();

		gl.bindBuffer(vbo.target, vbo.glName);
		vbo.initialize(cast(uint)(bufferSize * Vertex.sizeof));

		auto vShader = Shader(ShaderType.vertex, vertexShader),
			 fShader = Shader(ShaderType.fragment, fragmentShader);

		this.program = Program(allocator, vShader, fShader);

		vShader.destroy();
		fShader.destroy();

		gl.bindVertexArray(vao.glName);
		vao.bindAttributesOfType!Vertex(program);
	}

	void drawTriangle(float2 a, float2 b, float2 c,
					  float2 ta, float2 tb, float2 tc,
					  Color color, int inside = 0)
	{
		Vertex[3] vertices;
		vertices[0] = Vertex(ta, a, color, inside);
		vertices[1] = Vertex(tb, b, color, inside);
		vertices[2] = Vertex(tc, c, color, inside);
		
		gl.bindBuffer(vbo.target, vbo.glName);
		vbo.bufferSubData(vertices[], 0);

		gl.bindVertexArray(vao.glName);
		
		gl.useProgram(program.glName);
		program.uniform["transform"] = matrix;

		gl.drawArrays(PrimitiveType.triangles, 0, 3);
	}
}


enum vertexShader = q{

	#version 330 
	in vec2 coords;
	in vec2 pos;
	in vec4 color;
	in int side;

	uniform mat4 transform;

	out vec2 out_coords;
	out vec4 out_color;
	out int  out_side;

	void main()
	{
		out_coords  = coords;
		out_color   = color;
		out_side	 = side;
		gl_Position = transform * vec4(pos, 0, 1);
	}
};

enum fragmentShader = q{

	#version 330
	in vec2 out_texcoords;
	in vec2 out_coords;
	in vec4 out_color;
	in int  out_side;

	out vec4 fragColor;

	void main()
	{
		vec4 color = out_color;
		vec2 px = dFdx(out_coords);
		vec2 py = dFdy(out_coords);

		float fx = (2 * out_coords.x) * px.x - px.y;
		float fy = (2 * out_coords.x) * py.x - py.y;

		float sd = (out_coords.x * out_coords.x - out_coords.y) / sqrt(fx * fx + fy * fy);

		float alpha;
		if(gl_FrontFacing)
			alpha = 1.5 + sd;
		else 
			alpha = 1.5 - sd;

		if( alpha > 1 )
			color.a = 1;
		else if( alpha < 0 )
			discard;
		else 
			color.a = alpha - 0.5;

		fragColor = color;
	}
};