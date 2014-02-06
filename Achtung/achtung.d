module achtung;

import main;
import math;
import types;
import rendering;
import content.sdl;
import graphics;
import event;
import std.random;
import logging;
import std.algorithm;
import game;
import std.variant;
import collections.grid;

struct AchtungConfig
{
    float minInvis, maxInvis, minVis, maxVis, turnSpeed;
    int snakeSize;
	int winningScore;
    SnakeProperties[] snakes;
    uint2 mapDim;
}

struct SnakeProperties
{
    uint color, leftKey, rightKey;
}

class AchtungGameState : IGameState
{
	//Maby theses shoul do someting?
	void init() { }
	void handleInput() { }

	Grid!bool map;
	EventStream stream;
	AchtungRenderer renderer;


	Table!(Snake) snakes;
	Table!(SnakeControl) controls;
	Table!(float) timers;
	Table!(int)   scores;

	//Temporary
	ulong[100] ids;
	
	AchtungConfig config;

	void init(Allocator)(ref Allocator allocator, string configPath)
	{
		config     = fromSDLFile!AchtungConfig(allocator, configPath);

		snakes     = Table!(Snake)(allocator, config.snakes.length);
		timers     = Table!(float)(allocator, config.snakes.length);
		scores     = Table!(int  )(allocator, config.snakes.length);
		controls   = Table!(SnakeControl)(allocator, config.snakes.length);


		foreach(i; 0 .. config.snakes.length)
		{
			scores[Color(config.snakes[i].color)] = 0;
		}

		map		  = Grid!bool(allocator,config.mapDim.x,config.mapDim.y);
		renderer   = AchtungRenderer(allocator, cast(uint)config.snakes.length, config.mapDim.x, config.mapDim.y);
		stream     = EventStream(allocator, 1024);
	}

	void enter()
	{
		foreach(i, player; Game.players)
			ids[i] = player.id;

		reset();
		foreach(ref score; scores) 
			score = 0;
	}

	void exit()
	{
	
	}

	void reset()
	{
		foreach(s; scores) if(s > config.winningScore)
		{
			Game.gameStateMachine.transitionTo("GameOver");
			return;
		}
	
		snakes.clear();
		timers.clear();
		controls.clear();
		stream.clear();

		map.fill(0);
		renderer.clear(Color(1,0,1,0));

		foreach(i; 0 .. snakes.capacity)
		{
			Color key = config.snakes[i].color;
			Snake snake;
			snake.pos = float2(uniform(50, config.mapDim.x -50), uniform(50, config.mapDim.y -50));
			snake.dir = (float2(config.mapDim/2) - snake.pos).normalized;
			snake.visible = true;

			snakes[key]  = snake;
			controls[key] = SnakeControl(config.snakes[i].leftKey, 
												  config.snakes[i].rightKey,
												  ids[i]);
			timers[key]   = 1.0f;
		}
	}

	void update()
	{
		generateInputEvents(controls, stream);
		handleInput(snakes, stream, config.turnSpeed);
		updateTimers(timers, snakes, Time.delta);

		moveSnakes(snakes, map, stream, config.snakeSize);
		handleCollision(snakes, timers, scores, controls, map, stream);

		stream.clear();
	}

	void render()
	{
		renderFrame(renderer, snakes, scores);
	}

	void generateInputEvents(ref Table!(SnakeControl) controls, ref EventStream stream) // <-- This is wierd and very much not ok.
	{
		foreach(key, c; controls)
		{
			if(Keyboard.isDown(cast(Key)c.leftKey))
				stream.push(InputEvent(key,config.turnSpeed));
			if(Keyboard.isDown(cast(Key)c.rightKey))
				stream.push(InputEvent(key,-config.turnSpeed));

			if(Phone.exists(c.id))
			{
				PhoneState state = Phone.state(c.id);
				stream.push(InputEvent(key, state.accelerometer.y / 400));
			}	
		}
	}

