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
import achtung_game_data;

struct AchtungConfig
{
    float minInvis, maxInvis, minVis, maxVis;
    int snakeSize;
	int winningScore;
	uint maxSnakes;
    uint2 maxResolution;
}

class AchtungGameState : IGameState
{
	//This is special. But it works good so why not ? 
	Grid!bool masterMap;

	Grid!bool map;
	EventStream stream;
	AchtungRenderer renderer;

	Table!(ulong) ids;
	Table!(Snake) snakes;
	Table!(float) timers;
    AchtungGameData agd;

	AchtungConfig config;

	this(A)(ref A allocator, string configPath, AchtungGameData agd)
	{
		config     = fromSDLFile!AchtungConfig(allocator, configPath);

		snakes     = Table!(Snake)(allocator, config.maxSnakes);
		timers     = Table!(float)(allocator, config.maxSnakes);
		masterMap  = Grid!bool(allocator, config.maxResolution.x, config.maxResolution.y);
		renderer   = AchtungRenderer(allocator, cast(uint)agd.data.capacity, config.maxResolution.x, config.maxResolution.y);
		stream     = EventStream(allocator, 1024 * 1000);
		this.agd = agd;
	}

	void enter()		
	{
		foreach(ref pd; agd.data)
		{
			pd.score = 0;
		}


		size_t c = Game.players.length;

		map = masterMap.subGrid(Game.window.fboSize.x - 100, Game.window.fboSize.y);

		reset();

		Game.window.onSizeChanged = &sizeChanged;
	}

	void exit()
	{
		Game.window.onFboSizeChanged = null;
	}

	void sizeChanged(int x, int y)
	{
		map = masterMap.subGrid(x - 100, y);
		reset();
	}

	void reset()
	{
		foreach(playerData; agd.data) if(playerData.score > config.winningScore)
		{
			Game.transitionTo("GameOver");
			return;
		}
	
		snakes.clear();
		timers.clear();
		stream.clear();

		map.fill(0);
		renderer.clear(Color(1,0,1,0));

		foreach(playerData; agd.data)
		{
			Snake snake;
			snake.pos = float2(uniform(50, map.width - 50), uniform(50, map.height - 50));
			snake.dir = (float2(map.width / 2, map.height / 2) - snake.pos).normalized;
			snake.visible = true;

			snakes[playerData.color]   = snake;
			timers[playerData.color]   = 1.0f;
		}
	}

	void update()
	{
		generateInputEvents(stream);
		handleInput(snakes, stream);
		updateTimers(timers, snakes, Time.delta);

		moveSnakes(snakes, map, stream, config.snakeSize);
		handleCollision(snakes, timers, map, stream);

		stream.clear();
	}

	void render()
	{
		renderFrame(renderer, snakes);
	}

	void generateInputEvents(ref EventStream stream) // <-- This is wierd and very much not ok.
	{
		foreach(playerData; agd.data)
		{
			if(Phone.exists(playerData.playerId) && snakes.indexOf(playerData.color) != -1)
			{
				PhoneState state = Phone.state(playerData.playerId);
				stream.push(InputEvent(playerData.color, state.accelerometer.y / 50));
			}	
		}
	}

	void handleInput(ref Table!(Snake) snakes, 
					 ref EventStream stream)
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
						foreach(column; 0 .. size) {			
							map[newPos - origin + uint2(column, row)] = true;
						}
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
					count += checkCollision(cell, map);
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

	uint checkCollision(uint2 cell, ref Grid!bool map)
	{
		if(hitWall(cell, map))
			return 1000; //Arbitraty large number.
		else 
			return cast(uint)(map[cell] == true);
	}

	bool hitWall(uint2 position, ref Grid!bool map)
	{
		return position.x >= map.width || 
			   position.y >= map.height; 
	}

	void handleCollision(ref Table!Snake snakes,
					     ref Table!float timers, 
					     ref Grid!bool map, 
					     ref EventStream stream)
	{
		foreach(collision; stream.over!CollisionEvent)
		{
			if(collision.numPixels < config.snakeSize / 2 + 1) continue;

			timers.remove(collision.color);
			snakes.remove(collision.color);

			auto toGet = agd.data.length - snakes.length - 1;

			foreach(ref playerData; agd.data) if(collision.color == playerData.color) {
				playerData.score += toGet;
				sendDeathMessage(playerData.playerId, playerData.score);
			}

			if(snakes.length == 1){
				foreach(ref playerData; agd.data) if(playerData.color == snakes.keys[0])
				{
					playerData.score += agd.data.length -1;
					sendDeathMessage(playerData.playerId, playerData.score);
				}
				reset();
				return;
			}
			
		}
	}

	
	void sendDeathMessage(ulong id, uint score)
	{
		import util.bitmanip;
		ubyte[32] buff = void; auto buffer = buff[0 .. 32];
		size_t offset = 0;

		buffer.write!ushort(ushort.sizeof + ubyte.sizeof, &offset);
		buffer.write!ubyte(AchtungMessages.death, &offset);
		buffer.write!ushort(cast(ushort)score, &offset);

		Game.server.send(id, buffer[0 .. offset]);
	}

	void renderFrame(ref AchtungRenderer buffer,
					 ref Table!Snake snakes)
	{
		import std.stdio;

		gl.clear(ClearFlags.color);
		uint2 s = Game.window.size;
		gl.viewport(0,0, s.x, s.y);
		buffer.draw(snakes, agd, config.snakeSize);
	}

}