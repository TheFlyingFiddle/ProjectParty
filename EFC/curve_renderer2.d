module curve_renderer2;

import math, graphics;


struct Line
{
	float2 start, end;
	float2 c0, c1;
}

struct Renderer
{
	struct Vertex
	{
		float2 pos;
		float2 control;
		Color  color;
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
			 fShader = Shader(ShaderType.fragment, fragmentShader),
			 gShader = Shader(ShaderType.geometry, geomShader);

		this.program = Program(allocator, vShader, fShader, gShader);

		vShader.destroy();
		fShader.destroy();
		gShader.destroy();

		gl.bindVertexArray(vao.glName);
		vao.bindAttributesOfType!Vertex(program);
	}

	void drawPath(Line[] lines, Color color)
	{
		gl.lineWidth(5.0f);
		Vertex[128] vertices;
		foreach(i, line; lines)
		{
			vertices[i * 2]		= Vertex(line.start, line.c0, color);
			vertices[i * 2 + 1] = Vertex(line.end,   line.c1, color);
		}


		gl.bindBuffer(vbo.target, vbo.glName);
		vbo.bufferSubData(vertices[0 .. lines.length * 2], 0);

		gl.bindVertexArray(vao.glName);
		gl.useProgram(program.glName);
		program.uniform["transform"] = matrix;

		gl.drawArrays(PrimitiveType.lines, 0, lines.length * 2);
	}
}


enum vertexShader = q{

	#version 330 
	in vec2 pos;
	in vec2 control;
	in vec4 color;

	out vertexAttrib
	{
		vec2 pos;
		vec2 control;
		vec4 color;
	} vertex;

	void main()
	{
		vertex.control  = control;
		vertex.color    = color;
		vertex.pos	    = pos;
	}
};

enum geomShader = q{

	#version 330
	layout(lines) in;
	layout(line_strip, max_vertices = 18) out;
	
	uniform mat4 transform;

	in vertexAttrib
	{
		vec2 pos;
		vec2 control;
		vec4 color;
	} vertex[];


	out vertData {
        vec4 color;
	} vertOut;


	vec2 evaluateBezierPosition( vec2 v[4], float t )
	{
		vec2 p;
		float OneMinusT = 1.0 - t;
		float b0 = OneMinusT*OneMinusT*OneMinusT;
		float b1 = 3.0*t*OneMinusT*OneMinusT;
		float b2 = 3.0*t*t*OneMinusT;
		float b3 = t*t*t;
		return b0*v[0] + b1*v[1] + b2*v[2] + b3*v[3];
	}

	void main()
	{
		vec2 pos[4];
		pos[0] = vertex[0].pos;
		pos[1] = vertex[0].control;
		pos[2] = vertex[1].control;
		pos[3] = vertex[1].pos;
		

		vertOut.color = vertex[0].color;
		gl_Position = transform * vec4(vertex[0].pos, 0, 1);
		EmitVertex();

		float detail = 1.0 / 16.0;
		for(int i = 0; i < 16; i++)
		{
			float t = float(i) * detail;
			vec2 p  = evaluateBezierPosition(pos, t) + vec2(0.5, 0.5);
			vertOut.color = vertex[0].color;
			gl_Position = transform * vec4(p, 0, 1);
			EmitVertex();
		}

		vertOut.color = vertex[1].color;
		gl_Position = transform * vec4(vertex[1].pos, 0, 1);
		EmitVertex();

		//EndPrimitive();
	}

};

enum fragmentShader = q{

	#version 330
	in vertData {
        vec4 color;
	} vertIn;

	out vec4 fragColor;

	void main()
	{
		fragColor = vertIn.color;
	}
};