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
	Color playerColor;
	int score;
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

class GamePlayState : IGameState
{
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
		questions = fromSDLFile!(Questions)(GC.it, "questions.sdl");
		state = GameState.betweenRounds;
		elapsed = 0;
		playTime = 10;
	}

	void enter()
	{
		Game.router.setMessageHandler(50, &handleChoice);
		Game.router.setMessageHandler(51, &handleReady);
		Game.router.setMessageHandler(52, &handlePixel);
		Game.router.setMessageHandler(53, &handleClear);

		foreach(i, player; Game.players)
		{
			auto color = Color(uniform(0, 0xFFFFFF+1) | 0xFF000000);
			players[player.id] = PlayerData(color, 0);
			Game.server.sendMessage(player.id, BetweenRounds(i == 0));
		}

		drawingPlayer = 0;
	}

	void handleChoice(ulong id, ubyte[] msg)
	{
		auto choice = msg.read!ubyte;
		if(questions[currentQuestion].answer == 
		   questions[currentQuestion].choices[choice])
		{
			Game.server.sendMessage(id, CorrectAnswer());
			players[id].score++;
			nextQuestion();
		}
		else
		{
			Game.server.sendMessage(id, IncorrectAnswer());
			players[id].score = max(0, players[id].score - 1);
		}
		
	}

	void handleReady(ulong id, ubyte[] msg)
	{
		state = GameState.inRound;

		nextQuestion();
	}

	void handlePixel(ulong id, ubyte[] msg)
	{
		auto start = msg.read!ubyte;
		auto position = float2(msg.read!float * Game.window.size.x, msg.read!float * Game.window.size.y);
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
		}

		lines.clear();
	}

	void render()
	{
		gl.clearColor(1,1,1,1);
		gl.clear(ClearFlags.all);

		auto texture	= Game.content.loadTexture("smooth");
		auto frame		= Frame(texture);

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

class LobbyState : IGameState
{
	this() { }

	void enter() { }
	void exit() { }

	void update()
	{
		if(Keyboard.isDown(Key.enter))
		{
			Game.transitionTo("GamePlay");
		}
	}

	void render() 
	{
		gl.clearColor(1,0,1,1);
		gl.clear(ClearFlags.all);
	}
}