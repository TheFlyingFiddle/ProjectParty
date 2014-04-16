module graphics.program;

import graphics.enums;
import graphics.shader;
import graphics.common;
import graphics.context;
import util.strings;
import math;
import collections;
import std.traits;
import graphics.color;

struct UniformInfo
{
	StringID name;
	UniformType type;
	int size;
	int loc;
}

struct Uniform
{
	Program program;
	UniformInfo info;

	void set(T)(T value) 
	{
		assert(validateUniform!T(value, info));
		program.flushUniform(info.loc, value);
	}
}

struct VertexAttribute
{
	StringID name;
	uint loc;
	int size;
	VertexAttributeType type;
}

struct Program
{
	uint glName;
	List!UniformInfo uniforms;
	List!VertexAttribute attributes;

	this(Allocator, Shaders...)(ref Allocator allocator, Shaders shaders) 
	{
		this.glName = gl.createProgram();
		this.link(allocator, shaders);
	}

	void obliterate() 
	{
		gl.deleteProgram(this.glName);
	}

	void bindAttributeLocation(const(char)[] name, uint loc)
	{
		gl.bindAttribLocation(glName, loc, name.toCString());
	}

	void bindFragDataLocation(const(char)[] name, uint loc)
	{
		gl.bindFragDataLocation(glName, loc, name.toCString());
	}

	void bindFragDataLocationIndex(const(char)[] name, uint loc, uint index)
	{
		gl.bindFragDataLocationIndexed(glName, loc, index, name.toCString());
	}

	Program link(Allocator, Shaders...)(ref Allocator allocator, Shaders shaders) 
	{
		foreach(shader; shaders)
			gl.attachShader(glName, shader.glName);

		gl.linkProgram(glName);
		assert(linked, infoLog);

		this.attributes = List!VertexAttribute(allocator, activeAttributes);
		this.uniforms   = List!UniformInfo(allocator, activeUniforms);

		cacheUniforms();
		cacheAttributes();

		foreach(shader; shaders)
			gl.detachShader(glName, shader.glName);

		return this;
	}

	Program validate() 
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

	auto uniform() 
	{
		struct UniformIndexer {
			Program prog;
			auto opIndex(StringID index) {	
				foreach(ref uniform; prog.uniforms) {
					if(uniform.name == index)
						return Uniform(prog, uniform);
				}
				assert(0, "Uniform:" ~ index ~ " not found!");
			}

			auto opIndex(string index)
			{
				return opIndex(StringID(index));
			}

			void opIndexAssign(T)(T value, string name) 
			{
				StringID id = StringID(name);
				foreach(ref uniform; prog.uniforms) {
					if(uniform.name == id) {
						prog.validateUniform(value, uniform);
						flushUniform(uniform.loc, value);
					}
				}
			}
		}
		return UniformIndexer(this);
	}

	auto attribute()  
	{
		auto prog = this;
		struct AttributeIndexer	{
			auto opIndex(StringID index) {	
				foreach(ref attribute; prog.attributes) {
					if(attribute.name == index)
						return attribute;
				}
				assert(0, "Attribute: " ~ index ~ " not found!");
			}

			auto opIndex(string index)
			{
				return opIndex(StringID(index));
			}

		}
		return AttributeIndexer();
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

	private void cacheAttributes()
	{
		int numAttribs = this.activeAttributes;
		int length;
		int size;
		int loc;
		uint type;

		foreach(i; 0 .. numAttribs) {
			gl.getActiveAttrib(glName, i, 
							   cast(uint)c_buffer.length, 
							   &length,
							   &size, 
							   &type, 
							   c_buffer.ptr);

			loc = gl.getAttribLocation(glName, c_buffer.ptr);

			StringID name = StringID(c_buffer[0 .. length]);
			attributes ~= VertexAttribute(name, loc, size, 
									      cast(VertexAttributeType)type);
		}
	}

	private void cacheUniforms()
	{
		int total = activeUniforms();
		assert(total <= uniforms.capacity);
		foreach(i; 0 .. total)
		{
			uniforms ~= uniformInfo(i);
		}
	}

	private UniformInfo uniformInfo(uint activeIndex)
	{
		import util.strings;

		int size, length, loc;
		uint type;
		gl.getActiveUniform(glName, activeIndex, cast(uint)c_buffer.length, 
							&length, &size, &type,
							c_buffer.ptr);
		loc = gl.getUniformLocation(glName, c_buffer.ptr);

		StringID name = StringID(c_buffer[0 .. length]);
		return  UniformInfo(name, cast(UniformType)type, size, loc);
	}


	private void validateUniform(T)(T value, UniformInfo uniform)
	{
		debug
		{
			static if(isArray!T) {
				assert(value.length == uniform.size);
				alias typeof(value[0]) type;
			} else {
				alias T type;
			}

			void validate(U)()
			{
				enum msg = "Wrong type for the uniform %s in program %s expected %s was %s.";
				auto msgParams = std.typecons.tuple(uniform.name, this, uniform.type, type.stringof);
				assert(is(type == U), format(msg, msgParams.expand));
			}

			void assertNotImplemented(string s)
			{
				assert(0, "Not implemented! " ~ s);
			}

			alias UniformType UT;
			switch(uniform.type)
			{
				case UT.float_ : validate!(float ); break;
				case UT.float2 : validate!(float2); break;
				case UT.float3 : validate!(float3); break;
				case UT.float4 :  break;
				case UT.int_   : validate!(int   ); break;
				case UT.int2   : validate!(int2  ); break;
				case UT.int3   : validate!(int3  ); break;
				case UT.int4   : validate!(int4  ); break;
				case UT.uint_  : validate!(uint  ); break;
				case UT.uint2  : validate!(uint2 ); break;
				case UT.uint3  : validate!(uint3 ); break;
				case UT.uint4  : validate!(uint4 ); break;

				case UT.mat2   : assertNotImplemented("mat2   vertex attribute arrays"); break;
				case UT.mat3   : assertNotImplemented("mat3   vertex attribute arrays"); break;
				case UT.mat4   : validate!(mat4);										 break;
				case UT.mat2x3 : assertNotImplemented("mat2x3 vertex attribute arrays"); break;
				case UT.mat2x4 : assertNotImplemented("mat2x4 vertex attribute arrays"); break;
				case UT.mat3x2 : assertNotImplemented("mat3x2 vertex attribute arrays"); break;
				case UT.mat3x4 : assertNotImplemented("mat3x4 vertex attribute arrays"); break;
				case UT.mat4x2 : assertNotImplemented("mat4x2 vertex attribute arrays"); break;
				case UT.mat4x3 : assertNotImplemented("mat4x3 vertex attribute arrays"); break;

				//Can only be of sampler type otherwise
				default : 
					validate!(int);
					return;
			}
		}

	}
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