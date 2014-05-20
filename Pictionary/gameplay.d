module gameplay;

import 
	game, 
	graphics, 
	math, 
	content, 
	collections, 
	network.message, 
	util.bitmanip, 
	allocation,
	game.debuging,
	graphics.convinience;

import std.random;
import std.algorithm : max, min;

alias In = IncommingNetworkMessage;
enum IncomingMessages : In
{
	lobbyReady	= In(49),
	choice		= In(50),
	ready		= In(51),
	pixel		= In(52),
	clear		= In(53)
}

alias Out = OutgoingNetworkMessage;
enum OutgoingMessages : Out
{
	youDraw			= Out(50, 128),
	youGuess		= Out(51, 1024),
	betweenRounds	= Out(52),
	correctAnswer   = Out(53),
	incorrectAnswer	= Out(54),
}

@(OutgoingMessages.youDraw)
struct YouDraw
{
	string toDraw;
}

@(OutgoingMessages.youGuess)
struct YouGuess
{
	string[] choices;
}

@(OutgoingMessages.betweenRounds)
struct BetweenRounds
{
	ubyte youDraw;
}

@(OutgoingMessages.correctAnswer)
struct CorrectAnswer { }

@(OutgoingMessages.incorrectAnswer)
struct IncorrectAnswer { }

struct PlayerData
{
	Color color;
	int score;
	bool ready;
}

struct Question
{
	string		answer;
	string[]	choices;
}

struct Questions
{
	List!Question questions;

	auto ref opIndex(size_t index)
	{
		return questions[index];
	}

	@property size_t length()
	{
		return questions.length;
	}
}

enum GameState : ubyte
{
	inRound = 0,
	betweenRounds = 1
}

struct Line
{
	float2 startPos;
	float2 endPos;
}

struct Layout
{
	float4 drawingArea;
	float4 nameArea;
	float4 roundArea;
}

ref float4 scale(ref float4 toScale, float2 s)
{
	toScale.x *= s.x;
	toScale.y *= s.y;
	toScale.z *= s.x;
	toScale.w *= s.y;
	return toScale;
}

class GamePlayState : IGameState
{
	Layout layout;
	Table!(ulong, PlayerData) players;
	Questions questions;

	float elapsed;
	float playTime;

	GameState state;

	uint drawingPlayer;
	uint currentQuestion;

	FBO fbo;
	float2 oldDrawPos;

	this(A)(ref A allocator)
	{
		players = Table!(ulong, PlayerData)(allocator, 40);
		questions = fromSDLFile!Questions(allocator, "questions.sdl");
		layout = fromSDLFile!Layout(allocator, "layout.sdl");
		layout.drawingArea.scale(Game.window.relativeScale);
		layout.nameArea.scale(Game.window.relativeScale);
		
		state = GameState.betweenRounds;
		elapsed = 0;
		playTime = 100;

		fbo = createSimpleFBO(cast(uint)layout.drawingArea.z * 2, cast(uint)layout.drawingArea.w * 2);
	}

	void enter()
	{
		Game.router.setMessageHandler(IncomingMessages.choice, &handleChoice);
		Game.router.setMessageHandler(IncomingMessages.ready, &handleReady);
		Game.router.setMessageHandler(IncomingMessages.pixel, &handlePixel);
		Game.router.setMessageHandler(IncomingMessages.clear, &handleClear);

		foreach(i, player; Game.players)
		{
			auto color = Color(uniform(0, 0xFFFFFF+1) | 0xFF000000);
			players[player.id] = PlayerData(color, 0, false);
			Game.server.sendMessage(player.id, BetweenRounds(i == 0));
		}

		drawingPlayer = 0;
	}

	void onConnect(ulong id)
	{

	}

	void handleChoice(ulong id, ubyte[] msg)
	{
		auto choice = msg.read!ubyte;
		if(questions[currentQuestion].answer == 
		   questions[currentQuestion].choices[choice])
		{
			Game.server.sendMessage(id, CorrectAnswer());
			players[id].score++;
			// Added as an incentive to paint at all...
			players[drawingPlayer].score++;
			nextQuestion();
		}
		else
		{
			Game.server.sendMessage(id, IncorrectAnswer());
			players[id].score--;
		}
	}

	void handleReady(ulong id, ubyte[] msg)
	{
		if(players.indexOf(id) == -1) 
			return;
		players[id].ready = true;
		if(allReady()) {
			state = GameState.inRound;
			nextQuestion();
		}
	}

	bool allReady()
	{
		foreach(player; players)
		{
			if(!player.ready)
				return false;
		}
		return true;
	}

