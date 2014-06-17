module graphics.particle.particle;

import graphics, math; 

struct Particle
{
	//68-bytes
	float4 coords;
	float2 center;
	float2 velocity;

	Color startColor;
	Color endColor;
	float2 startSize;
	float2 endSize;

	float rotationSpeed;
	float time;
	float lifeTime;
	float startAlpha;
	float endAlpha;
}

final class ParticleSystem
{
	enum PROJ_MAT = "projection_matrix";
	enum TEXTURE = "tex";
	enum CURRENT_TIME = "current";
	enum CUTOFF_THRESHOLD = "cutoff_threshold";

	private VBO vbo;
	private VAO vao;
	private Program program;
	private float currentTime = 0;
	private int drawCounter = 0;
	private Particle[] queue;

	TextureAtlas atlas;

	int firstActiveParticle;
	int firstNewParticle;
	int firstFreeParticle;
	int firstRetiredParticle;

	@property uint numActiveParticles()
	{
		if (firstActiveParticle <= firstFreeParticle)
			return firstFreeParticle - firstActiveParticle;
		else
			return (maxParticles - firstActiveParticle) + firstFreeParticle;
	}

	private int maxParticles()
	{
		return this.queue.length;
	}

	import allocation;
	//this(ref ScopeStack allocator, TextureAtlasID atlas, size_t bufferSize)
	//{
	//    this.queue	    = allocator.allocate!(Particle[])(bufferSize);
	//
	//    this.vbo = VBO.create(BufferHint.streamDraw);
	//    this.vao = VAO.create();
	//
	//    gl.bindBuffer(vbo.target, vbo.glName);
	//    vbo.initialize(cast(uint)(bufferSize * Particle.sizeof));
	//
	//    auto gShader = Shader(ShaderType.geometry, gs),
	//        vShader = Shader(ShaderType.vertex,   vs),
	//        fShader = Shader(ShaderType.fragment, fs);
	//
	//    this.program = Program(allocator, gShader, vShader, fShader);
	//
	//    gShader.destroy();
	//    vShader.destroy();
	//    fShader.destroy();
	//
	//    gl.bindVertexArray(vao.glName);
	//    vao.bindAttributesOfType!Particle(program);
	//}


	private void setupShaderProgram(ref mat4 projection)
	{
		gl.useProgram(program.glName);

		program.uniform[PROJ_MAT]		= projection;
		program.uniform[CURRENT_TIME]	= this.currentTime;
		program.uniform[TEXTURE]		= 0;
		program.uniform[CUTOFF_THRESHOLD] = 0.1f;
	}


	public void update(float delta)
	{
		currentTime += delta;

		retireActiveParticles();
		freeRetiredParticles();

		if (firstActiveParticle == firstFreeParticle)
			currentTime = 0;

		if (firstRetiredParticle == firstActiveParticle)
			drawCounter = 0;
	}

	private void retireActiveParticles()
	{
		while (firstActiveParticle != firstNewParticle)
		{
			// Is this particle old enough to retire?
			// We multiply the active particle index by four, because each
			// particle consists of a quad that is made up of four vertices.
			float particleAge = currentTime - queue[firstActiveParticle].time;

			if (particleAge < queue[firstActiveParticle].lifeTime)
				break;

			// Remember the time at which we retired this particle.
			queue[firstActiveParticle].time = drawCounter;

			// Move the particle from the active to the retired queue.
			firstActiveParticle = (firstActiveParticle + 1) % this.maxParticles;
		}
	}

	private void freeRetiredParticles()
	{
		while (firstRetiredParticle != firstActiveParticle)
			firstRetiredParticle = (firstRetiredParticle + 1) % this.maxParticles;
	}


	public void render(ref mat4 projection)
	{
		import std.stdio;

		gl.bindBuffer(vbo.target, vbo.glName);
		gl.useProgram(program.glName);

		this.addNewParticlesToVertexBuffer();
		this.setupShaderProgram(projection);

		gl.bindVertexArray(vao.glName);
		auto tex = atlas.texture.texture;
		gl.activeTexture(TextureUnit.zero);
		gl.bindTexture(tex.target, tex.glName);

		if (firstActiveParticle <= firstFreeParticle)
		{
			gl.drawArrays(PrimitiveType.points, 
						  firstActiveParticle, 
						  (firstFreeParticle - firstActiveParticle));
		}
		else
		{
			gl.drawArrays(PrimitiveType.points, 
						  firstActiveParticle,  
						  (maxParticles - firstActiveParticle));
			if (firstFreeParticle > 0)
			{	
				gl.drawArrays(PrimitiveType.points, 0, firstFreeParticle);
			}
		}

		drawCounter++;
	}


