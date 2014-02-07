module game.rendering;

import graphics, 
	   content.texture, 
	   content.font,
	   math, 
	   collections.list,
	   logging;

struct TextureToRender
{
	TextureID texID = TextureID(uint.max); //Hmm...
	uint count;
}

struct Vertex
{
	float4 pos;
	float4 texCoord;
	float2 origin;
	Color  color;
	float  rotation;
}

struct Transform
{
	float2 position;
	float2 scale;
	float2 origin;
	float  rotation;
}

auto logChnl = LogChannel("RENDERING");

struct Renderer
{
	private VBO vbo;
	private VAO vao;
	private Program program;

	private List!TextureToRender toRender;
	private TextureToRender active;
	
	private uint elements;
	private uint bufferSize;

	private Vertex* bufferPtr;

	this(A)(ref A allocator, size_t maxDiffrentTextures, size_t bufferSize)
	{
		this.elements = 0;
		this.bufferSize = bufferSize;
		this.toRender = List!TextureToRender(allocator, maxDiffrentTextures);

		this.vbo = VBO.create(BufferHint.streamDraw);
		this.vao = VAO.create();
		
		gl.bindBuffer(vbo.target, vbo.glName);
		vbo.initialize(cast(uint)(bufferSize * Vertex.sizeof));

		auto gShader = Shader(ShaderType.geometry, gs),
			 vShader = Shader(ShaderType.vertex,   vs),
			 fShader = Shader(ShaderType.fragment, fs);

		this.program = Program(allocator, gShader, vShader, fShader);

		gShader.destroy();
		vShader.destroy();
		fShader.destroy();

		gl.bindVertexArray(vao.glName);
		vao.bindAttributesOfType!Vertex(program);
	}

	void addItem(TextureID id, ref Vertex vertex)
	{
		if(elements == bufferSize)
			resize();

		if(active.texID != id)
		{
			active = TextureToRender(id, 0);
			toRender ~= active;
		}


		toRender[$ - 1].count++;

		elements++;

		*(bufferPtr++) = vertex;
	}

	void addItems(Range)(TextureID id, ref Range vertices)
	{
		if(vertices.length + elements >= bufferSize)
			resize();

		if(active.texID != id)
			toRender ~= TextureToRender(id, 0);

		elements += vertices.length;
		toRender[$ - 1].count += vertices.length;

		foreach(ref vertex; vertices)
			*(bufferPtr++) = vertex;	
	}


	//A resize is a tricky thing in glLand.
	void resize()
	{	
		gl.bindBuffer(vbo.target, vbo.glName);
		vbo.unmapBuffer();

		VBO tmp = VBO.create(vbo.hint);
		
		bufferSize *= 2;
		gl.bindBuffer(tmp.target, tmp.glName);
		tmp.initialize(bufferSize * Vertex.sizeof);
		
		
		gl.bindBuffer(BufferTarget.read, vbo.glName);
		gl.copyBufferSubData(BufferTarget.read, tmp.target, 0, 0, elements * Vertex.sizeof);

		gl.bindBuffer(vbo.target, 0);
		vbo.obliterate();

		vbo = tmp;

		gl.bindBuffer(vbo.target, vbo.glName);
		gl.bindVertexArray(vao.glName);
		vao.bindAttributesOfType!Vertex(program);

		//Need to remap buffer.

		bufferPtr = vbo.mapRange!Vertex(elements, bufferSize - elements, BufferRangeAccess.write);

		logChnl.warn("Performance Warning! The vbo got resized, consider making a bigger buffer.");
	}


	/** Starts a render cycle. This must be called before any calls to 
	*   addItem(s). And must be matched with a call to end.
	*/
	void start()
	{
		gl.bindBuffer(vbo.target, vbo.glName);
		bufferPtr = vbo.mapBuffer!Vertex(BufferAccess.write);
	}

	/** Draws all elements that has thus far been added for rendering immediatly.
	*   This is usefull if it is required to render to a render target.
	*   If a program is specified the rendering happens through that
	*   program.
	*/
	void draw(ref mat4 transform, Program* program = null)
	{
		draw_impl(transform, program);
		start();
	}


	/** Draws everything that has been added for rending. 
	*   If a program is specified the rendering happens through that
	*   program.
	*/
	void end(ref mat4 transform, Program* program = null)
	{
		draw_impl(transform, program);
	}

	private void draw_impl(ref mat4 transform, Program* program)
	{
		if(elements == 0) return;

		program = program == null ? &this.program : program;

		gl.bindBuffer(vbo.target, vbo.glName);
		vbo.unmapBuffer();

		program.uniform["transform"] = transform;

		gl.activeTexture(TextureUnit.zero);
		gl.bindVertexArray(vao.glName);

		uint offset = 0;
		foreach(ref render ; toRender)
		{
			auto texture = render.texID.texture;
			gl.bindTexture(texture.target, texture.glName);

			gl.drawArrays(PrimitiveType.points, offset, render.count);

			offset += render.count;
		}

		elements = 0;
		toRender.clear();
		active = TextureToRender();
	}

	@disable this(this);
}

void addFrame(ref Renderer renderer,
			  ref Frame frame,
			  float2 pos,
			  Color color,
			  float2 scale = float2(1,1),
			  float2 origin = float2(0,0),
			  float rotation = 0,
			  bool mirror = false)
{

	float4 coords = frame.coords;
	if(mirror) {
		swap(coords.x, coords.z);
	}

	float2 dim = float2(frame.srcRect.z * scale.x, frame.srcRect.w * scale.y);
	auto vertex = Vertex(float4(pos.x, pos.y, dim.x, dim.y),
								coords,
								origin,
								color,
								rotation);

	renderer.addItem(frame.texture, vertex);
}


