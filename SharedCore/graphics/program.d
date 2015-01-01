module graphics.program;

import graphics.enums, graphics.context, util.strings, math, graphics.color;

struct Program(U, V)
{
	uint glName;	
	int[U.tupleof.length] uniformLocs;
	int[V.tupleof.length] attributeLocs;
	U uniforms;

	this(Shaders...)(Shaders shaders)
	{
		this.glName = gl.createProgram();

		foreach(shader; shaders)
			gl.attachShader(glName, shader.glName);

		foreach(i, dummy; V.init.tupleof)
			gl.bindAttribLocation(glName, i, cast(char*)V.tupleof[i].stringof.ptr);


		gl.linkProgram(glName);
		assert(linked, infoLog);

		validateUniforms();
		validateAttributes();

		foreach(shader; shaders)
			gl.detachShader(glName, shader.glName);
	}

	private void validateUniforms()
	{
		foreach(ref unif; uniformLocs)
			unif = ushort.max;

		//Version one only tests the bare minimum of stuff. 
		import graphics.enums;

		int size, length, loc;
		UniformType type;
		foreach(i; 0 .. activeUniforms())
		{
			gl.getActiveUniform(glName, i, cast(uint)c_buffer.length, 
								&length, &size, cast(uint*)&type,
								c_buffer.ptr);
			loc = gl.getUniformLocation(glName, c_buffer.ptr);

			foreach(j, field; U.init.tupleof)
			{
				enum name   = U.tupleof[j].stringof;
				alias uType = typeof(U.tupleof[j]);

				if(name == c_buffer[0 .. length])
				{
					assert(isUniformType!uType(type), "Wrong type for uniform: " ~ name);
					uniformLocs[j] = loc; //Need to fix for more complex types such as blocks. 					
				}
			}
		}

		assert(activeUniforms() == uniformLocs.length, "Wrong number of uniforms!");
		foreach(i, field; U.init.tupleof)
		{
			assert(uniformLocs[i] != ushort.max, "Uniform " ~ U.tupleof[i].stringof ~ " is not present in the shader!");
		}			
	}

	private void validateAttributes()
	{
		//This implementation is wrong for shaders with matrices.
		int length, size, loc;
		VertexAttributeType type;

		assert(this.activeAttributes == V.tupleof.length, "Wrong number of vertex attributes in shader!");

		foreach(i; 0 .. this.activeAttributes) {
			gl.getActiveAttrib(glName, i, 
							   cast(uint)c_buffer.length, 
							   &length,
							   &size, 
							   cast(uint*)&type, 
							   c_buffer.ptr);
			loc = gl.getAttribLocation(glName, c_buffer.ptr);

			foreach(j, field; V.init.tupleof)
			{
				enum name = V.tupleof[j].stringof;
				alias aType = typeof(V.tupleof[j]);
				if(name == c_buffer[0 .. length])
					attributeLocs[j] = loc;
			}
		}
	}

	void use()
	{
		if(context.program != glName)
			gl.useProgram(glName);

		context.program = glName;
		flushUniforms();
	}

	void flushUniforms()
	{
		foreach(int i, dummy; U.init.tupleof)
		{
			flushUniform(uniformLocs[i], uniforms.tupleof[i]);	
		}
	}

	auto validate() 
	{
		gl.validateProgram(glName);
		assert(valid);
		return this;
	}

	string infoLog() @property
	{
		int length;
		gl.getProgramInfoLog(glName,
							 cast(uint)c_buffer.length,
							 &length,
							 c_buffer.ptr);
		return c_buffer[0 .. length].idup;
	}

	bool deleted() @property
	{
		return cast(bool)getProgramParameter(ProgramProperty.deleted);
	}

	bool linked() @property
	{
		return cast(bool)getProgramParameter(ProgramProperty.linked);
	}

	bool valid() @property
	{
		return cast(bool)getProgramParameter(ProgramProperty.valid);
	}

