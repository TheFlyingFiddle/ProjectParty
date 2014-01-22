module achtung;

import main;
import collections;
import math;
import types;
import better_renderer;
import sdl;
import graphics.color;
import derelict.glfw3.glfw3;
import events;
import std.random;
import logging;
import game.time;
import std.algorithm;

Grid!bool map;
EventStream stream;
AchtungRenderer renderer;

List!Snake alive;
List!Timer timers;
List!SnakeControl controls;
int visibleSnakes, snakeSize;
float minInvis, maxInvis, minVis, maxVis;
float turnSpeed;


void init(Allocator)(ref Allocator allocator, SDLObject config)
{
	auto w = cast(uint)config.map.width.integer,
		h = cast(uint)config.map.height.integer,
		snakeLen = config.snakes.length;

	alive      = List!Snake(allocator, snakeLen);
	timers     = List!Timer(allocator, snakeLen);
	controls   = List!SnakeControl(allocator, snakeLen);

	map		   = Grid!bool(allocator,w,h);
	renderer   = AchtungRenderer(allocator, snakeLen, w, h);
	stream     = EventStream(allocator, 1024);

	minInvis   = config.minInvis.number;
	maxInvis   = config.maxInvis.number;
	minVis     = config.minVis.number;
	maxVis     = config.maxVis.number;
	turnSpeed  = config.turnSpeed.number;
	snakeSize  = cast(uint)config.snakeSize.integer;

	reset(config);
}

void reset(SDLObject config)
{
	alive.clear();
	timers.clear();
	controls.clear();
	stream.clear();

	map.fill(0);
	renderer.clear(Color(1,0,1,0));

	foreach(i; 0 .. alive.capacity)
	{
		Snake snake;
		snake.pos =float2(config.snakes[i].posx.number,
						  config.snakes[i].posy.number);
		snake.dir = float2(config.snakes[i].dirx.number,
						   config.snakes[i].diry.number);
		snake.color    = Color(cast(uint)config.snakes[i].color.number);
		alive ~= snake;

		controls ~= SnakeControl(snake.color, 
								 cast(uint)config.snakes[i].leftKey.number,
								 cast(uint)config.snakes[i].rightKey.number);

		timers ~= Timer(1, snake.color, true);
	}

	visibleSnakes = alive.length;
}

void update()
{
	generateInputEvents(controls, stream, window);
	handleInput(alive, stream, turnSpeed);
	updateTimers(timers, alive, Time.delta);
	moveSnakes(alive, map, stream, snakeSize);
	doGameLogic(alive, controls, map, stream);

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
				timer.time = uniform(minVis,maxVis);
				visibleSnakes++;
			} 
			else 
			{
				timer.time = uniform(minInvis,maxInvis);
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

void doGameLogic(ref List!Snake alive, 
				 ref List!SnakeControl controls,
				 ref Grid!bool map, 
				 ref EventStream stream)
{
	foreach(collision; stream.over!CollisionEvent)
	{
		if(collision.numPixels < snakeSize / 2 + 1) continue;

		assert(alive.remove!(x => x.color    == collision.color));
		assert(controls.remove!(x => x.color == collision.color));
		assert(timers.remove!(x => x.color   == collision.color));
		visibleSnakes--;
	}
}

void renderFrame(ref AchtungRenderer buffer, ref List!Snake snakes)
{
	mat4 proj = mat4.CreateOrthographic(0, 800,600,0,1,-1);
	List!Snake visible = snakes[0 .. visibleSnakes];
	buffer.draw(proj, visible, 4);
}