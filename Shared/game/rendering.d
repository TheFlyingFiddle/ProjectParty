module game.rendering;

import graphics, 
	   content.texture, 
	   content.font,
	   math, 
	   collections.list,
	   logging;

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

	private TextureID texture;


	private uint elements;
	private uint offset;
	private uint bufferSize;

	private Vertex* bufferPtr, basePtr;

	mat4 transform;
	Program* usedProgram;

	this(A)(ref A allocator, size_t bufferSize)
	{
		this.elements = 0;
		this.bufferSize = bufferSize;

		this.vbo = VBO.create(BufferHint.streamDraw);
		this.vao = VAO.create();
		
		vbo.bind();
		vbo.initialize(cast(uint)(bufferSize * Vertex.sizeof));

		auto gShader = Shader(ShaderType.geometry, gs),
			 vShader = Shader(ShaderType.vertex,   vs),
			 fShader = Shader(ShaderType.fragment, fs);

		this.program = Program(allocator, gShader, vShader, fShader);

		gShader.destroy();
		vShader.destroy();
		fShader.destroy();

		vao.bind();
		vao.bindAttributesOfType!Vertex(program);

		texture = TextureID.invalid;
	}

	~this()
	{
		program.obliterate();
		vbo.obliterate();
		vao.obliterate();
	}

	void addItem(TextureID id, Vertex vertex)
	{
		addItem(id, vertex);
	}

	void addItem(TextureID id, ref Vertex vertex)
	{
		if(texture != id) {
			if(texture == TextureID.invalid)
				texture = id;
			else 
			{
				draw();
				texture = id;
			}
		} 

		if(elements == bufferSize)
		{
			draw();
			elements = 0;
			offset = 0;
		}

		elements++;
		*(bufferPtr++) = vertex;
	}

	void addItem(uint index, TextureID id, ref Vertex vertex)
	{
		texture = id;
		elements++;
		basePtr[index] = vertex;
	}


	void addItems(Range)(TextureID id, ref Range vertices)
	{
		if(texture != id) {
			if(texture == TextureID.invalid)
				texture = id;
			else 
			{
				draw();
				texture = id;
			}
		} 

		if(elements + vertices.length >= bufferSize)
		{
			draw_impl();
			elements = 0;
			offset = 0;
			start(this.transform, this.usedProgram);
		}

		elements += vertices.length;
		toRender[$ - 1].count += vertices.length;

		foreach(ref vertex; vertices)
			*(bufferPtr++) = vertex;	
	}


	/** Starts a render cycle. This must be called before any calls to 
	*   addItem(s). And must be matched with a call to end.
	*/
	void start(ref mat4 transform, Program* program = null)
	{
		usedProgram = program == null ? &this.program : program;
		this.transform = transform;

		vbo.bind();
		if(elements == bufferSize)
		{
			elements = 0;
			offset   = 0;
		}

		bufferPtr = vbo.mapRange!Vertex(elements, bufferSize - elements, BufferRangeAccess.unsynchronizedWrite);
		basePtr = bufferPtr;
	}

	/** Draws all elements that has thus far been added for rendering immediatly.
	*   This is usefull if it is required to render to a render target.
	*   If a program is specified the rendering happens through that
	*   program.
	*/
	void draw()
	{
		draw_impl();
		start(transform, usedProgram);
	}


	/** Draws everything that has been added for rending. 
	*   If a program is specified the rendering happens through that
	*   program.
	*/
	void end()
	{
		draw_impl();
		texture = TextureID.invalid;
	}

	private void draw_impl()
	{
		import logging;

		vbo.bind();
		vbo.unmapBuffer();

		if(elements == offset) return;

		
		gl.useProgram(usedProgram.glName);
		context.program = usedProgram.glName;
		usedProgram.uniform["transform"] = transform;

		vao.bind();
		auto tex = texture.texture;

		context[TextureUnit.zero] = tex;
		gl.drawArrays(PrimitiveType.points, offset, elements - offset);

		if(bufferSize - elements < 0xFFFF)
			elements = 0;

		offset = elements;
	}

	@disable this(this);
}

void addFrame(Renderer* renderer,
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
								origin * scale,
								color,
								rotation);

	renderer.addItem(frame.texture, vertex);
}


void addFrame(Renderer* renderer,
				  uint index,
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
								origin * scale,
								color,
								rotation);

	renderer.addItem(index, frame.texture, vertex);
}



void addFrame(Renderer* renderer,
			  Frame frame, float4 rect,
			  Color color = Color.white,
			  float2 origin = float2.zero,
			  float rotation = 0,
			  bool mirror = false)
{
	float4 coords = frame.coords;
	if(mirror) {
		swap(coords.x, coords.z);
	}

	renderer.addItem(frame.texture, 
					 Vertex(rect, coords, origin, color, rotation));
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
	origin = float2(-origin.x * scale.x, -origin.y * scale.y);
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
						float2(-origin.x - cursor.x, 
							   -origin.y - cursor.y + font.base * scale.y),
					    color, rotation));
		count++;
		cursor.x += info.advance * scale.x;
	}
	
	return count;
}

void addText(Renderer* renderer,
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
	

	if(renderer.texture != texID) {
		if(renderer.texture == TextureID.invalid)
			renderer.texture = texID;
		else 
		{
			renderer.draw();
			renderer.texture = texID;
		}
	} 

	if(renderer.elements + text.length >= renderer.bufferSize)
	{
		renderer.draw_impl();
		renderer.elements = 0;
		renderer.offset = 0;
		renderer.start(renderer.transform, renderer.usedProgram);
	}


	RenderRange range = RenderRange(renderer); // <-- Must have a reference here.
	auto count = addText(fontID, text, pos, color, 
						 scale, origin, rotation, range);

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