	int infoLogLength() @property
	{
		return getProgramParameter(ProgramProperty.infoLogLength);
	}

	int activeAttributes() @property
	{
		return getProgramParameter(ProgramProperty.activeAttributes);
	}

	int numTransformFeedbackVaryings() @property
	{
		return getProgramParameter(ProgramProperty.transformFeedbackVaryings);
	}

	int transformFeedbackVaryingMaxLength() @property
	{
		return getProgramParameter(ProgramProperty.transformFeedbackVaryingMaxLength);
	}

	int geometryVerticesOut() @property
	{
		return getProgramParameter(ProgramProperty.geometryVerticesOut);
	}

	int activeUniforms() @property
	{
		return getProgramParameter(ProgramProperty.activeUniforms);
	}

	int numAttachedShaders() @property
	{
		return getProgramParameter(ProgramProperty.numAttachedShaders);
	}

	PrimitiveType geometryInputType() @property
	{
		return cast(PrimitiveType)getProgramParameter(ProgramProperty.geometryInputType);
	}

	PrimitiveType geometryOutputType() @property
	{
		return cast(PrimitiveType)getProgramParameter(ProgramProperty.geometryOutputType);
	}

	private int activeAttributesMaxLength() @property
	{
		return getProgramParameter(ProgramProperty.activeAttributesMaxLength);
	}

	private int activeUniformsMaxLength() @property
	{
		return getProgramParameter(ProgramProperty.activeUniformsMaxLength);
	}

	private int getProgramParameter(ProgramProperty pp) 
	{
		int data;
		gl.getProgramiv(glName, pp, &data);
		return data;
	}
}


alias VAO = VertexArrayObject;
struct VertexArrayObject(T)
{
	uint glName;
	uint ibo;

	static VertexArrayObject!(T) create()
	{
		uint name;
		gl.genVertexArrays(1, &name);

		return VertexArrayObject!T(name, 0);
	}

	void bind()
	{
		if(context.vao != glName)
			gl.bindVertexArray(glName);

		context.vao = glName;
		context.ibo = ibo;
	}

	void unbind()
	{
		if(context.vao == glName)
		{
			ibo = context.ibo;
			context.ibo = 0;
			context.vao = 0;
			gl.bindVertexArray(0);
		}
	}
}

alias Alias(T...) = T;
struct Normalized { }
import graphics.buffer;
void setupVertexBindings(A, U)(ref VertexArrayObject!A vao,
							   ref Program!(U, A) program,
							   ref VBO buffer,
							   IBO* ibo = null)
{
	import std.stdio;
	import graphics.context;
	import derelict.opengl3.gl3;

	import graphics.common;
	vao.bind();
	buffer.bind();
	if(ibo !is null)
		ibo.bind();

	uint offset = 0;
	foreach(i, field; A.init.tupleof)
	{
		enum name = A.tupleof[i].stringof;
		alias type = typeof(A.tupleof[i]);

		gl.enableVertexAttribArray(program.attributeLocs[i]);

		alias attribs = Alias!(__traits(getAttributes, A.tupleof[i]));
		bool normalized = attribs.length == 1 && is(attribs[0] == Normalized);

		gl.vertexAttribPointer(program.attributeLocs[i], glUnitSize!type,
							   glType!type, normalized, A.sizeof, cast(void*)offset);
		
		offset += type.sizeof;
	}

	vao.unbind();
}

void drawArrays(V, U)(ref VAO!V vao, 
					  ref Program!(U,V) program, 
					  PrimitiveType type, 
					  int start, 
					  int length)
{
	vao.bind();
	program.use();
	gl.drawArrays(type, start, length);
}

