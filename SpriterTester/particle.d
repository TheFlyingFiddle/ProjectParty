module particle;

import graphics, game, content, math, content.sdl, allocation;
import std.stdio;

class ParticleState : IGameState
{
	ParticleSystem system;

	int fpsCounter;
	int fps = 60;
	float fpsElapsed = 0;

	float counter = 0;
	FontID font;
	
	this(A)(ref A allocator)
	{
		auto settings = fromSDLFile!ParticleSettings(GC.it, "ParticleSettings.sdl");
		system = ParticleSystem(allocator, settings, 0xFFFF * 16);
		font = Game.content.loadFont("Blocked72");
	}

	void enter() 
	{
	}

	void exit() 
	{
	}

	void update()
	{
		fpsCounter++;
		fpsElapsed += Time.delta;
		if(fpsElapsed >= 1.0f)
		{
			fpsElapsed -= 1.0f;
			fps = fpsCounter;
			fpsCounter = 0;
		}

		if(Keyboard.isDown(Key.enter)){
			system.settings = fromSDLFile!ParticleSettings(GC.it, "ParticleSettings.sdl");
		}

		import std.random;

		counter += Time.delta;
		while(counter > 1.0f / 60)
		{
			counter -= 1.0f / 60;

			float4 rect		= float4(0,0,1,1);
			float2 pos		= float2(Game.window.size / 2);
			auto polar	    = float2(0,300).toPolar();
			polar.angle		+= uniform(-1.0f,1.0f);

			float2 size		= float2(2, 2);

			Particle particle;
			particle.coords		= rect;
			particle.center		= pos;
			particle.velocity	= polar.toCartesian;
			particle.startSize	= float2(10,10);
			particle.endSize	= float2(100,100);
			particle.startColor = Color.white;
			particle.endColor	= Color.green;
			particle.time		= system.currentTime;
			particle.rotationSpeed = TAU * 3;
			particle.lifeTime	= 3;

			system.AddParticle(particle);
			foreach(i; 0 .. 5800)
			{
				auto pos2 = pos + Polar!float(Time.total + 0.5f * i, 200f).toCartesian;
				auto velo = (pos2 - pos).toPolar;
				velo.angle += uniform(-0.5f, 0.5f);

				particle.startSize = float2(1,1);
				particle.endSize   = float2(1,1);
				particle.center = pos2;
				particle.velocity = velo.toCartesian;
				particle.endColor = Color.red;


				system.AddParticle(particle);
			}
		}

		system.Update(Time.delta);
	}

	void render()
	{
		gl.clear(ClearFlags.color);

		mat4 proj = mat4.CreateOrthographic(0, Game.window.fboSize.x, Game.window.fboSize.y, 0, 1, -1);
		system.Render(proj, Game.content.loadTexture("particle.png"));

		import util.strings;
		char[128] buffer;
		Game.renderer.addText(font, text(buffer, "FPS: ", fps), float2(0, Game.window.fboSize.y), Color.red);
		Game.renderer.addText(font, text(buffer, "Active Particles: ", system.numActiveParticles), float2(0, Game.window.fboSize.y - 100), Color.red);
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

struct Particle
{
	//64-bytes
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
}

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

	private Program program;

	private float currentTime = 0;
	private float lifeTime    = 3;
	private int drawCounter = 0;
	private Particle[] queue;

	ParticleSettings settings;


	int firstActiveParticle;
	int firstNewParticle;
	int firstFreeParticle;
	int firstRetiredParticle;

	@property int numActiveParticles()
	{
		if(firstFreeParticle > firstActiveParticle)
			return firstFreeParticle - firstActiveParticle;
		else
			return firstFreeParticle + MaxParticles - firstActiveParticle;
	}

	private int MaxParticles()
	{
		return this.queue.length;
	}

	import allocation;
	this(ref ScopeStack allocator, ParticleSettings settings, size_t bufferSize)
	{
		this.settings   = settings;
		this.queue	    = allocator.allocate!(Particle[])(bufferSize);

		this.vbo = VBO.create(BufferHint.streamDraw);
		this.vao = VAO.create();
		
		gl.bindBuffer(vbo.target, vbo.glName);
		vbo.initialize(cast(uint)(bufferSize * Particle.sizeof));

		auto gShader = Shader(ShaderType.geometry, gs),
			 vShader = Shader(ShaderType.vertex,   vs),
			 fShader = Shader(ShaderType.fragment, fs);

		this.program = Program(allocator, gShader, vShader, fShader);

		gShader.destroy();
		vShader.destroy();
		fShader.destroy();

		gl.bindVertexArray(vao.glName);
		vao.bindAttributesOfType!Particle(program);
	}


	private void setupShaderProgram(ref mat4 projection)
	{
		gl.useProgram(program.glName);
		
		program.uniform[PROJ_MAT]		= projection;
		program.uniform[LIFE_TIME]		= settings.lifeTime;
		program.uniform[CURRENT_TIME]	= this.currentTime;
		program.uniform[START_ALPHA]	= 1.0f;
		program.uniform[END_ALPHA]		= 0.0f;
		program.uniform[TEXTURE]		= 0;
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
			float particleAge = currentTime - queue[firstActiveParticle].time;

			if (particleAge < lifeTime)
				break;

			// Remember the time at which we retired this particle.
			queue[firstActiveParticle].time = drawCounter;

			// Move the particle from the active to the retired queue.
			firstActiveParticle = (firstActiveParticle + 1) % this.MaxParticles;
		}
	}

