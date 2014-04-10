module particle;

import graphics, game, content, math, content.sdl, allocation;
import std.stdio;

class ParticleState : IGameState
{
	ParticleSystem system;
	
	this(A)(ref A allocator)
	{
		auto settings = fromSDLFile!ParticleSettings(GC.it, "ParticleSettings.sdl");
		system = ParticleSystem(allocator, settings, 1000);
	}

	void enter() 
	{
	}

	void exit() 
	{
	}

	void update()
	{
		if(Keyboard.isDown(Key.enter)){
			system.settings = fromSDLFile!ParticleSettings(GC.it, "ParticleSettings.sdl");
		}

		import std.random;

		float4 rect		= float4(0,0,1,1);
		float2 pos		= float2(Game.window.size / 2);
		auto polar	    = float2(0,300).toPolar();
		polar.angle		+= uniform(-1.0f,1.0f);

		float2 size		= float2(2, 2);

		system.AddParticle(pos, polar.toCartesian, size, rect);

		foreach(i; 0 .. 4)
		{
			auto pos2 = pos + Polar!float(Time.total + 0.5f * i, 200f).toCartesian;
			auto velo = pos2 - pos;
			system.AddParticle(pos2, velo, size, rect);
		}

		system.Update(Time.delta);
	}

	void render()
	{
		gl.clear(ClearFlags.color);

		mat4 proj = mat4.CreateOrthographic(0, Game.window.fboSize.x, Game.window.fboSize.y, 0, 1, -1);
		system.Render(proj, Game.content.loadTexture("particle.png"));
	}
}

struct ParticleSettings
{
	@Convert!toColor() Color startColor;
	@Convert!toColor() Color endColor;
	@Convert!toColor() Color colorVariance;
	float startSize;
	float endSize;
	float startAngularVelocity;
	float endAngularVelocity;
	float lifeTime;
	float sizeVariance;
}

Color toColor(uint i) { return Color(i); }

struct ParticleSystem
{
	enum ELEMENTS_PER_SQUARE = 6;
	enum PROJ_MAT = "projection_matrix";
	enum FORCES = "forces";
	enum START_COLOR = "start_color";
	enum END_COLOR = "end_color";
	enum START_ALPHA = "start_alpha";
	enum END_ALPHA = "end_alpha";
	enum START_SIZE = "start_size";
	enum END_SIZE = "end_size";
	enum SIZE_VARIANCE = "size_variance";
	enum LIFE_TIME = "life_time";
	enum CURRENT_TIME = "current";
	enum COLOR_VARIANCE = "color_variance";
	enum START_ANGULAR_VELOCITY = "start_angular_velocity";
	enum END_ANGULAR_VELOCITY = "end_angular_velocity";
	enum IN_POS  = "in_position";
	enum IN_VEL = "in_velocity";
	enum IN_RANDOM = "in_random";
	enum IN_TIME = "in_time";
	enum IN_COORDS = "in_coords";
	enum IN_OFFSET = "in_offset";
	enum TEXTURE = "tex";

	private VBO vbo;
	private VAO vao;
	private IBO ibo;

	private Program program;

	private float currentTime = 0;
	private float lifeTime    = 3;
	private int drawCounter = 0;
	private Vertex[] queue;

	ParticleSettings settings;


	int firstActiveParticle;
	int firstNewParticle;
	int firstFreeParticle;
	int firstRetiredParticle;

	private int MaxParticles()
	{
		return this.queue.length / 4;
	}

	private struct Vertex
    {
        float2 position;
		float2 velocity;
		float2 random;
		float2 offset;
		float2 coords;
		float time;
    }

	import allocation;
	this(ref ScopeStack allocator, ParticleSettings settings, size_t bufferSize)
	{
		this.settings   = settings;
		this.queue	    = allocator.allocate!(Vertex[])(bufferSize * 4);

		this.vbo = VBO.create(BufferHint.streamDraw);
		this.vao = VAO.create();
		this.ibo = IBO.create(BufferHint.staticDraw);
			

		gl.bindBuffer(ibo.target, ibo.glName);
		ibo.initialize(cast(uint)(6 * bufferSize * ushort.sizeof));
		bufferIndices(cast(ushort)(6 * bufferSize));

		gl.bindBuffer(vbo.target, vbo.glName);
		vbo.initialize(cast(uint)(4 * bufferSize * Vertex.sizeof));

		auto vShader = Shader(ShaderType.vertex,   vs),
			 fShader = Shader(ShaderType.fragment, fs);

		this.program = Program(allocator, vShader, fShader);

		vShader.destroy();
		fShader.destroy();

		gl.bindVertexArray(vao.glName);
		vao.bindAttributesOfType!Vertex(program);
	}

