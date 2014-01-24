module achtung;

import main;
import collections;
import math;
import types;
import rendering;
import content.sdl;
import graphics.color;
import derelict.glfw3.glfw3;
import event;
import std.random;
import logging;
import game.time;
import std.algorithm;

Grid!bool map;
EventStream stream;
AchtungRenderer renderer;

List!Snake alive;
List!Timer timers;
List!Score scores;
List!SnakeControl controls;
int visibleSnakes;
AchtungConfig config;

struct AchtungConfig
{
    float minInvis, maxInvis, minVis, maxVis, turnSpeed;
    int snakeSize;
    SnakeProperties[] snakes;
    uint2 mapDim;
}

struct SnakeProperties
{
    uint color, leftKey, rightKey;
}

void init(Allocator)(ref Allocator allocator, string configPath)
{
    config = fromSDLFile!AchtungConfig(allocator, configPath);

	alive      = List!Snake(allocator, config.snakes.length);
	timers     = List!Timer(allocator, config.snakes.length);
	controls   = List!SnakeControl(allocator, config.snakes.length);
	scores	   = List!Score(allocator, config.snakes.length);

	foreach(i; 0 .. config.snakes.length)
	{
		scores ~= Score(Color(config.snakes[i].color), 0);
	}


	map		   = Grid!bool(allocator,config.mapDim.x,config.mapDim.y);
	renderer   = AchtungRenderer(allocator, config.snakes.length, config.mapDim.x, config.mapDim.y);
	stream     = EventStream(allocator, 1024);

	reset();
}

void reset()
{

	writeScores();

	alive.clear();
	timers.clear();
	controls.clear();
	stream.clear();

	map.fill(0);
	renderer.clear(Color(1,0,1,0));

	foreach(i; 0 .. alive.capacity)
	{
		Snake snake;
		snake.pos = float2(uniform(50, config.mapDim.x -50), uniform(50, config.mapDim.y -50));
		snake.dir = ( float2(config.mapDim/2) - snake.pos).normalized;
		snake.color = Color(config.snakes[i].color);
		alive ~= snake;

		controls ~= SnakeControl(snake.color, 
								 config.snakes[i].leftKey,
								 config.snakes[i].rightKey);

		timers ~= Timer(1, snake.color, true);
	}

	visibleSnakes = alive.length;
}

void writeScores()
{
	foreach(score; scores)
	{
		info(score.score);
	}
}

void update()
{
	generateInputEvents(controls, stream, window);
	handleInput(alive, stream, config.turnSpeed);
	updateTimers(timers, alive, Time.delta);
	moveSnakes(alive, map, stream, config.snakeSize);
	handleCollision(alive, controls, map, stream, timers, scores);

	stream.clear();
}

void render()
{
	renderFrame(renderer, alive);
}

void generateInputEvents(ref List!SnakeControl controls, ref EventStream stream, GLFWwindow* window) // <-- This is wierd and very much not ok.
{
	foreach(c; controls)
	{
		if(glfwGetKey(window, c.leftKey) == GLFW_PRESS)
			stream.push(InputEvent(c.color, Input.Left));
		if(glfwGetKey(window, c.rightKey) == GLFW_PRESS)
			stream.push(InputEvent(c.color, Input.Right));
	}
}

void handleInput(ref List!Snake snakes, ref EventStream stream, float turn)
{
	foreach(event; stream.over!InputEvent)
	{
		auto index = snakes.countUntil!(x => x.color == event.color);
		auto polar = snakes[index].dir.toPolar;

		if(event.input == Input.Left)
			polar.angle += turn;
		else
			polar.angle -= turn;

		snakes[index].dir = polar.toCartesian;
	}
}

void updateTimers(ref List!Timer timers, ref List!Snake snakes, float elapsed)
{
	foreach(ref timer; timers)
	{
		timer.time -= elapsed;
		if(timer.time <= 0.0f)
		{
			auto index = snakes.countUntil!(x => x.color == timer.color);
			swap(snakes[index], snakes[max(0, visibleSnakes - 1)]);
			timer.visible = !timer.visible;
			if(timer.visible)
			{
				timer.time = uniform(config.minVis,config.maxVis);
				visibleSnakes++;
			} 
			else 
			{
				timer.time = uniform(config.minInvis,config.maxInvis);
				visibleSnakes--;
			}
		}
	}
}

void moveSnakes(ref List!Snake snakes, ref Grid!bool map, ref EventStream stream, uint size)
{
	foreach(uint i, ref snake; snakes)	
	{
		auto oldPos = uint2(snake.pos);
		snake.pos += snake.dir;
		auto newPos = uint2(snake.pos);
		if(oldPos != newPos && i < visibleSnakes) 
		{
			auto c = checkCollision(newPos, oldPos, size, map);
			if(c)
			{
				stream.push(CollisionEvent(snake.color, c));
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

void handleCollision(
				 ref List!Snake alive, 
				 ref List!SnakeControl controls,
				 ref Grid!bool map, 
				 ref EventStream stream,
				 ref List!Timer timers,
				 ref List!Score scores)
{
	foreach(collision; stream.over!CollisionEvent)
	{
		if(collision.numPixels < config.snakeSize / 2 + 1) continue;

		assert(alive.remove!(x => x.color    == collision.color));
		assert(controls.remove!(x => x.color == collision.color));
		assert(timers.remove!(x => x.color   == collision.color));
		visibleSnakes--;
		auto toGet = alive.capacity - alive.length;
		size_t index = scores.countUntil!(x => x.color == collision.color);
		scores[index].score += toGet;
		if(alive.length == 1){
			reset();
		}

	}
}

void renderFrame(ref AchtungRenderer buffer, ref List!Snake snakes)
{
	mat4 proj = mat4.CreateOrthographic(0, 800,600,0,1,-1);
	List!Snake visible = snakes[0 .. visibleSnakes];
	buffer.draw(proj, visible, 4);
}

struct Score
{
	Color color;
	int score;
}