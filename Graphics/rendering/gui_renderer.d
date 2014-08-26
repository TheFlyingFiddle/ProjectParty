module rendering.gui_renderer;

import graphics;
import rendering.renderer;
import math.vector;

struct GuiVertex
{
	float2 position;
	float2 coords;
	float3 thresh;
	@Normalized Color color;
}

struct GuiRenderer
{
	private Renderer!(GuiVertex) _renderer;

	this(A)(ref A allocator, RenderConfig config)
	{
		_renderer = Renderer!(GuiVertex)(allocator, config, guiVert, guiFrag);
	}

	void addItems(Vertex[] vertices, uint[] indecies, ref Texture2D texture)
	{
		import std.c.stdlib;

		auto len = vertices.length;
		auto guiVertices = cast(GuiVertex*)alloca(GuiVertex.sizeof * len);
		foreach(i; 0 .. len)
		{
			guiVertices[i].position = vertices[i].position;
			guiVertices[i].coords = vertices[i].coords;
			guiVertices[i].thresh = float3.zero;
			guiVertices[i].color  = vertices[i].color;
		}

		_renderer.addItems(guiVertices[0 .. len], indecies, texture);
	}

	void addItems(DistVertex[] vertices, uint[] indecies, ref Texture2D texture)
	{
		import std.c.stdlib;

		auto len = vertices.length;
		auto guiVertices = cast(GuiVertex*)alloca(GuiVertex.sizeof * len);
		foreach(i; 0 .. len)
		{
			guiVertices[i].position	  = vertices[i].position;
			guiVertices[i].coords = vertices[i].coords;
			guiVertices[i].thresh = vertices[i].thresholds;
			guiVertices[i].color  = vertices[i].color;
		}

		_renderer.addItems(guiVertices[0 .. len], indecies, texture);
	}

	void viewport(float2 viewport)
	{
		_renderer.viewport(viewport);
	}

	void begin()
	{
		_renderer.begin();
	}

	void end() 
	{
		_renderer.end();
	}
}

enum guiVert = q{
	#version 330
	in vec2 position;
	in vec2 coords;
	in vec3 thresh;
	in vec4 color;

	uniform vec2 invViewport;

	out vertAttrib 
	{
		vec2 coords;
		vec3 thresholds;
		vec4 color;
	} vertOut;

	void main()
	{
		vertOut.thresholds = thresh;
		vertOut.color  = color;
		vertOut.coords = coords;
		gl_Position    = vec4(position * invViewport * 2 - vec2(1, 1), 0.0, 1.0);
	}
};

enum guiFrag = q{
	#version 330
	uniform sampler2D sampler;
	in vertAttrib 
	{
		vec2 coords;
		vec3 thresholds;
		vec4 color;
	} vertIn;

	out vec4 fragColor;

	void main()
	{
		vec4 color = texture2D(sampler, vertIn.coords);
		if(vertIn.thresholds.z != 0.0f)
		{
			float sample = color[int(vertIn.thresholds.x)];
			if(sample < vertIn.thresholds.y) discard;

			fragColor = vertIn.color;
			fragColor.a = smoothstep(vertIn.thresholds.y, vertIn.thresholds.z, sample);
		} 
		else 
		{
			if(color.a < 0.1) discard; 
			fragColor = color * vertIn.color;
		}
	}
};