	private void bufferIndices(ushort bufferSize)
	{
		auto ptr = ibo.mapRange!ushort(0, bufferSize, BufferRangeAccess.write);
		foreach(ushort i; 0 .. bufferSize / 6)
		{
			(*ptr++)  = cast(ushort)(i * 4);
			(*ptr++)  = cast(ushort)(i * 4 + 1);
			(*ptr++)  = cast(ushort)(i * 4 + 2);
			(*ptr++)  = cast(ushort)(i * 4);
			(*ptr++)  = cast(ushort)(i * 4 + 2);
			(*ptr++)  = cast(ushort)(i * 4 + 3);
		}

		ibo.unmapBuffer();
	}


	private void setupShaderProgram(ref mat4 projection)
	{
		gl.useProgram(program.glName);
		
		program.uniform[PROJ_MAT]	 = projection;
		program.uniform[START_COLOR] = settings.startColor;
		program.uniform[END_COLOR]   = settings.endColor;
		program.uniform[START_SIZE]  = settings.startSize;
		program.uniform[END_SIZE]    = settings.endSize;

		program.uniform[START_ANGULAR_VELOCITY] = settings.startAngularVelocity;
		program.uniform[END_ANGULAR_VELOCITY]   = settings.endAngularVelocity;
		program.uniform[COLOR_VARIANCE]			= settings.colorVariance;
		program.uniform[SIZE_VARIANCE]			= settings.sizeVariance;
		program.uniform[LIFE_TIME]				= settings.lifeTime;
		program.uniform[CURRENT_TIME]			= this.currentTime;
		program.uniform[START_ALPHA]			= 1.0f;
		program.uniform[END_ALPHA]				= 0.0f;
		program.uniform[TEXTURE]				= 0;
	}


	public void Update(float delta)
	{
		currentTime += delta;

		RetireActiveParticles();
		FreeRetiredParticles();

		if (firstActiveParticle == firstFreeParticle)
			currentTime = 0;

		if (firstRetiredParticle == firstActiveParticle)
			drawCounter = 0;
	}

	private void RetireActiveParticles()
	{
		while (firstActiveParticle != firstNewParticle)
		{
			// Is this particle old enough to retire?
			// We multiply the active particle index by four, because each
			// particle consists of a quad that is made up of four vertices.
			float particleAge = currentTime - queue[firstActiveParticle * 4].time;

			if (particleAge < lifeTime)
				break;

			// Remember the time at which we retired this particle.
			queue[firstActiveParticle * 4].time = drawCounter;

			// Move the particle from the active to the retired queue.
			firstActiveParticle = (firstActiveParticle + 1) % this.MaxParticles;
		}
	}

	private void FreeRetiredParticles()
	{
		while (firstRetiredParticle != firstActiveParticle)
		{
			// Has this particle been unused long enough that
			// the GPU is sure to be finished with it?
			// We multiply the retired particle index by four, because each
			// particle consists of a quad that is made up of four vertices.
			int age = drawCounter - cast(int)queue[firstRetiredParticle * 4].time;

			// The GPU is never supposed to get more than 2 frames behind the CPU.
			// We add 1 to that, just to be safe in case of buggy drivers that
			// might bend the rules and let the GPU get further behind.
			if (age < 3)
				break;

			// Move the particle from the retired to the free queue.
			firstRetiredParticle = (firstRetiredParticle + 1) % this.MaxParticles;
		}
	}


	public void Render(ref mat4 projection, TextureID texture)
	{
		import std.stdio;

		gl.bindBuffer(vbo.target, vbo.glName);
		gl.bindBuffer(ibo.target, ibo.glName);
		gl.useProgram(program.glName);

		this.AddNewParticlesToVertexBuffer();
		this.setupShaderProgram(projection);

		gl.bindVertexArray(vao.glName);
		auto tex = texture.texture;
		gl.activeTexture(TextureUnit.zero);
		gl.bindTexture(tex.target, tex.glName);

		if (firstActiveParticle < firstFreeParticle)
		{
			gl.drawElements(PrimitiveType.triangles, 
						   (firstFreeParticle - firstActiveParticle) * ELEMENTS_PER_SQUARE, 
							IndexBufferType.ushort_,
							cast(size_t*)(firstActiveParticle * ELEMENTS_PER_SQUARE * ushort.sizeof));

		}
		else
		{
			gl.drawElements(PrimitiveType.triangles, 
								 (MaxParticles - firstActiveParticle) * ELEMENTS_PER_SQUARE, 
								 IndexBufferType.ushort_,
								 cast(size_t*)(firstActiveParticle * ELEMENTS_PER_SQUARE * ushort.sizeof));


			if (firstFreeParticle > 0)
			{
				gl.drawElements(PrimitiveType.triangles, 
								firstFreeParticle * 6, 
								IndexBufferType.ushort_, cast(size_t*)(0));
			}
		}

		drawCounter++;
	}


