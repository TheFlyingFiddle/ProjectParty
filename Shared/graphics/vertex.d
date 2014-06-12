module graphics.vertex;

import math.vector;
import graphics;
import std.traits;


alias VertexArray VAO;
struct VertexArray
{
	uint glName;

	static VertexArray create()
	{
		uint name;
		gl.genVertexArrays(1, &name);
		return VertexArray(name);
	}

	void destroy() 
	{
		gl.deleteVertexArrays(1, &glName);
	}

	void bind()
	{
		if(context.vao == glName)
			return;

		context.vao = glName;
		gl.bindVertexArray(glName);
	}

	VertexArray bindAttribute(T)(VertexAttribute attrib, int stride, int offset, bool normalize = glNormalized!T) 
	{
		assertValidAttib!T(attrib);

		gl.enableVertexAttribArray(attrib.loc);
		gl.vertexAttribPointer(attrib.loc, glUnitSize!T, glType!T, normalize, stride, 
							   cast(void*)offset);
		return this;
	}

	VertexArray disableAttrib(VertexAttribute attrib)
	{
		gl.disableVertexAttribArray(attrib.loc);
		return this;
	}

	/** Enables all vertex attributes arrays corresponding to a specific vertex type.
	*   Use this if you use an interleaved vertex buffer object that only contains
	*	 vertices of a specific type.
	*
	*	Example:
	*
	*	struct VertT 
	*	{
	*		float2 position, texCoords;
	*		Color tint;
	*	}
	*
	*	Context.vertexArrays = myVertexArrays;
	*	Context.vertexBuffer = myVertexBuffer; //Containts vertices of type VertT
	*	enableTypeAttribArrays!VertT(myProgram); //This will enable VertexAttributeArrays position, texCoords and tint in the program.
	*														  //And assign appropriate values coorisponding to float2 and Color.
	*
	*/
	void bindAttributesOfType(T)(Program program) if(is(T == struct))
	{
		uint offset = 0;
		foreach(i, trait; FieldTypeTuple!T) {
			enum name = __traits(allMembers, T)[i];
			bindAttribute!trait(program.attribute[name], T.sizeof, offset);
			offset += trait.sizeof;
		}
	}

	bool deleted() @property
	{
		return gl.isVertexArray(glName) == FALSE;
	}

	void free() 
	{
		gl.DeleteVertexArrays(1, &glName);
	}

	private static void assertValidAttib(T)(VertexAttribute attrib) 
	{
		debug
		{
			void validTypes(U...)()
			{
				enum msg = "\nWrong attribute type for attribute %s,\nExpected %s \nActual %s.";
				assert(isAny!(T,U), std.string.format(msg, attrib.name, U.stringof, T.stringof));
			}

			alias VertexAttributeType VT;
			switch(attrib.type) 
			{
				case VT.float_ : validTypes!(uint , float , int ); break;
				case VT.float2 : validTypes!(uint2, float2, int2); break; 
				case VT.float3 : validTypes!(uint3, float3, int3); break;
				case VT.float4 : validTypes!(uint4, float4, int4, Color);	break;
				case VT.int_   : validTypes!(int  ); break;
				case VT.int2   : validTypes!(int2 ); break;
				case VT.int3   : validTypes!(int3 ); break;
				case VT.int4   : validTypes!(int4 ); break;
				case VT.uint_  : validTypes!(uint ); break;
				case VT.uint2  : validTypes!(uint2); break;
				case VT.uint3  : validTypes!(uint3); break;
				case VT.uint4  : validTypes!(uint4); break;

				default :
					assert(false, "Not yet implemented!");
			}
		}
	}

}