uint addText(T,Sink)(FontID fontID,
					  const (T)[] text, 
					  float2 pos,
					  Color color,
					  float2 scale,
					  float2 origin, 
					  float rotation,
					  ref Sink sink)
{
	auto font  = fontID.font;

	CharInfo spaceInfo = font[' '];


	import std.math;
	float f = sin(rotation), 
		  g = cos(rotation);


	uint count = 0;
	float2 cursor = float2(0,0);
	foreach(dchar c; text)
	{
		if(c == ' ') 
		{
			cursor.x += spaceInfo.advance * scale.x;
			continue;
		}  
		else if(c == '\n') 
		{
			cursor.y -= font.lineHeight * scale.y;
			cursor.x = -origin.x * scale.x;
			continue;
		} 
		else if(c == '\t') 
		{
			cursor.x += spaceInfo.advance * font.tabSpaceCount * scale.x;
			continue;
		}

		CharInfo info = font[c];

		float2 tmp = float2(info.offset.x * scale.x, 
							info.offset.y * scale.y);
		float2 calc;
		calc.x = tmp.x * g - tmp.y * f;
		calc.y = tmp.x * f + tmp.y * g;

		float4 ppos = float4(pos.x + calc.x,
							 pos.y + calc.y,
							 scale.x * info.srcRect.z, 
							 scale.y * info.srcRect.w);
		
		sink.put(Vertex(ppos, info.textureCoords, 
						float2(-origin.x - cursor.x, -origin.y - cursor.y + font.base),
					    color, rotation));
		count++;
		cursor.x += info.advance * scale.x;
	}
	
	return count;
}

void addText(ref Renderer renderer,
			 FontID fontID,
			 const (char)[] text, 
			 float2 pos,
			 Color color = Color.white,
			 float2 scale = float2(1,1),
			 float2 origin = float2(0,0), 
			 float rotation = 0)
{
	struct RenderRange
	{
		Renderer* renderer;
		void put(Vertex vertex)
		{
			*(renderer.bufferPtr++) = vertex;
		}
	}

	auto font  = fontID.font;
	auto texID = font.page.texture; 	
	
	if(renderer.elements + text.length >= 
	   renderer.bufferSize)
		renderer.resize();

	if(renderer.active.texID != texID)
	{
		renderer.active = TextureToRender(texID, 0);
		renderer.toRender ~= renderer.active;
	}
	
	RenderRange range = RenderRange(&renderer); // <-- Must have a reference here.
	auto count = addText(fontID, text, pos, color, 
						 scale, origin, rotation, range);

	renderer.toRender[$ - 1].count += count;
	renderer.elements += count;
}

enum vs =
"#version 330
in vec4  pos;
in vec4  texCoord;
in vec4  color;
in vec2  origin;
in float rotation;

out vertexAttrib
{ 
vec4        pos;
vec4  texCoord;
vec4  color;
vec2  origin;
float rotation;
} vertex;

void main() 
{
	vertex.pos  = pos + vec4(0, 0, 0,0);
        vertex.texCoord = texCoord;
        vertex.color         = color;
        vertex.origin   = origin;
        vertex.rotation = rotation;
}
	";

	enum gs =
		"#version 330
		layout(points) in;
		layout(triangle_strip, max_vertices = 4) out;

		in vertexAttrib
		{
        vec4 pos;
        vec4 texCoord;
        vec4 color;
        vec2 origin;
        float rotation;
		} vertex[];

		out vertData 
		{
        vec4 color;
        vec2 texCoord;
		} vertOut;

		uniform mat4 transform;

		vec4 calcPos(in vec2 pos, in vec2 origin, in float sinus, in float cosinus)
		{
        pos.x += origin.x * cosinus - origin.y * sinus;
        pos.y += origin.x * sinus   + origin.y * cosinus;
        return vec4(pos, 0 , 1);
		}

		void emitCorner(in vec2 pos, in vec2 origin, in vec2 coord, in float sinus, in float cosinus)
		{
        gl_Position      = transform * calcPos(pos, origin, sinus, cosinus);
        vertOut.color    = vertex[0].color;
        vertOut.texCoord = coord;
        EmitVertex();
}

	void main()
		{
        float sinus   = sin(vertex[0].rotation),
		cosinus = cos(vertex[0].rotation);

        vec4 pos      =  vertex[0].pos;
        vec4 texCoord =  vertex[0].texCoord;
        vec2 origin   = -vertex[0].origin;

        emitCorner(pos.xy, origin , texCoord.xy, sinus, cosinus);
        emitCorner(pos.xy, origin + vec2(0, pos.w), texCoord.xw, sinus, cosinus);
        emitCorner(pos.xy, origin + vec2(pos.z, 0), texCoord.zy, sinus, cosinus);
        emitCorner(pos.xy, origin + vec2(pos.z, pos.w) , texCoord.zw, sinus, cosinus);
}
	";

	enum fs =
		"#version 330
		in vertData {
        vec4 color;
        vec2 texCoord;
		} vertIn;

		out vec4 fragColor;

		uniform sampler2D sampler;

		void main()
		{
        fragColor = texture2D(sampler, vertIn.texCoord) * vertIn.color;
		}
		";