	void addNewParticlesToVertexBuffer()
	{
		if(firstNewParticle == firstFreeParticle) return;

		if (firstNewParticle < firstFreeParticle)
		{
			auto range0 = firstNewParticle, 
				range1 = (firstFreeParticle - firstNewParticle);
			vbo.bufferSubData(queue[range0 .. range0 + range1], range0);
		}
		else
		{
			auto range0 = firstNewParticle, 
				range1 = (this.maxParticles - firstNewParticle);
			vbo.bufferSubData(queue[range0 ..  range0 + range1], range0);

			if (firstFreeParticle > 0)
			{
				vbo.bufferSubData(queue[0 ..  firstFreeParticle], 0);
			}
		}

		firstNewParticle = firstFreeParticle;
	}

	public void addParticle(ref Particle particle)
	{
		int nextFreeParticle = (firstFreeParticle + 1) % this.maxParticles;

		if (nextFreeParticle == firstRetiredParticle)
			return;

		queue[firstFreeParticle] = particle;
		queue[firstFreeParticle].time = currentTime;

		firstFreeParticle = nextFreeParticle;
	}


	enum gs = 
		"
		#version 330
		layout(points) in;
		layout(triangle_strip, max_vertices = 4) out;

		uniform mat4 projection_matrix;

		uniform float start_alpha;
		uniform float end_alpha;
		uniform float current;

		in vertexAttrib
		{
		vec4 coords;
		vec2 center;
		vec2 velocity;

		vec4 startColor;
		vec4 endColor;
		vec2 startSize;
		vec2 endSize;

		float rotationSpeed;
		float time;
		float lifeTime;
		float startAlpha;
		float endAlpha;
		} vertex[];

		out vertData
		{
		vec4 color;
		vec2 coord;
		float alpha;
		} vertOut;

		vec4 calcPos(in vec2 pos, in vec2 origin, in float sinus, in float cosinus)
		{
		pos.x += origin.x * cosinus - origin.y * sinus;
		pos.y += origin.x * sinus   + origin.y * cosinus;
		return vec4(pos, 0 , 1);
}

void emitCorner(in vec2 pos, in vec2 origin, 
in vec2 coord, in float sinus, 
in float cosinus, in vec4 color, in float alpha)
{
	gl_Position      = projection_matrix * calcPos(pos, origin, sinus, cosinus);
		vertOut.color	 = color;
		vertOut.coord	 = coord;
		vertOut.alpha	 = alpha;
		EmitVertex();
}

void main(void)
{
	float age = clamp(0.0, 1.0, (current - vertex[0].time) / (vertex[0].lifeTime));

		vec2 pos	 = vertex[0].center;
		pos			+= vertex[0].velocity * age;
		float angle  = vertex[0].rotationSpeed * age;

		float s = sin(angle);
		float c = cos(angle);

		vec2 size	= mix(vertex[0].startSize, vertex[0].endSize, age);
		vec2 origin = -size / 2.0; 

		//OUT STUFF
		vec4 out_tint = mix(vertex[0].startColor, vertex[0].endColor, age);

		out_tint.rgb *= out_tint.a;

		float alpha = mix(vertex[0].startAlpha, vertex[0].endAlpha, age);

		emitCorner(pos, origin					, vertex[0].coords.xy, s, c, out_tint, alpha);
		emitCorner(pos, origin + vec2(0, size.y), vertex[0].coords.xw, s, c, out_tint, alpha);
		emitCorner(pos, origin + vec2(size.x, 0), vertex[0].coords.zy, s, c, out_tint, alpha);
		emitCorner(pos, origin + size			, vertex[0].coords.zw, s, c, out_tint, alpha);
}
";

enum vs =
"#version 330
in vec4 coords;
in vec2 center;
in vec2 velocity;

in vec4 startColor;
in vec4 endColor;
in vec2 startSize;
in vec2 endSize;

in float rotationSpeed;
in float time;
in float lifeTime;
in float startAlpha;
in float endAlpha;

out vertexAttrib
{
	vec4 coords;
		vec2 center;
		vec2 velocity;

		vec4 startColor;
		vec4 endColor;
		vec2 startSize;
		vec2 endSize;

		float rotationSpeed;
		float time;
		float lifeTime;
		float startAlpha;
		float endAlpha;
		} vertex;

		void main() 
		{
		vertex.coords		= coords;
		vertex.center		= center;
		vertex.velocity		= velocity;
		vertex.startColor	= startColor;
		vertex.endColor		= endColor;
		vertex.startSize	= startSize;
		vertex.endSize		= endSize;
		vertex.rotationSpeed= rotationSpeed;
		vertex.time			= time;
		vertex.lifeTime		= lifeTime;
		vertex.startAlpha	= startAlpha;
		vertex.endAlpha		= endAlpha;
}
";

enum fs =
"
#version 330
precision highp float;

in vertData
{
	vec4 color;
		vec2 coord;
		float alpha;
		} vertIn;


		out vec4 out_frag_color;
		uniform sampler2D tex;
		uniform float cutoff_threshold;

		void main(void)
		{
		vec4 sample = texture(tex, vertIn.coord);
		if(sample.a < cutoff_threshold) discard;

		out_frag_color = sample * vertIn.color * vertIn.alpha;
}
";
}