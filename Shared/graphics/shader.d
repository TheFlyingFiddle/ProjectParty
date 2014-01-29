module graphics.shader;
import graphics.context;
import graphics.enums;
import graphics.common;
import util.strings;

/**
* Authors: Lukas B
* Date: June 22, 2013
* Examples:
*-----------------------------------------------------------------------------
*	auto shader = Shader(ShaderType.vertex); 
*	shader.source = myShaderSource;  
*	shader.compile(); //In debug mode failiure will cause an assertion error. 
*	writeln(shader.infoLog); //Prints information of the shader compile process.
* ----------------------------------------------------------------------------
*/
struct Shader
{
	//The name that the opengl driver gave for this shader.
	package uint glName;

	//Creates a shader from a shader name given by the opengl driver.
	this(ShaderType type, const(char)[] source)
	{
		this.glName = gl.createShader(type);
		this.source = source;
		this.compile();
	}

	void destroy() 
	{
		gl.deleteShader(this.glName);
	}

	/// The type of shader.
	ShaderType type() @property 
	{
		return cast(ShaderType)getShaderParameter(ShaderParameter.shaderType);
	}

	///True if the shader has been deleted by a call to free()
	bool deleted() @property
	{
		return getShaderParameter(ShaderParameter.deleteStatus) == TRUE;
	}

	///Gets the source of the shader.
	string source() @property
	{ 
		assert(shaderSourceLength <= c_buffer.length);
		int length;
		gl.getShaderSource(glName,
						   cast(uint)c_buffer.length,
						   &length,
						   c_buffer.ptr);
		return c_buffer[0 .. length].idup;
	}

	///Gets the info log of the shader.
	string infoLog() @property
	{
		assert(infoLogLength <= c_buffer.length);
		int length;
		gl.getShaderInfoLog(glName,
							cast(uint)c_buffer.length,
							&length,
							c_buffer.ptr);
		return c_buffer[0 .. length].idup;
	}

	package void compile()
	{
		gl.compileShader(glName);
		assert(compiled, infoLog);
	}

	package void source(const(char)[] source) @property
	{
		int length = cast(int)source.length;
		auto c_source = cast(char*)source.ptr;
		gl.shaderSource(glName, 1, &c_source, &length);
	}

	private int shaderSourceLength() @property
	{
		return getShaderParameter(ShaderParameter.shaderSourceLength);
	}

	private int infoLogLength() @property
	{
		return getShaderParameter(ShaderParameter.infoLogLength);
	}

	private bool compiled() @property
	{
		return getShaderParameter(ShaderParameter.compileStatus) == TRUE;
	}

	private int getShaderParameter(ShaderParameter param) 
	{
		int data;
		gl.getShaderiv(glName, param, &data);
		return data;
	}

	///Releases resources used by the shader compiler.
	///Shaders can still be compiled after this operation is done.
	///NOTE: Depending on the opengl driver this might do nothing. 
	///		it is more of a hint then an actuall commmand.
	public static void releaseCompiler() 
	{
		gl.releaseShaderCompiler();
	}
}