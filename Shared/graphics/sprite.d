module graphics.sprite;

import math;
import graphics;
import std.algorithm;
import std.exception;
import content.texture, 
	   content.font;

struct SpriteBuffer 
{
	private VBO vbo;
	private VAO vao;

	private static Program defaultProgram;
	private Program program;

	private Vertex[]    vertices;
	private Texture2D[] textures;

	private struct Vertex
	{
		float4 pos;
		float4 texCoord;
		float2 origin;
		Color  color;
		float  rotation;
	}

	private uint elements;


	this(Allocator)(uint size, ref Allocator allocator, BufferHint hint = BufferHint.streamDraw) 
	{
		size      = size;
		vbo       = VBO.create(hint);
		vao       = VAO();
		vertices  = allocator.allocate!(Vertex[])(size);
		textures  = allocator.allocate!(Texture2D[])(size);
		elements  = 0;

		gl.bindBuffer(vbo.target, vbo.glName);
		vbo.initialize(cast(uint)(size * Vertex.sizeof));


		auto gShader  = Shader(ShaderType.geometry, gs),
			vShader  = Shader(ShaderType.vertex,   vs),
			fShader  = Shader(ShaderType.fragment, fs);

		if(defaultProgram.glName == 0)
			defaultProgram = Program(allocator, gShader, vShader, fShader);

		program = defaultProgram;

		gl.useProgram(program.glName);
		program.uniform["sampler"] = 0;

		gShader.destroy();
		vShader.destroy();
		fShader.destroy();


		gl.bindVertexArray(vao.glName);
		vao.bindAttributesOfType!Vertex(program);
	}


	void addFrame(Frame frame, float4 rect,
			      Color color = Color.white,
				  float2 origin = float2.zero,
				  float rotation = 0,
				  bool mirror = false)
	{
		enforce(elements < vertices.length, "SpriteBuffer full");

		float4 coords = frame.coords;
		if(mirror) {
			swap(coords.x, coords.z);
		}

		vertices[elements] = Vertex(rect,
									coords,
									origin,
									color,
									rotation);

		textures[elements++] = TextureManager.lookup(frame.texture);
	}

	void addFrame(Frame frame,
				  float4 rect,
				  float4 bounds,
				  Color color = Color.white,
				  float2 origin = float2.zero,
				  float rotation = 0,
				  bool mirror = false)
	{
		enforce(elements < vertices.length, "SpriteBuffer full");

		float4 coords = frame.coords;
		if(mirror) {
			swap(coords.x, coords.z);
		}

		if(clampPosAndCoords(bounds, rect, coords)) {
			vertices[elements] = Vertex(rect,
										coords,
										origin,
										color,
										rotation);

			textures[elements++] = TextureManager.lookup(frame.texture);
		}
	}

	void addFrame(Frame frame, 
				  float2 pos,
				  Color color = Color.white,
				  float2 scale = float2(1,1),
				  float2 origin = float2(0,0), 
				  float rotation = 0,
				  bool mirror = false)
	{
		enforce(elements < vertices.length, "SpriteBuffer full");

		float4 coords = frame.coords;
		if(mirror) {
			swap(coords.x, coords.z);
		}

		float2 dim = float2(frame.srcRect.z * scale.x, frame.srcRect.w * scale.y);
		vertices[elements] = Vertex(float4(pos.x, pos.y, dim.x, dim.y),
									coords,
									origin,
									color,
									rotation);

		textures[elements++] = TextureManager.lookup(frame.texture);
	}

	void addText(T)(FontID fontID,
					const (T)[] text, 
					float2 pos,
					Color color = Color.white,
					float2 scale = float2(1,1),
					float2 origin = float2(0,0), 
					float rotation = 0)
		if(is(T == char) || is(T == wchar) || is(T == dchar))
		{
			enforce(elements + text.length < vertices.length, "SpriteBuffer full");

			Font font = FontManager.lookup(fontID);
			textures[elements .. elements + text.length] = TextureManager.lookup(font.page.texture);

			float2 cursor = float2(0,0);
			foreach(wchar c; text)
			{
				if(c == ' ') {
					CharInfo spaceInfo = font[' '];
					cursor.x += spaceInfo.advance * scale.x;
					continue;
				}        else if(c == '\n') {
					cursor.y -= font.lineHeight * scale.y;
					cursor.x = -origin.x * scale.x;
					continue;
				} else if(c == '\t') {
					CharInfo spaceInfo = font[' '];
					cursor.x += spaceInfo.advance * font.tabSpaceCount * scale.x;
					continue;
				}

				CharInfo info = font[c];
				float4 ppos = float4(pos.x + info.offset.x * scale.x,
									 pos.y + info.offset.y * scale.y,
									 scale.x * info.srcRect.z, 
									 scale.y * info.srcRect.w);

				vertices[elements++] = Vertex(ppos, 
											  info.textureCoords,
											  float2(-origin.x - cursor.x,
													 -origin.y - cursor.y ),
											  color,
											  rotation);

				cursor.x += info.advance * scale.x;
			}
		}