	void handlePixel(ulong id, ubyte[] msg)
	{
		auto start = msg.read!ubyte;
		auto position = float2(msg.read!float * layout.drawingArea.z * 2, 
							   msg.read!float * layout.drawingArea.w * 2);
		if(start)
		{
			oldDrawPos = position;
			drawOnCanvas(position);
		}
		else 
		{
			drawOnCanvas(position);
			oldDrawPos = position;
		}
	}

	void handleClear(ulong id, ubyte[] msg)
	{
		clear();
	}

	void clear()
	{
		gl.bindFramebuffer(FrameBufferTarget.framebuffer, fbo.glName);
		gl.clearColor(1,1,1,1);
		gl.clear(ClearFlags.all);
		gl.bindFramebuffer(FrameBufferTarget.framebuffer, 0);

	}

	void exit()
	{
		
	}

	void update()
	{
		if (state == GameState.inRound)
		{
			elapsed += Time.delta;
			if(elapsed >= playTime)
			{
				roundOver();
				elapsed = 0;
			}
		}
	}

	void nextQuestion()
	{
		currentQuestion = uniform(0, questions.length);
		auto drawingID = players.keyAt(drawingPlayer);
		Game.server.sendMessage(drawingID, YouDraw(questions[currentQuestion].answer));
		
		foreach(id, player; players) if (id != drawingID)
		{
			Game.server.sendMessage(id, YouGuess(questions[currentQuestion].choices));
		}

		clear();
	}

	void roundOver()
	{
		state = GameState.betweenRounds;
		
		drawingPlayer = (drawingPlayer + 1)%players.length;
		foreach(id, _ ; players)
		{
			auto index = players.indexOf(id);
			Game.server.sendMessage(id, BetweenRounds(index == drawingPlayer));
			players[id].ready = false;
		}

		clear();
	}

	void drawOnCanvas(float2 position)
	{
		gl.bindFramebuffer(FrameBufferTarget.framebuffer, fbo.glName);
		auto buffer = Game.renderer;

		auto texture	= Game.content.loadTexture("smooth");
		auto frame		= Frame(texture);
		
		auto dir = (position - oldDrawPos).normalized;
		auto mag = distance(position, oldDrawPos);
		import std.stdio;
		writeln("Dir:", dir, "Mag:", mag);
		
		mat4 proj = mat4.CreateOrthographic(0,Game.window.fboSize.x, Game.window.fboSize.y,0,1,-1);
		buffer.start(proj);

		foreach(i; 0 .. cast(int)(mag * 10))
		{	
			auto pos = oldDrawPos + dir * (i / 10.0f);
			buffer.addFrame(frame, float4(pos.x, pos.y, 10, 10), Color.black, float2(5, 5));
		}

		if(oldDrawPos == position)
		{
			buffer.addFrame(frame, float4(position.x, position.y, 5, 5), Color.black, float2(2.5, 2.5));
		}

		buffer.draw();
		buffer.end();


		gl.bindFramebuffer(FrameBufferTarget.framebuffer, 0);
	}

	void render()
	{
		gl.clearColor(0,0,0,0);
		gl.clear(ClearFlags.all);

		auto texture	= Game.content.loadTexture("smooth");
		auto frame		= Frame(texture);
		
		auto font		= Game.content.loadFont("SegoeUILight72");

		auto bgtexture	= Game.content.loadTexture("background2");
		auto bgframe		= Frame(bgtexture);

		Game.renderer.addFrame(bgframe, float4(0,0,Game.window.size.x,Game.window.size.y), Color.white);

		import util.strings;
		char[128] buf;
		Game.renderer.addText(font, text(buf, "Time left: ", playTime - elapsed), layout.roundArea.xy, 
							  Color.white, Game.window.relativeScale);
		foreach(i, id, player; players)
		{
			auto index = Game.players.countUntil!(p=>p.id == id);
			if(index == -1)
				continue;
			auto scoreText = text(buf, Game.players[index].name, ": ", player.score);
			auto size = font.measure(scoreText);

			Game.renderer.addText(font, scoreText,
				  float2(layout.nameArea.x, layout.nameArea.y + layout.nameArea.w - i*size.y), 
								  player.color, Game.window.relativeScale);
		}

		gl.bindFramebuffer(FrameBufferTarget.framebuffer, fbo.glName);
		uint4 area = uint4(layout.drawingArea.x, layout.drawingArea.y, 
						   layout.drawingArea.z + layout.drawingArea.x, 
						   layout.drawingArea.w + layout.drawingArea.y);
		blitToBackbuffer(fbo,
						 uint4(0,0, layout.drawingArea.z * 2, layout.drawingArea.w * 2),
						 area,
						 BlitMode.color,
						 BlitFilter.linear);
		gl.bindFramebuffer(FrameBufferTarget.framebuffer, 0);
	}
}
