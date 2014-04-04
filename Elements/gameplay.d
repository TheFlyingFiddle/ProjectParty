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
import tower_controller;
import ballistic;


class GamePlayState : IGameState
{
	Level level;

	FontID lifeFont;
	List!Enemy enemies;

	int lifeTotal;
	List!uint2 selections;

	TowerCollection towerCollection;
	VentController ventController;
	BallisticController ballisticController;

	Table!(ulong, int)balances;

	this(A)(ref A allocator, string configFile)
	{
		lifeTotal = 1000;
		enemies = List!Enemy(allocator, 100);
		selections = List!uint2(allocator, 10);
		balances = Table!(ulong, int)(allocator, 10);
		towerCollection = TowerCollection(allocator);

		import std.algorithm;

		lifeFont = Game.content.loadFont("Blocked72");
		level = fromSDLFile!Level(allocator, configFile);
		Enemy.paths = level.paths;

		ventController = new VentController(allocator);
		VentInstance.prototypes = level.ventPrototypes;
		

		ballisticController = new BallisticController(allocator);
		HomingProjectileInstance.prefabs = level.homingPrototypes;
		BallisticProjectileInstance.prefabs = level.ballisticProjectilePrototypes;
		BallisticInstance.prefabs = level.ballisticTowerPrototypes;


		towerCollection.add(ventController);
		towerCollection.add(ballisticController);
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
		Game.router.setMessageHandler(IncomingMessages.towerSell, &handleTowerSell);
		Game.router.setMessageHandler(IncomingMessages.ballisticValue, &handleBallisticValue);
		Game.router.setMessageHandler(IncomingMessages.ballisticDirection, &handleBallisticDirection);
		Game.router.setMessageHandler(IncomingMessages.ballisticLaunch, &handleBallisticLaunch);
		Game.router.setMessageHandler(IncomingMessages.upgradeTower, &handleTowerUpgrade);
		Game.router.setMessageHandler(IncomingMessages.towerRepaired, &handleTowerRepaired);

		Game.router.connectionHandlers ~= &connect;
		Game.router.disconnectionHandlers ~= &disconnect;
	}

	Tower getMetaInfo(ubyte type, ubyte typeIndex) 
	{
		return level.towers.find!(x => x.type == type && x.typeIndex == typeIndex)[0];
	}

	void sendTransaction(ulong id, int amount)
	{
		TransactionMessage tMsg;
		tMsg.amount = amount;

		Game.server.sendMessage(id, tMsg);
		balances[id] += amount;
	}

	void connect(ulong id) 
	{
		balances[id] = level.startBalance;
		sendTransaction(id, level.startBalance);
	}

	void disconnect(ulong id)
	{
		balances.remove(id);
	}

	void handleTowerRequest(ulong id, ubyte[] msg)
	{			
		auto x = msg.read!uint;
		auto y = msg.read!uint;
		auto type = msg.read!ubyte;
		auto typeIndex = msg.read!ubyte;

		auto meta = getMetaInfo(type, typeIndex);
		if (level.tileMap[uint2(x,y)] == TileType.buildable && 
			balances[id] >= meta.cost) {

			towerCollection.buildTower(float2(x * level.tileSize.x + level.tileSize.x / 2, 
												       y * level.tileSize.y + level.tileSize.y / 2), 
													    type, typeIndex, id);

			level.tileMap[uint2(x,y)] = cast(TileType) type;
			sendTransaction(id, -meta.cost);

			foreach(player; Game.players)
				Game.server.sendMessage(player.id, TowerBuiltMessage(x, y, type, typeIndex, id == player.id));
		}
	}


	void handleTowerEntered(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint;
		auto y = msg.read!uint;
		towerCollection.towerEntered(uint2(x,y), level.tileSize, id);
		foreach(player; Game.players) if (player.id != id)
			Game.server.sendMessage(player.id, TowerEnteredMessage(x, y));
	}

	void handleTowerExited(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint;
		auto y = msg.read!uint;
		towerCollection.towerExited(uint2(x,y), level.tileSize, id);
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

		foreach(i, tower; level.towers) {
			TowerInfoMessage tiMsg;
			tiMsg.cost = tower.cost;
			tiMsg.range = tower.range;
			tiMsg.type = tower.type;
			tiMsg.phoneIcon = tower.phoneIcon;
			tiMsg.color = tower.color;
			tiMsg.index = tower.typeIndex;
			tiMsg.upgradeIndex = tower.upgradeIndex;
			Game.server.sendMessage(id, tiMsg);
		}

		towerCollection.forEachTower((tower, type, typeIndex)
		{
			TowerBuiltMessage tbMsg;
			tbMsg.x = tower.cell(level.tileSize).x;
			tbMsg.y = tower.cell(level.tileSize).y;
			tbMsg.towerType	= type;
			tbMsg.typeIndex	= typeIndex;
			tbMsg.ownedByMe = tower.ownedPlayerID == id;
			Game.server.sendMessage(id, tbMsg);
		});
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

		auto index = ventController.towerIndex(uint2(x,y), level.tileSize);
		if(index != -1)
			ventController.instances[index].open = value;
	}