	void AddNewParticlesToVertexBuffer()
	{

		if (firstNewParticle < firstFreeParticle)
		{
			auto range0 = firstNewParticle * 4, range1 = (firstFreeParticle - firstNewParticle) * 4;
			vbo.bufferSubData(queue[range0 .. range0 + range1], range0);
		}
		else
		{
			auto range0 = firstNewParticle * 4, range1 = (this.MaxParticles - firstNewParticle) * 4;
			vbo.bufferSubData(queue[range0 ..  range0 + range1],range0);

			if (firstFreeParticle > 0)
			{
				vbo.bufferSubData(queue[0 ..  firstFreeParticle * 4], 0);
			}
		}

		firstNewParticle = firstFreeParticle;
	}

	public void AddParticle(float2 position, float2 velocity, float2 size, float4 coords)
	{
		int nextFreeParticle = (firstFreeParticle + 1) % this.MaxParticles;

		if (nextFreeParticle == firstRetiredParticle)
			return;


		queue[firstFreeParticle * 4 + 0].coords	= float2(coords.x, coords.y);
		queue[firstFreeParticle * 4 + 1].coords = float2(coords.z, coords.y);
		queue[firstFreeParticle * 4 + 2].coords = float2(coords.z, coords.w);
		queue[firstFreeParticle * 4 + 3].coords = float2(coords.x, coords.w);

		queue[firstFreeParticle * 4 + 0].offset = -size / 2;
		queue[firstFreeParticle * 4 + 1].offset = float2(size.x / 2, -size.y / 2);
		queue[firstFreeParticle * 4 + 2].offset = size / 2;
		queue[firstFreeParticle * 4 + 3].offset = float2(-size.x / 2, size.y / 2); ;

		import std.random;

		auto rand = float2(uniform(-1, 1.0001), uniform(-1, 1.0001));
		for (int i = 0; i < 4; i++)
		{
			queue[firstFreeParticle * 4 + i].position = float2(position.x, position.y);
			queue[firstFreeParticle * 4 + i].velocity = velocity;
			queue[firstFreeParticle * 4 + i].time = currentTime;
			queue[firstFreeParticle * 4 + i].random = rand;

		}

		firstFreeParticle = nextFreeParticle;
	}

	enum vs = 
"
#version 130
precision highp float;

uniform mat4 projection_matrix;

uniform vec4 start_color;
uniform vec4 end_color;

uniform float start_alpha;
uniform float end_alpha;

uniform vec4 color_variance;

uniform float start_size;
uniform float end_size;

uniform float size_variance;

uniform float start_angular_velocity;
uniform float end_angular_velocity;

uniform float life_time;
uniform float current;

in vec2  position;
in vec2  velocity;
in vec2  random;
in vec2  offset;
in vec2  coords;
in float time;

out vec2 out_coords;
out vec4 out_tint;

void main(void)
{
	float age = clamp(0.0,1.0,(current - time) / (life_time));

	vec2 pos = position;
	pos += velocity * age;
	float angle = mix(start_angular_velocity, end_angular_velocity, age) * random.y * random.x;

	float s = sin(angle);
	float c = cos(angle);

	float varianceSize = random.x * size_variance;

	vec2 offset = (mix(start_size, end_size, age) + varianceSize) * offset;

	pos.x += offset.x * c - offset.y * s ;
	pos.y += offset.x * s + offset.y * c;

	vec4 varianceColor = color_variance * random.x;

	//OUT STUFF
	float alpha = mix(start_alpha, end_alpha, age);

	out_tint = (mix(start_color, end_color, age) + varianceColor) * alpha;
	out_coords = coords;
	gl_Position = projection_matrix * vec4(pos, 0.0, 1.0);
}
";

enum fs =
"
#version 130
precision highp float;

in vec2 out_coords;
in vec4 out_tint;
out vec4 out_frag_color;
uniform sampler2D tex;

void main(void)
{
	out_frag_color = texture(tex, out_coords) * out_tint;
}
";
}