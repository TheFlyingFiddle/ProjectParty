module rendering.combined;

import graphics;
import rendering.renderer;
import math.vector;

struct Renderer2D
{
    private Renderer!(DistVertex) _renderer;

    this(A)(ref A allocator, RenderConfig config)
    {
        _renderer = Renderer!(DistVertex)(allocator, config, vertexShader, fragmentShader);
    }

    void addItems(Vertex[] vertices, uint[] indecies, ref Texture2D texture)
    {
        import std.c.stdlib;

        auto len = vertices.length;
        auto distVertex = cast(DistVertex*)alloca(DistVertex.sizeof * len);
        foreach(i; 0 .. len)
        {
            distVertex[i].position = vertices[i].position;
            distVertex[i].coords = vertices[i].coords;
            distVertex[i].thresholds = float3.zero;
            distVertex[i].color  = vertices[i].color;
        }

        _renderer.addItems(distVertex[0 .. len], indecies, texture);
    }

    void addItems(DistVertex[] vertices, uint[] indecies, ref Texture2D texture)
    {
        _renderer.addItems(vertices, indecies, texture);
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


private enum vertexShader = q{
	#version 330
	in vec2 position;
	in vec2 coords;
	in vec3 thresholds;
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
		vertOut.thresholds = thresholds;
		vertOut.color  = color;
		vertOut.coords = coords;
		gl_Position    = vec4(position * invViewport * 2 - vec2(1, 1), 0.0, 1.0);
	}
};

private enum fragmentShader = q{
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