	private void FreeRetiredParticles()
	{
		while (firstRetiredParticle != firstActiveParticle)
			firstRetiredParticle = (firstRetiredParticle + 1) % this.MaxParticles;
	}


	public void Render(ref mat4 projection, TextureID texture)
	{
		import std.stdio;

		gl.bindBuffer(vbo.target, vbo.glName);
		gl.useProgram(program.glName);

		this.AddNewParticlesToVertexBuffer();
		this.setupShaderProgram(projection);

		gl.bindVertexArray(vao.glName);
		auto tex = texture.texture;
		gl.activeTexture(TextureUnit.zero);
		gl.bindTexture(tex.target, tex.glName);

		if (firstActiveParticle < firstFreeParticle)
		{
			gl.drawArrays(PrimitiveType.points, 
						  firstActiveParticle, 
						 (firstFreeParticle - firstActiveParticle));
		}
		else
		{
			gl.drawArrays(PrimitiveType.points, 
						  firstActiveParticle,  
						 (MaxParticles - firstActiveParticle));
			if (firstFreeParticle > 0)
			{	
				gl.drawArrays(PrimitiveType.points, 0, firstFreeParticle);
			}
		}

		drawCounter++;
	}


	void AddNewParticlesToVertexBuffer()
	{
		if(firstNewParticle == firstFreeParticle) return;

		if (firstNewParticle < firstFreeParticle)
		{
			auto range0 = firstNewParticle, 
				 range1 = (firstFreeParticle - firstNewParticle);
			vbo.bufferSubData(queue[range0 .. range0 + range1], range0);

			//auto ptr = vbo.mapRange!Particle(range0, range1, BufferRangeAccess.unsynchronizedWrite);
			//foreach(i; 0 .. range1)
			//{
			//    (*ptr++) = queue[range0 + i];
			//}
			//vbo.unmapBuffer();
		}
		else
		{
			auto range0 = firstNewParticle, 
				 range1 = (this.MaxParticles - firstNewParticle);
			vbo.bufferSubData(queue[range0 ..  range0 + range1], range0);

			if (firstFreeParticle > 0)
			{
				vbo.bufferSubData(queue[0 ..  firstFreeParticle], 0);
			}
		}

		firstNewParticle = firstFreeParticle;
	}

	public void AddParticle(ref Particle particle)
	{
		int nextFreeParticle = (firstFreeParticle + 1) % this.MaxParticles;

		if (nextFreeParticle == firstRetiredParticle)
			return;

		queue[firstFreeParticle] = particle;
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
} vertex[];

out vertData
{
	vec4 color;
	vec2 coord;
} vertOut;

vec4 calcPos(in vec2 pos, in vec2 origin, in float sinus, in float cosinus)
{
	pos.x += origin.x * cosinus - origin.y * sinus;
	pos.y += origin.x * sinus   + origin.y * cosinus;
	return vec4(pos, 0 , 1);
}

void emitCorner(in vec2 pos, in vec2 origin, 
				in vec2 coord, in float sinus, 
				in float cosinus, in vec4 color)
{
	gl_Position      = projection_matrix * calcPos(pos, origin, sinus, cosinus);
	vertOut.color	 = color;
	vertOut.coord	 = coord;
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
	float alpha = mix(start_alpha, end_alpha, age);
	vec4 out_tint = mix(vertex[0].startColor, vertex[0].endColor, age) * alpha;


	emitCorner(pos, origin					, vertex[0].coords.xy, s, c, out_tint);
	emitCorner(pos, origin + vec2(0, size.y), vertex[0].coords.xw, s, c, out_tint);
	emitCorner(pos, origin + vec2(size.x, 0), vertex[0].coords.zy, s, c, out_tint);
	emitCorner(pos, origin + size			, vertex[0].coords.zw, s, c, out_tint);
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
} vertIn;


out vec4 out_frag_color;
uniform sampler2D tex;

void main(void)
{
	out_frag_color = texture(tex, vertIn.coord) * vertIn.color;
}
";
}