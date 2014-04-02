module gameplay;
import std.math;
import std.algorithm;
import game, math, collections, content, graphics;
import derelict.freeimage.freeimage, util.strings;
import game.debuging;
import types;
import network.message;
import util.bitmanip;
import vent;


class GamePlayState : IGameState
{
	Level level;

	FontID lifeFont;
	List!Enemy enemies;

	int lifeTotal;
	List!uint2 selections;

	VentController ventController;


	this(A)(ref A allocator, string configFile)
	{
		lifeTotal = 1000;
		enemies = List!Enemy(allocator, 100);
		selections = List!uint2(allocator, 10);

		import std.algorithm;


		lifeFont = Game.content.loadFont("Blocked72");

		level = fromSDLFile!Level(allocator, configFile);
		Enemy.paths = level.paths;
		ventController = VentController(allocator);
		VentInstance.prototypes = level.ventPrototypes;
		
		ventController.instances ~= VentInstance(float2(100,100), 0);
		level.tileMap[ventController.instances[0].cell(level.tileSize)] = cast(TileType)2;
	}

	void enter()
	{
		Game.router.setMessageHandler(IncomingMessages.towerRequest, &handleTowerRequest);
		Game.router.setMessageHandler(IncomingMessages.selectRequest, &handleSelectRequest);
		Game.router.setMessageHandler(IncomingMessages.mapRequest, &handleMapRequest);
		Game.router.setMessageHandler(IncomingMessages.towerEntered, &handleTowerEntered);
		Game.router.setMessageHandler(IncomingMessages.towerExited, &handleTowerExited);
		Game.router.setMessageHandler(IncomingMessages.deselect, &handleDeselect);
		Game.router.setMessageHandler(IncomingMessages.ventValue, &handleVentValue);
		Game.router.setMessageHandler(IncomingMessages.ventDirection, &handleVentDirection);
	}

	void handleTowerRequest(ulong id, ubyte[] msg)
	{			
		auto x = msg.read!uint;
		auto y = msg.read!uint;
		auto type = msg.read!ubyte;
		auto typeIndex = msg.read!ubyte;
		if (level.tileMap[uint2(x,y)] == TileType.buildable) {
			buildTower(float2(x * level.tileSize.x + level.tileSize.x / 2, 
							  y * level.tileSize.y + level.tileSize.y / 2), 
						type, typeIndex);
			level.tileMap[uint2(x,y)] = cast(TileType) type;

			foreach(player; Game.players)
			{
				Game.server.sendMessage(player.id, TowerBuiltMessage(x, y, type));
			}
		}
	}

	void buildTower(float2 position, ubyte towerType, ubyte towerTypeIndex)
	{
		ventController.instances ~= VentInstance(position, towerTypeIndex);
	}

	void handleTowerEntered(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint;
		auto y = msg.read!uint;

		foreach(player; Game.players) if (player.id != id)
			Game.server.sendMessage(player.id, TowerEnteredMessage(x, y));
	}

	void handleTowerExited(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint;
		auto y = msg.read!uint;

		foreach(player; Game.players) if (player.id != id)
			Game.server.sendMessage(player.id, TowerExitedMessage(x, y));
	}


	void handleMapRequest(ulong id, ubyte[] msg)
	{
		MapMessage mapmsg;
		mapmsg.width = level.tileMap.width;
		mapmsg.height = level.tileMap.height;
		mapmsg.tiles = cast (ubyte[])level.tileMap.buffer[0 .. level.tileMap.width * level.tileMap.height];
		Game.server.sendMessage(id, mapmsg);
	}

	void handleSelectRequest(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint;
		auto y = msg.read!uint;
		auto index = selections.countUntil!(s=> s == uint2(x, y));

		if(index == -1) {
			foreach(player ; Game.players) if (player.id != id) 
				Game.server.sendMessage(player.id, SelectedMessage(x, y, 0x88AACCBB));

			selections ~= uint2(x,y);
		}
	}

	void handleDeselect(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint;
		auto y = msg.read!uint;
		selections.remove(uint2(x,y));

		foreach(player ; Game.players) if (player.id != id) 
			Game.server.sendMessage(player.id, DeselectedMessage(x, y));
	}

	void handleVentValue(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint;
		auto y = msg.read!uint;
		auto value = msg.read!float;

		auto index = ventController.instances.countUntil!(v=>v.cell(level.tileSize) == uint2(x,y));
		if(index != -1)
		{
			ventController.instances[index].open = value;
		}
	}

	void handleVentDirection(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint;
		auto y = msg.read!uint;
		auto value = msg.read!float;

		auto index = ventController.instances.countUntil!(v=>v.cell(level.tileSize) == uint2(x,y));
		if(index != -1)
		{
			ventController.instances[index].direction = value;
		}
	}