void drawElements(T, V, U)(ref VAO!V vao,
						   ref Program!(U,V) program,
						   PrimitiveType type,
						   int start,
						   int length)
{
	vao.bind();
	program.use();
	
	static if(is(T == uint))
		gl.drawElements(type, length,  IndexBufferType.uint_, cast(void*)(start * 4));
	else  if(is(T == ushort))
		gl.drawElements(type, length,  IndexBufferType.ushort_, cast(void*)(start * 2));
	else 
		static assert(0, "Must be uint or ushort!");

	vao.unbind();

}

private void flushUniform(int loc, int value)
{
	gl.uniform1i(loc, value);
}

private void flushUniform(int loc,  int[] value) 
{
	gl.uniform1iv(loc, cast(uint)value.length, cast(int*)value.ptr);
}

private void flushUniform(int loc,  int2 value) 
{
	gl.uniform2i(loc, value.x, value.y);
}

private void flushUniform(int loc, int2[] value) 
{
	gl.uniform2iv(loc, cast(uint)value.length, cast(int*)value.ptr);
}

private void flushUniform(int loc, int3 value)
{
	gl.uniform3i(loc, value.x, value.y, value.z);
}

private void flushUniform(int loc, int3[] value) 
{
	gl.uniform3iv(loc, cast(uint)value.length, cast(int*)value.ptr);
}

private void flushUniform(int loc, int4 value) 
{
	gl.uniform4i(loc, value.x, value.y, value.z, value.w);
}

private void flushUniform(int loc, int4[] value)
{
	gl.uniform4iv(loc, cast(uint)value.length, cast(int*)value.ptr);
}

private void flushUniform(int loc, uint value)
{
	gl.uniform1ui(loc, value);
}

private void flushUniform(int loc, uint[] value) 
{
	gl.uniform1uiv(loc, cast(uint)value.length, cast(uint*)value.ptr);
}

private void flushUniform(int loc, uint2 value)
{
	gl.uniform2ui(loc, value.x, value.y);
}

private void flushUniform(int loc, uint2[] value)
{
	gl.uniform2uiv(loc, cast(uint)value.length, cast(uint*)value.ptr);
}

private void flushUniform(int loc, uint3 value)
{
	gl.uniform3ui(loc, value.x, value.y, value.z);
}

private void flushUniform(int loc, uint3[] value)
{
	gl.uniform3uiv(loc, cast(uint)value.length, cast(uint*)value.ptr);
}

private void flushUniform(int loc, uint4 value)
{
	gl.uniform4ui(loc, value.x, value.y, value.z, value.w);
}

private void flushUniform(int loc, uint4[] value)
{
	gl.uniform4uiv(loc, cast(uint)value.length, cast(uint*)value.ptr);
}

private void flushUniform(int loc, float value)
{
	gl.uniform1f(loc, value);
}

private void flushUniform(int loc, float[] value)
{
	gl.uniform1fv(loc, cast(uint)value.length, cast(float*)value.ptr);
}

private void flushUniform(int loc, float2 value)
{
	gl.uniform2f(loc, value.x, value.y);
}

private void flushUniform(int loc, float2[] value)
{
	gl.uniform2fv(loc, cast(uint)value.length, cast(float*)value.ptr);
}

private void flushUniform(int loc, float3 value)
{
	gl.uniform3f(loc, value.x, value.y, value.z);
}

private void flushUniform(int loc, float3[] value)
{
	gl.uniform3fv(loc, cast(uint)value.length, cast(float*)value.ptr);
}

private void flushUniform(int loc, float4 value)
{
	gl.uniform4f(loc, value.x, value.y, value.z, value.w);
}

private void flushUniform(int loc, Color color)
{
	flushUniform(loc, float4(color.r, color.g, color.b, color.a));
}

private void flushUniform(int loc, float4[] value)
{
	gl.uniform4fv(loc, cast(uint)value.length, cast(float*)value.ptr);
}

private void flushUniform(int loc, in mat4 matrix)
{
	gl.uniformMatrix4fv(loc, 1, FALSE, cast(float*)&matrix);
}