	void addText(T)(FontID fontID,
					const (T)[] text, 
					float2 pos,
					float4 scissor,
					Color color = Color.white)
		if(is(T == char) || is(T == wchar) || is(T == dchar))
		{
			enforce(elements + text.length < vertices.length, "SpriteBuffer full");

			Font font = FontManager.lookup(fontID);
			Texture2D page = TextureManager.lookup(font.page.texture);

			float2 cursor = float2(0,0);
			foreach(wchar c; text)
			{
				if(c == ' ') {
					CharInfo spaceInfo = font[' '];
					cursor.x += spaceInfo.advance;
					continue;
				}        else if(c == '\n') {
					cursor.y -= font.lineHeight;
					cursor.x = 0;
					continue;
				} else if(c == '\t') {
					CharInfo spaceInfo = font[' '];
					cursor.x += spaceInfo.advance * font.tabSpaceCount;
					continue;
				}

				CharInfo info = font[c];
				float4 ppos = float4(pos.x + info.offset.x + cursor.x,
									 pos.y + info.offset.y + cursor.y,
									 info.srcRect.z, 
									 info.srcRect.w);
				float4 coords = info.textureCoords;
				cursor.x += info.advance;



				if(clampPosAndCoords(scissor, ppos, coords)) {
					vertices[elements] = Vertex(ppos, 
												coords,
												float2.zero,
												color,
												0);

					textures[elements++] = page;
				}
			}
			return this;
		}


	private bool clampPosAndCoords(float4 bounds, ref float4 pos, ref float4 coords)
	{
		if(bounds.x + bounds.z < pos.x || 
		   bounds.y + bounds.w < pos.y || 
		   pos.x + pos.z < bounds.x    ||
		   pos.y + pos.w < bounds.y)
			return false;

		if(bounds.x + bounds.z < pos.x + pos.z) 
		{
			float old = pos.z;
			pos.z = (bounds.x + bounds.z) - pos.x;
			coords.z = (coords.z - coords.x) * (pos.z / old) + coords.x;
		} 

		if(bounds.x > pos.x) 
		{
			float old = pos.z;
			pos.z -= bounds.x - pos.x;
			pos.x  = bounds.x;

			float s = (old - pos.z) / old; 
			coords.x += (coords.z - coords.x) * s;
		}

		if(bounds.y + bounds.w < pos.y + pos.w) 
		{
			float old = pos.w;
			pos.w =    (bounds.y + bounds.w) - pos.y;
			coords.w = (coords.w - coords.y) * (pos.w / old) + coords.y;
		} 

		if(bounds.y > pos.y) 
		{
			float old = pos.w;
			pos.w -= bounds.y - pos.y;
			pos.y  = bounds.y;

			float s = (old - pos.w) / old; 
			coords.y += (coords.w - coords.y) * s;
		}

		return pos.w > 0 && pos.z > 0;
	}

	void draw(ref mat4 transform)
	{
		if(elements == 0) return;
		
		gl.bindBuffer(vbo.target, vbo.glName);
		vbo.bufferSubData(vertices[0 .. elements], 0);

		gl.bindVertexArray(vao.glName);
		gl.useProgram(program.glName);

		program.uniform["transform"] = transform;
		Texture2D texture = textures[0];

		uint count = 1;
		uint offset = 0;
		foreach(i; 1 .. elements)
		{
			if(textures[i] != texture)         {
				gl.activeTexture(TextureUnit.zero);
				gl.bindTexture(texture.target, texture.glName);

				gl.drawArrays(PrimitiveType.points, offset, count);
				count = 1; offset = i;
				texture = textures[i];
				continue;
			}
			count++;
		}

		gl.activeTexture(TextureUnit.zero);
		gl.bindTexture(textures[elements - 1].target, texture.glName);

		gl.drawArrays(PrimitiveType.points, offset, count);

		this.elements = 0;
	}

	@disable this(this);
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