	void handleInput(ref Table!(Snake) snakes, 
					 ref EventStream stream, float turn)
	{
		foreach(event; stream.over!InputEvent)
		{
			auto snake = event.color in snakes;
			auto polar = snake.dir.toPolar;
			polar.angle += event.input;
			snake.dir = polar.toCartesian;
		}
	}

	void updateTimers(ref Table!(float) timers, 
					  ref Table!(Snake) snakes,
					  float elapsed)
	{
		foreach(c, ref timer; timers)
		{
			timer -= elapsed;
			if(timer <= 0.0f)
			{
				auto snake = c in snakes;
				if(snake.visible) {
					snake.visible = false; 
					timer = uniform(config.minInvis,config.maxInvis);
				} 
				else 
				{
					snake.visible = true;
					timer = uniform(config.minVis,config.maxVis);
				}
			}
		}
	}

	void moveSnakes(ref Table!Snake snakes, 
					ref Grid!bool map, 
					ref EventStream stream, 
					uint size)
	{
		foreach(key, ref snake; snakes)	
		{
			auto oldPos = uint2(snake.pos);
			snake.pos += snake.dir;
			auto newPos = uint2(snake.pos);
			if(oldPos != newPos && snake.visible) 
			{
				auto c = checkCollision(newPos, oldPos, size, map);
				if(c)
				{
					stream.push(CollisionEvent(key, c));
				} 
				else 
				{
					uint2 origin = uint2(size / 2, size / 2);
					foreach(row; 0 .. size)
						foreach(column; 0 .. size)
							map[newPos - origin + uint2(column, row)] = true;
				}
			}
		}
	}

	uint checkCollision(uint2 newPos, uint2 oldPos, uint size, ref Grid!bool map)
	{
		uint count = 0;
		uint2 origin = uint2(size / 2, size / 2);
		foreach(uint row; 0 .. size)
		{
			foreach(uint column; 0 .. size)
			{
				uint2 cell = newPos - origin + uint2(column, row);
				if(!inOld(cell, oldPos, size))
				{
					if(checkCollision(cell, map)) count++;
				}
			}
		}
		return count;
	}

	bool inOld(uint2 newCell, uint2 oldPos, uint size)
	{
		uint2 origin = uint2(size / 2, size / 2);
		foreach(uint row; 0 .. size)
		{
			foreach(uint column; 0 .. size)
			{
				uint2 cell = oldPos - origin + uint2(column, row);
				if(newCell == cell) return true;
			}
		}
		return false;
	}

	bool checkCollision(uint2 cell, ref Grid!bool map)
	{
		return hitWall(cell, map) || map[cell] == true;
	}

	bool hitWall(uint2 position, ref Grid!bool map)
	{
		return position.x >= map.width || 
			position.y >= map.height;
	}

	void handleCollision(ref Table!Snake snakes,
					     ref Table!float timers,
					     ref Table!int scores,
					     ref Table!SnakeControl controls, 
					     ref Grid!bool map, 
					     ref EventStream stream)
	{
		foreach(collision; stream.over!CollisionEvent)
		{
			if(collision.numPixels < config.snakeSize / 2 + 1) continue;

			timers.remove(collision.color);
			controls.remove(collision.color);
			snakes.remove(collision.color);
			

			auto toGet = snakes.capacity - snakes.length;
			scores[collision.color] += toGet;
			if(snakes.length == 1){
				scores[snakes.keys[0]] += snakes.capacity;
				reset();
				return;
			}
		}
	}

	void renderFrame(ref AchtungRenderer buffer,
					 ref Table!Snake snakes,
					 ref Table!int scores)
	{
		gl.clear(ClearFlags.color);
		
		uint2 s = Game.window.size;
		gl.viewport(0,0, s.x, s.y);
		mat4 proj = mat4.CreateOrthographic(0,s.x,s.y,0,1,-1);
		buffer.draw(proj, snakes, scores, config.snakeSize);
	}
}