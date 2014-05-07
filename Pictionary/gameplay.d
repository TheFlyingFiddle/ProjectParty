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
	game.debuging;

import std.random;
import std.algorithm : max, min;

enum IncomingMessages : ubyte
{
	lobbyReady = 49,
	choice = 50,
	ready = 51,
	pixel = 52,
	clear = 53
}

struct YouDraw
{
	enum ubyte id = 50;
	enum uint maxSize = 128;
	string toDraw;
}

struct YouGuess
{
	enum ubyte id = 51;
	enum uint maxSize = 1024;
	string[] choices;
}

struct BetweenRounds
{
	enum ubyte id = 52;
	ubyte youDraw;
}

struct CorrectAnswer
{
	enum ubyte id = 53;
}

struct IncorrectAnswer
{
	enum ubyte id = 54;
}

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

	List!Line lines;
	Table!(ulong, PlayerData) players;
	Questions questions;

	float elapsed;
	float playTime;

	GameState state;

	uint drawingPlayer;
	uint currentQuestion;

	this(A)(ref A allocator)
	{
		lines = List!Line(allocator, 1_000_000);
		players = Table!(ulong, PlayerData)(allocator, 40);
		questions = fromSDLFile!Questions(allocator, "questions.sdl");
		layout = fromSDLFile!Layout(allocator, "layout.sdl");
		layout.drawingArea.scale(Game.window.relativeScale);
		layout.nameArea.scale(Game.window.relativeScale);
		
		state = GameState.betweenRounds;
		elapsed = 0;
		playTime = 10;
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
		auto position = float2(msg.read!float * layout.drawingArea.z + layout.drawingArea.x, 
							   msg.read!float * layout.drawingArea.w + layout.drawingArea.y);
		if (start || lines.length == 0)
			lines ~= Line(position, position);
		else
			lines ~= Line(lines[$-1].endPos, position);
	}

	void handleClear(ulong id, ubyte[] msg)
	{
		lines.clear();
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

		lines.clear();
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

		lines.clear();
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
		Game.renderer.addText(font, text(buf, "Time left: ", playTime - elapsed), float2(0, Game.window.size.y), 
							  Color.black, Game.window.relativeScale);
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

		if (state == GameState.inRound)
		{
			foreach(line; lines)
			{
				Game.renderer.addFrame(frame, float4(line.startPos.x - 2, line.startPos.y - 2, 4, 4), Color.black);
			}

			foreach(line; lines)
			{
				Game.renderer.addLine(line.startPos, line.endPos, Color.black, 4);
			}
		}
	}
}
