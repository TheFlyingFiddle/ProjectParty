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
import std.algorithm : max, min, any;

alias In = IncommingNetworkMessage;
enum IncomingMessages : In
{
	toggleReady	= In(49),
	answer		= In(50),
	buyScore	= In(51),
}

alias Out = OutgoingNetworkMessage;
enum OutgoingMessages : Out
{
	choices			= Out(50, 1024),
	correctAnswer	= Out(51),
	showAnswer		= Out(52),
}


@(OutgoingMessages.choices)
struct Choices
{
	string[] choices;
 	ubyte category;
}

@(OutgoingMessages.correctAnswer)
struct CorrectAnswer { }


@(OutgoingMessages.showAnswer)
struct ShowAnswer 
{
	ubyte answer;
}

struct PlayerData
{
	ubyte[Category.max + 1] categoryCorrect;
	ubyte answer;
}

enum Category : ubyte
{
	sports = 0,
	science = 1,
	entertainment = 2,
	geography = 3,
	history = 4,
	culture = 5
}

struct Question
{
	string		question;
	string		answer;
	string[]	choices;
}

struct Questions
{
	List!QuestionSet questionSets;

	auto ref opIndex(Category category, size_t index)
	{
		return questionSets[category].questions[index];
	}

	size_t length(Category category)
	{
		return questionSets[category].questions.length;
	}
}

struct QuestionSet
{
	Category		category;
	List!Question	questions;
}

enum GameState : ubyte
{
	question = 0,
	answer = 1
}

struct QuestionInstance
{
	Category	category;
	size_t		questionIndex;
}

class GamePlayState : IGameState
{
	Table!(ulong, PlayerData) players;
	Questions questions;
	@property Question currentQuestion()
	{
		return questions[order[0].category, order[0].questionIndex];
	}

	float elapsed;
	float questionTime;
	float answerTime;

	List!QuestionInstance order;

	GameState state;

	this(A)(ref A allocator)
	{
		players = Table!(ulong, PlayerData)(allocator, 40);
		order = List!QuestionInstance(allocator, Category.max + 1);
		questions = fromSDLFile!(Questions)(GC.it, "questions.sdl");
		elapsed = 0;
		questionTime = 15;
		answerTime = 0.1;
	}

	void enter()
	{
		players.clear();
		foreach(i, player; Game.players)
		{
			players[player.id] = PlayerData();
			players[player.id].answer = ubyte.max;
		}
		nextQuestion();
		Game.router.setMessageHandler(IncomingMessages.answer, &handleAnswer);
		Game.router.setMessageHandler(IncomingMessages.buyScore, &handleBuyScore);
	}

	void handleAnswer(ulong id, ubyte[] msg)
	{
		auto answer = msg.read!ubyte;
		players[id].answer = answer;
		int counter;
		foreach(id, player; players)
		{
			if(player.answer != ubyte.max)
				counter++;
		}
		if(counter == players.length)
			showAnswer();
	}

	void handleBuyScore(ulong id, ubyte[] msg)
	{
		auto category = msg.read!ubyte;
		players[id].categoryCorrect[category]++;
		if(hasWon(id))
			gameOver();
	}

	bool hasWon(ulong id)
	{
		foreach(category; players[id].categoryCorrect)
		{
			if(category < 3)
				return false;
		}
		return true;
	}

	void gameOver()
	{
		Game.transitionTo("Lobby");
	}

	void exit()
	{
		
	}

	void update()
	{
		elapsed += Time.delta;
		if(state == GameState.question)
		{
			if(elapsed >= questionTime)
			{
				showAnswer();
			}
		}
		else
		{
			if(elapsed >= answerTime)
			{
				nextQuestion();
			}
		}
	}

	void showAnswer()
	{
		foreach(id, ref player; players)
		{
			auto answer = player.answer;
			if(answer != ubyte.max &&
					currentQuestion.answer == 
					currentQuestion.choices[answer])
			{
				Game.server.sendMessage(id, CorrectAnswer());
				players[id].categoryCorrect[order[0].category]++;
				if(hasWon(id))
					gameOver();
			}
			players[id].answer = ubyte.max;
			auto index = currentQuestion.choices.countUntil!(x=>x == currentQuestion.answer);
			Game.server.sendMessage(id, ShowAnswer(cast(ubyte)index));
		}
		state = GameState.answer;
		elapsed = 0;
	}

	void nextQuestion()
	{
		if (order.length == 1 || order.length == 0)
		{
			order.clear();
			while(order.length <= Category.max)
			{
				auto category = cast(Category)uniform(0, Category.max+1);
				if(order.any!(x=>x.category == category))
					continue;
				auto questionIndex = uniform(0, questions.length(category));
				order ~= QuestionInstance(category, questionIndex);
			}
		}
		else
		{
			order.removeAt(0);
		}

		foreach(id, player; players)
		{
			Game.server.sendMessage(id, Choices(currentQuestion.choices,
												order[0].category));
		}
		elapsed = 0;
		state = GameState.question;
	}

	void render()
	{
		gl.clearColor(1,1,1,1);
		gl.clear(ClearFlags.all);

		auto font = Game.content.loadFont("SegoeUILight72");
		
		if(state == GameState.question)
		{
			auto size = font.measure(currentQuestion.question);
			Game.renderer.addText(	font, currentQuestion.question, 
									float2(Game.window.size/2) - size/2,
									Color.black);
		}
		else
		{
			auto size = font.measure(currentQuestion.answer);
			Game.renderer.addText(	font, currentQuestion.answer, 
									float2(Game.window.size/2) - size/2,
									Color.black);
		}
	}
}