	void handleVentDirection(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint;
		auto y = msg.read!uint;
		auto value = msg.read!float;

		auto index = ventController.towerIndex(uint2(x,y), level.tileSize);
		if(index != -1)
			ventController.instances[index].direction = value;
	}

	void handleBallisticValue(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint;
		auto y = msg.read!uint;
		auto value = msg.read!float;

		auto index = ballisticController.towerIndex(uint2(x,y), level.tileSize);
		if(index != -1)
		{
			auto distance = ballisticController.instances[index].maxDistance * value;
			ballisticController.instances[index].distance = distance;
		}
	}

	void handleBallisticDirection(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint;
		auto y = msg.read!uint;
		auto value = msg.read!float;

		auto index = ballisticController.towerIndex(uint2(x,y), level.tileSize);
		if(index != -1)
			ballisticController.instances[index].angle = value;
	}	
	
	void handleBallisticLaunch(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint;
		auto y = msg.read!uint;

		auto index = ballisticController.towerIndex(uint2(x,y), level.tileSize);
		if(index != -1)
			ballisticController.launch(index);
	}

	void handleTowerSell(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint,
			  y = msg.read!uint;

		auto meta = towerCollection.metaTower(uint2(x,y), level.tileSize, level.towers);
		level.tileMap[uint2(x,y)] = TileType.buildable;
		towerCollection.removeTower(uint2(x,y), level.tileSize);
		sendTransaction(id, cast(int)(0.9 * meta.cost));
		
		foreach(player; Game.players)
				Game.server.sendMessage(player.id, TowerSoldMessage(x,y));
	}

	void handleTowerUpgrade(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint,
			y = msg.read!uint;

		auto meta = towerCollection.metaTower(uint2(x,y), level.tileSize, level.towers);
		if(meta.upgradeIndex == ubyte.max)
			return;

		auto upgradeMeta = level.towers[meta.upgradeIndex];
		auto cost = upgradeMeta.cost - meta.cost;
		if(balances[id] < cost)
			return;

		sendTransaction(id, -cost);
		towerCollection.upgradeTower(uint2(x,y), level.tileSize, upgradeMeta.typeIndex);

		foreach(player; Game.players)
			Game.server.sendMessage(player.id, TowerSoldMessage(x,y));

		foreach(player; Game.players)
			Game.server.sendMessage(player.id, TowerBuiltMessage(x, y, upgradeMeta.type, upgradeMeta.typeIndex, player.id == id));
	}

	void handleTowerRepaired(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint, y = msg.read!uint;
		
		towerCollection.repairTower(uint2(x,y), level.tileSize);

		foreach(player; Game.players)
			Game.server.sendMessage(player.id, TowerRepairedMessage(x, y));
	}

	void sendTowerBroke(uint2 towerCell)
	{
		foreach(player; Game.players)
			Game.server.sendMessage(player.id, TowerBrokenMessage(towerCell.x, towerCell.y));
	}

	void exit()
	{

	}

	void update()
	{
		updateWave();
		updateEnemies();
		towerCollection.update(enemies);
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
		}

		foreach(ref enemy; enemies)
		{
			float2 position = enemy.position;
			float2 origin = float2(enemy.frame.width/2, enemy.frame.height/2);
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
		ballisticController.render(Game.renderer, float2(level.tileSize), enemies);
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
		foreach(player; Game.players)
		{
			sendTransaction(player.id, enemies[i].worth / Game.players.length);
		}	

		enemies.removeAt(i);

		for (int j = ballisticController.homingProjectiles.length - 1; j >= 0; j--)
		{
			if(ballisticController.homingProjectiles[j].targetIndex == i)
			{
				auto nearest = findNearestEnemy(enemies, ballisticController.homingProjectiles[j].position);
				if(nearest == -1)
					ballisticController.homingProjectiles.removeAt(j);
				else
					ballisticController.homingProjectiles[j].targetIndex = nearest;
			} 
			else if(ballisticController.homingProjectiles[j].targetIndex > i)
			{
				ballisticController.homingProjectiles[j].targetIndex--;
			}
		}
	}

	void gameOver()
	{
		std.c.stdlib.exit(0);
	}
}

int findNearestEnemy(ref List!Enemy enemies, float2 position)
{
	int index = -1;
	auto lowestDistance = float.max;

	foreach(i, ref enemy; enemies)
	{
		float distance = distance(enemy.position, position);

		if(index == -1 || distance < lowestDistance)
		{
			index = i;
			lowestDistance = distance;
		}

	}
	return index;
}

int findFarthestReachableEnemy(List!Enemy enemies, float2 towerPos, float range)
{
	auto index = -1;
	
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

int findNearestReachableEnemy(List!Enemy enemies, float2 towerPos, float range)
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