	void exit()
	{

	}

	void update()
	{
		updateWave();
		updateEnemies();
		ventController.update(enemies);
		killEnemies();
	}

	void updateWave()
	{
		for(int i = level.waves[0].spawners.length - 1; i >= 0; --i)
		{
			updateSpawner(level.waves[0].spawners[i]);
			if (level.waves[0].spawners[i].numEnemies == 0)
				level.waves[0].spawners.removeAt(i);
		}
		if (level.waves[0].spawners.length == 0 &&
			enemies.length == 0) {
			if (level.waves.length > 1)
				level.waves.removeAt(0);
			else
				gameOver();
		}
			
	}

	private void updateSpawner(ref Spawner spawner)
	{
		spawner.startTime -= Time.delta;
		if (spawner.startTime <= 0) {
			spawner.elapsed += Time.delta;
			if (spawner.elapsed >= spawner.spawnInterval) {
				auto enemy = Enemy(level.enemyPrototypes[spawner.prototypeIndex], spawner.pathIndex);
				enemies ~= enemy;
				spawner.numEnemies--;
				spawner.elapsed = 0;
			}
		}
	}

	void updateEnemies()
	{
		for (int i = enemies.length -1; i >=0; i--)
		{
			enemies[i].distance += enemies[i].speed * Time.delta;
			if (enemies[i].distance < 0)
				enemies[i].distance = 0;
			if (enemies[i].distance > level.paths[enemies[i].pathIndex].endDistance)
			{
				lifeTotal--;
				killEnemy(i);
				if(lifeTotal == 0)
				{
					gameOver();
				}
			}
		}
	}

	int findFarthestReachableEnemy(float2 towerPos, float range)
	{
		int index = -1;
		foreach(i, ref enemy; enemies)
		{
			float distance = distance(enemy.position, towerPos);
			if (distance <= range)
			{
				if(index == -1)
					index = i;
				else if (enemy.distance > enemies[index].distance)
					index = i;
			}
		}
		return index;
	}

	int findNearestReachableEnemy(float2 towerPos, float range)
	{
		int index = -1;
		float lowestDistance = float.infinity;
		foreach(i, ref enemy; enemies)
		{
			float distance = distance(enemy.position, towerPos);
			if (distance <= range)
			{
				if(index == -1)
				{
					index = i;
					lowestDistance = distance;
				}
				else if (distance < lowestDistance)
				{
					index = i;
					lowestDistance = distance;
				}
			}
		}
		return index;
	}

	void render()
	{
		auto imageTex = Game.content.loadTexture("map2.png");
		auto imageFrame = Frame(imageTex);
		Game.renderer.addFrame(imageFrame, float4(0,0, Game.window.size.x, Game.window.size.y));
		TextureID towerTexture;

		
		foreach(ref enemy; enemies)
		{
			float2 position = enemy.position;
			float2 origin = float2(enemy.frame.width/2, enemy.frame.height/2);
			Game.renderer.addFrame(enemy.frame, float4(position.x, 
												 position.y,
												 enemy.frame.width, enemy.frame.height),
												 Color.white, origin);
			float amount = enemy.health/enemy.maxHealth;
			float hBWidth = min(50, enemy.maxHealth);
			Game.renderer.addRect(float4(position.x - hBWidth/2, position.y + enemy.frame.height/2, 
										hBWidth, 5), Color.red);
			Game.renderer.addRect(float4(position.x - hBWidth/2, position.y + enemy.frame.height/2, 
										hBWidth*amount, 5), Color.green);
		}

		import util.strings;
		char[128] buffer;
		Game.renderer.addText(lifeFont, text(buffer, lifeTotal), float2(0,Game.window.size.y), Color(0x88FFFFFF));

		auto selectionTexture = Game.content.loadTexture("pixel");
		auto selectionFrame = Frame(selectionTexture);
		foreach(selection; selections) 
		{
			Game.renderer.addFrame(selectionFrame, 
						float4(selection.x * level.tileSize.x, selection.y * level.tileSize.y, level.tileSize.x, level.tileSize.y), Color(0x55FF0000)); 
		}

		ventController.render(Game.renderer, float2(level.tileSize));
	}

	void killEnemies()
	{
		for(int i = enemies.length -1; i >= 0; i--)
		{
			if(enemies[i].health <= 0)
			{
				killEnemy(i);
			}
		}
	}

	void killEnemy(uint i)
	{
		enemies.removeAt(i);

	}

	void gameOver()
	{
		std.c.stdlib.exit(0);
	}
}