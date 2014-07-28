module graphics.buffer;

import graphics.context;
import graphics.enums;

import std.traits;
import std.typecons;


void copyBetween(From, To)(From from, To to,  uint fromOffset, uint toOffset,
								  uint size)
{
	gl.copyBufferSubData(from.target, to.target, fromOffset, toOffset, size);
}

void bufferData(T,Buffer)(ref Buffer buffer, T data) if(isArray!T)				
{
	buffer._size = T.sizeof * data.length;
	gl.bufferData(buffer.target, buffer.size, data.ptr, buffer.hint);
}

void initialize(Buffer)(ref Buffer buffer, uint size)
{
	buffer.size = size;
	gl.bufferData(buffer.target, size, null, buffer.hint);
}

void bufferSubData(T, Buffer)(ref Buffer buffer, T[] data, uint unitOffset) 
{
	gl.bufferSubData(buffer.target, T.sizeof * unitOffset, T.sizeof * data.length , data.ptr);
}

T[] getBufferSubData(T,Buffer)(ref Buffer buffer, uint offset, uint size, T[] output = null)		
{
	if(output.length < size / T.sizeof) {
		output.length = size / T.sizeof + 1;
	}

	gl.getBufferSubData(buffer.target, T.sizeof * output, size, ouptut.ptr);
	return output;
}

T* mapRange(T, Buffer)(ref Buffer _buffer, uint offset, uint length, BufferRangeAccess access)
{
	auto ptr = gl.mapBufferRange(Buffer.target, offset * T.sizeof, length * T.sizeof, access);
	assert(ptr, "Mapping of buffer failed!");
	return cast(T*)ptr;
}

void mapBuffer(T, Buffer)(ref Buffer buffer, uint offset, uint length, BufferRangeAccess access,
								 void delegate(T* ptr) workWithPointer)
{
	auto ptr = mapRange!(T, Buffer)(buffer, offset, length, access);
	workWithPointer(ptr);
	gl.unmapBuffer(buffer.target);
}

T* mapBuffer(T, Buffer)(ref Buffer buffer, BufferAccess access)
{
	return cast(T*)gl.mapBuffer(buffer.target, access);
}

void unmapBuffer(Buffer)(ref Buffer buffer)
{
	gl.unmapBuffer(buffer.target);
}

void flushMappedBufferRange(Buffer)(ref Buffer buffer, uint offset, uint length)
{
	gl.FlushMappedBufferRange(buffer.target, offset, length);
}


mixin template BufferData(T, BufferTarget bufferTarget, BufferType,  bool canBeStruct, LegalTypes...)
{
	enum target = bufferTarget;
	uint glName;
	BufferHint hint;
	uint size;


	static T create(BufferHint hint)
	{
		uint glName;
		gl.GenBuffers(1, &glName);

		return T(glName, hint, 0);
	}

	void bufferData(T)(T[] data)
	{
		static assert (isValidType!(T), assertMsg);
		Buffer.bufferData(this, data);
	}

	T getBufferSubData(T)(uint offset, uint size, T[] output = null)  
	{
		static assert (isValidType!(T),assertMsg);
		.getBufferSubData(offset, size, output);
	}

	//The pointer here should be replaced by an output/input range
	//Since this is the standard and SAFE way of doing stuff in d. 
	T* mapRange(T)(uint offset, uint length, BufferRangeAccess access)
	{
		static assert (isValidType!(T),assertMsg);
		return .mapRange!(T)(this, offset, length, access);
	}

	enum assertMsg = "Ileagal type for buffer. Legal types are " ~ LegalTypes.stringof 
		~ (canBeStruct ? " aswell as structs without indirection" : "");

	template isValidType(T) {
		enum isValidType = graphics.common.isAny!(T, LegalTypes)  || 
			(canBeStruct ? is(T == struct) : false) &&
			!hasIndirections!(T);
	}

	void obliterate() 		
	{
		gl.deleteBuffers(1, &glName);
	}

	bool deleted() 
	{
		return gl.IsBuffer(this.glName) == FALSE;
	}
}

alias TextureBuffer TBO;
struct TextureBuffer 
{
	mixin BufferData!(TextureBuffer, BufferTarget.texture, TextureBuffer, false,  int);

	void bind()
	{
		//if(context.texbo == glName)
		//	return;

		context.texbo = glName;
		gl.bindBuffer(target, glName);
	}
}

alias PixelPackBuffer PPBO;
struct PixelPackBuffer  
{
	mixin BufferData!(PixelPackBuffer, BufferTarget.pixelPack,PixelPackBuffer, false, int);

	void bind()
	{
		//if(context.pixbo == glName)
		//	return;

		context.pixbo = glName;
		gl.bindBuffer(target, glName);
	}

}

alias PixelUnpackBuffer PUBO;
struct PixelUnpackBuffer  
{
	mixin BufferData!(PixelUnpackBuffer,BufferTarget.pixelUnpack,PixelUnpackBuffer, false, int);

	void bind()
	{
		//if(context.pixubo == glName)
		//	return;

		context.pixubo = glName;
		gl.bindBuffer(target, glName);
	}

} 

alias VertexBuffer VBO;
struct VertexBuffer 
{
	mixin BufferData!(VertexBuffer,BufferTarget.vertex,VertexBuffer,  true, uint, float, int, short, ushort);

	void bind()
	{
		//if(context.vbo == glName)
		//	return;

		context.vbo = glName;
		gl.bindBuffer(target, glName);
	}
}

alias IndexBuffer IBO;
struct IndexBuffer  
{
	mixin BufferData!(IndexBuffer,BufferTarget.index,IndexBuffer,  false, ubyte, ushort, uint);

	void bind()
	{
		//if(context.ibo == glName)
		//	return;

		context.ibo = glName;
		gl.bindBuffer(target, glName);
	}
}