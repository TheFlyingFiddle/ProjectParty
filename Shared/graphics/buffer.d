module graphics.buffer;

import graphics.context;
import graphics.enums;

import std.traits;
import std.typecons;


static void copyBetween(From, To)(From from, To to,  uint fromOffset, uint toOffset,
								  uint size)
{
	gl.copyBufferSubData(from.target, to.target, fromOffset, toOffset, size);
}

static void bufferData(T,Buffer)(ref Buffer buffer, T data) if(isArray!T)				
{
	buffer._size = T.sizeof * data.length;
	gl.bufferData(buffer.target, buffer.size, data.ptr, buffer.hint);
}

static void initialize(Buffer)(ref Buffer buffer, uint size)
{
	buffer.size = size;
	gl.bufferData(buffer.target, size, null, buffer.hint);
}

static void bufferSubData(T, Buffer)(ref Buffer buffer, T[] data, uint unitOffset) 
{
	gl.bufferSubData(buffer.target, T.sizeof * unitOffset, T.sizeof * data.length , data.ptr);
}

static T[] getBufferSubData(T,Buffer)(ref Buffer buffer, uint offset, uint size, T[] output = null)		
{
	if(output.length < size / T.sizeof) {
		output.length = size / T.sizeof + 1;
	}

	gl.getBufferSubData(buffer.target, T.sizeof * output, size, ouptut.ptr);
	return output;
}

static T* mapRange(Buffer,T)(ref Buffer buffer, uint offset, uint length, BufferAccess access)
{
	auto ptr = gl.mapBufferRange(Buffer.target, offset, length, access);
	if(!ptr) {
		throw new Exception("Mapping of buffer failed!");
	}
	return cast(T*)ptr;
}

static void mapBuffer(T, Buffer)(ref Buffer buffer, uint offset, uint length, BufferAccess access,
								 void delegate(T* ptr) workWithPointer)
{
	auto ptr = cast(T*)gl.MapBufferRange(buffer.target, offset, length, access);
	workWithPointer(ptr);
	gl.unmapBuffer(buffer.target);
}

static void flushMappedBufferRange(Buffer)(ref Buffer buffer, uint offset, uint length)
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
	T* mapRange(T)(uint offset, uint length, BufferAccess access)
	{
		static assert (isValidType!(T),assertMsg);
		return Buffer.mapRange!(T)(this, offset, length, access);
	}

	enum assertMsg = "Ileagal type for buffer. Legal types are " ~ LegalTypes.stringof 
		~ (canBeStruct ? " aswell as structs without indirection" : "");

	template isValidType(T) {
		enum isValidType = graphics.common.isAny!(T, LegalTypes)  || 
			(canBeStruct ? is(T == struct) : false) &&
			!hasIndirections!(T);
	}

	void destroy() 		
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
}

alias PixelPackBuffer PPBO;
struct PixelPackBuffer  
{
	mixin BufferData!(PixelPackBuffer, BufferTarget.pixelPack,PixelPackBuffer, false, int);
}

alias PixelUnpackBuffer PUBO;
struct PixelUnpackBuffer  
{
	mixin BufferData!(PixelUnpackBuffer,BufferTarget.pixelUnpack,PixelUnpackBuffer, false, int);
} 

alias VertexBuffer VBO;
struct VertexBuffer 
{
	mixin BufferData!(VertexBuffer,BufferTarget.vertex,VertexBuffer,  true, uint, float, int, short, ushort);
}

alias IndexBuffer IBO;
struct IndexBuffer  
{
	mixin BufferData!(IndexBuffer,BufferTarget.index,IndexBuffer,  false, ubyte, ushort, uint);
}