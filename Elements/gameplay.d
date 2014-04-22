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
import gatling;
import network_types;
import enemy_collection;
import enemy;


struct TowerPlayer
{
	int balance;
	Color color;
}

class GamePlayState : IGameState
{
	FontID lifeFont;

	Level level;
	
	int lifeTotal;
	List!uint2 selections;

	TowerCollection		towerCollection;
	EnemyCollection		enemyCollection;

	
	float towerBreakTimer = 0;
	float towerBreakInterval = 30;


	Table!(ulong, TowerPlayer)	players;

	ParticleSystem particleSystem;
	ParticleCollection particleCollection;

	this(A)(ref A allo, string configFile)
	{
		auto prefabs = fromSDLFile!Prefabs(allo, configFile);

		lifeTotal = 1000;
		selections = List!uint2(allo, 10);
		players = Table!(ulong, TowerPlayer)(allo, 20);	


		import std.algorithm;

		lifeFont = Game.content.loadFont("Blocked72");
		enemyCollection = allo.allocate!EnemyCollection(allo, prefabs.enemyPrototypes);

		allo.allocate!SpeedupEnemyController(allo, enemyCollection);
		allo.allocate!HealerEnemyController(allo, enemyCollection);
		allo.allocate!TowerBreakerEnemyController(allo, enemyCollection);
		allo.allocate!StatusRemoverEnemyController(allo, enemyCollection);

		enemyCollection.onDeath ~= &killEnemy;
		enemyCollection.onAtEnd ~= &enemyAtEnd;
	

		towerCollection = allo.allocate!TowerCollection(allo, prefabs.towers);
		towerCollection.onTowerBroken ~= &sendTowerBrokenMessage;

		particleSystem = allo.allocate!ParticleSystem(allo, Game.content.loadTextureAtlas("particles"), 3000);
		particleCollection = allo.allocate!ParticleCollection(allo, particleSystem, 50);
		particleCollection.scale = Game.window.relativeScale;
		allo.allocate!(ParticleEmitterExtender!ConeEmitter)(allo, particleCollection);

		auto ventController = allo.allocate!VentController(allo, towerCollection, particleCollection);
		VentInstance.prefabs = prefabs.ventPrototypes;
		
		auto ballisticController = allo.allocate!BallisticController(allo, towerCollection, particleCollection);

		BallisticProjectileInstance.prefabs = prefabs.ballisticProjectilePrototypes;
		BallisticInstance.prefabs = prefabs.ballisticTowerPrototypes;

		auto gatlingController = allo.allocate!GatlingController(allo, towerCollection);
		enemyCollection.onDeath ~= &gatlingController.onEnemyDeath;

		AutoProjectileInstance.prefabs = prefabs.autoProjectilePrototypes;
		GatlingInstance.prefabs = prefabs.gatlingTowerPrototypes;

		//Temp music
		Game.sound.playMusic("test.ogg");
	}

	void enter()
	{

		import allocation;
		level = fromSDLFile!Level(GC.it, "level.sdl");
		
		BaseEnemy.paths = level.paths;
		enemyCollection.paths = level.paths;

		towerCollection.tileSize = level.tileSize;

		foreach(player; Game.players)
		{
			connect(player.id);
		}

		Game.router.setMessageHandler(IncomingMessages.towerRequest,	&handleTowerRequest);
		Game.router.setMessageHandler(IncomingMessages.selectRequest,	&handleSelectRequest);
		Game.router.setMessageHandler(IncomingMessages.mapRequest,		&handleMapRequest);
		Game.router.setMessageHandler(IncomingMessages.towerEntered,	&handleTowerEntered);
		Game.router.setMessageHandler(IncomingMessages.towerExited,		&handleTowerExited);
		Game.router.setMessageHandler(IncomingMessages.deselect,		&handleDeselect);
		Game.router.setMessageHandler(IncomingMessages.towerSell,		&handleTowerSell);
		Game.router.setMessageHandler(IncomingMessages.upgradeTower,	&handleTowerUpgrade);
		Game.router.setMessageHandler(IncomingMessages.towerRepaired,	&handleTowerRepaired);

		Game.router.connectionHandlers ~= &connect;
		Game.router.disconnectionHandlers ~= &disconnect;
		Game.router.reconnectionHandlers ~= &reconnect;
	}

	void exit()
	{
		towerCollection.clear();
		enemyCollection.clear();
		players.clear();
		particleCollection.clear();
		

		Game.router.setMessageHandler(IncomingMessages.towerRequest,	null);
		Game.router.setMessageHandler(IncomingMessages.selectRequest,	null);
		Game.router.setMessageHandler(IncomingMessages.mapRequest,		null);
		Game.router.setMessageHandler(IncomingMessages.towerEntered,	null);
		Game.router.setMessageHandler(IncomingMessages.towerExited,		null);
		Game.router.setMessageHandler(IncomingMessages.deselect,		null);
		Game.router.setMessageHandler(IncomingMessages.towerSell,		null);
		Game.router.setMessageHandler(IncomingMessages.upgradeTower,	null);
		Game.router.setMessageHandler(IncomingMessages.towerRepaired,	null);

		Game.router.connectionHandlers.remove(&connect);
		Game.router.disconnectionHandlers.remove(&disconnect);
		Game.router.reconnectionHandlers.remove(&reconnect);

		import core.memory;
		GC.collect();
	}

	ubyte getMetaInfo(ubyte type, ubyte typeIndex) 
	{
		return cast(ubyte)towerCollection.metas.countUntil!(x => x.type == type && x.typeIndex == typeIndex);
	}

	void connect(ulong id) 
	{
		import std.random;
		import std.stdio;
		players[id] = TowerPlayer(0, Color(uniform(0xFF000000, 0xFFFFFFFF)));
		// TODO: People should not be able to connect during gameplay
		Game.server.sendMessage(id, TransitionMessage("GamePlay"));
		sendTransaction(id, level.startBalance);
	}
 
	void reconnect(ulong id)
	{
		auto balance = players[id].balance;
		players[id].balance = 0;
		Game.server.sendMessage(id, TransitionMessage("GamePlay"));
		sendTransaction(id, balance);
	}

	void disconnect(ulong id)
	{
	}

	void sendTransaction(ulong id, int amount)
	{
		TransactionMessage tMsg;
		tMsg.amount = amount;

		Game.server.sendMessage(id, tMsg);
		players[id].balance += amount;

		import std.stdio;
		writeln("Balance: ", players[id].balance);
	}

	void handleTowerRequest(ulong id, ubyte[] msg)
	{			
		auto x = msg.read!uint;
		auto y = msg.read!uint;
		auto type = msg.read!ubyte;
		auto typeIndex = msg.read!ubyte;
	
		auto balance = players[id].balance;
			
		auto metaIndex = getMetaInfo(type, typeIndex);
		if (level.tileMap[uint2(x,y)] == TileType.buildable && 
			balance >= towerCollection.metas[metaIndex].cost) {

			towerCollection.buildTower(float2(x * level.tileSize.x + level.tileSize.x / 2, 
												       y * level.tileSize.y + level.tileSize.y / 2), 
													    metaIndex, id);

			level.tileMap[uint2(x,y)] = cast(TileType) type;
			sendTransaction(id, -towerCollection.metas[metaIndex].cost);

			foreach(player; Game.players)
				Game.server.sendMessage(player.id, 
						TowerBuiltMessage(x, y, type, typeIndex, id == player.id, 
												players[id].color.packedValue));
		}
	}


	void handleTowerEntered(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint;
		auto y = msg.read!uint;
		import std.stdio;
		writeln("HandleTowerEntered");
		auto index = towerCollection.indexOf(uint2(x,y));
		towerCollection.enterTower(index, id);
		foreach(player; Game.players) if (player.id != id)
			Game.server.sendMessage(player.id, TowerEnteredMessage(x, y));
	}

	void handleTowerExited(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint;
		auto y = msg.read!uint;
		auto index = towerCollection.indexOf(uint2(x,y));
		towerCollection.exitTower(index, id);
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

		foreach(i, tower; towerCollection.metas) {
			TowerInfoMessage tiMsg;
			tiMsg.cost = tower.cost;
			tiMsg.range = tower.range;
			tiMsg.type = tower.type;
			tiMsg.phoneIcon = tower.phoneIcon;
			tiMsg.name = tower.name;
			tiMsg.info = tower.info;
			tiMsg.index = tower.typeIndex;
			tiMsg.basic = tower.basic;
			tiMsg.upgradeIndex0 = tower.upgradeIndex0;
			tiMsg.upgradeIndex1 = tower.upgradeIndex1;
			tiMsg.upgradeIndex2 = tower.upgradeIndex2;
			Game.server.sendMessage(id, tiMsg);
		}

		foreach(tower; towerCollection.baseTowers)
		{
			TowerBuiltMessage tbMsg;
			tbMsg.x = tower.cell(level.tileSize).x;
			tbMsg.y = tower.cell(level.tileSize).y;
			tbMsg.towerType	= towerCollection.metas[tower.metaIndex].type;
			tbMsg.typeIndex	= towerCollection.metas[tower.metaIndex].typeIndex;
			tbMsg.ownedByMe = tower.ownedPlayerID == id;
			tbMsg.isBroken = cast(ubyte)tower.isBroken;
			if(players.indexOf(tower.ownedPlayerID) != -1)
				tbMsg.color = players[tower.ownedPlayerID].color.packedValue;
			else 
				tbMsg.color = 0xFF555555;
			Game.server.sendMessage(id, tbMsg);
		}
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


	void handleTowerSell(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint,
			  y = msg.read!uint;

		auto towerIndex = towerCollection.indexOf(uint2(x,y));
		auto meta = towerCollection.metaTower(towerIndex);
		level.tileMap[uint2(x,y)] = TileType.buildable;
		towerCollection.removeTower(towerIndex);
		sendTransaction(id, cast(int)(0.9 * meta.cost));
		
		foreach(player; Game.players)
				Game.server.sendMessage(player.id, TowerSoldMessage(x,y));
	}

	void handleTowerUpgrade(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint,
			 y = msg.read!uint,
		     selectedUpgrade = msg.read!ubyte;

		auto towerIndex = towerCollection.indexOf(uint2(x,y));
		auto meta = towerCollection.metaTower(towerIndex);
		Tower upgradeMeta = towerCollection.metas[selectedUpgrade];

		auto cost = upgradeMeta.cost - meta.cost;
		if(players[id].balance < cost)
			return;

		sendTransaction(id, -cost);
		towerCollection.upgradeTower(towerIndex, selectedUpgrade);

		foreach(player; Game.players)
			Game.server.sendMessage(player.id, TowerSoldMessage(x,y));

		foreach(player; Game.players)
			Game.server.sendMessage(player.id, 
					TowerBuiltMessage(x, y, upgradeMeta.type, upgradeMeta.typeIndex, 
											player.id == id, players[id].color.packedValue));
	}

	void handleTowerRepaired(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint, y = msg.read!uint;
		
		towerCollection.repairTower(towerCollection.indexOf(uint2(x,y)));

		foreach(player; Game.players)
			Game.server.sendMessage(player.id, TowerRepairedMessage(x, y));
	}



	void sendTowerBrokenMessage(TowerCollection collection, uint towerIndex)
	{
		auto c = collection.baseTowers[towerIndex].cell(level.tileSize);
		foreach(player; Game.players)
			Game.server.sendMessage(player.id, TowerBrokenMessage(c.x, c.y));
	}

	void update()
	{
		updateTowerBreaker();


		updateWave();
		enemyCollection.update(towerCollection);
		towerCollection.update(enemyCollection.enemies);
		enemyCollection.killEnemies();
	}

	void updateTowerBreaker()
	{
		towerBreakTimer += Time.delta;
		if(towerBreakTimer >= towerBreakInterval)
		{
			towerBreakTimer -= towerBreakInterval;
			import std.random;
			if(towerCollection.baseTowers.length > 0)
			{
				auto index = uniform(0,  towerCollection.baseTowers.length);
				towerCollection.breakTower(index);
			}
		}
	}

	void updateWave()
	{
		auto enemies = enemyCollection.enemies;
		level.waves[0].elapsed += Time.delta;

		if(level.waves[0].pauseTime < level.waves[0].elapsed) {
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
	}

	private void updateSpawner(ref Spawner spawner)
	{
		spawner.startTime -= Time.delta;
		if (spawner.startTime <= 0) {
			spawner.elapsed += Time.delta;
			if (spawner.elapsed >= spawner.spawnInterval) {
				enemyCollection.addEnemy(enemyCollection.enemyPrototypes[spawner.prototypeIndex], spawner.pathIndex);
				spawner.numEnemies--;
				spawner.elapsed = 0;
			}
		}
	}

	void render()
	{
		Game.renderer.addFrame(level.image, float4(0,0, Game.window.size.x, Game.window.size.y));
		TextureID towerTexture;

		enemyCollection.render();

		towerCollection.render(enemyCollection.enemies);

		mat4 proj = mat4.CreateOrthographic(0, Game.window.fboSize.x, Game.window.fboSize.y, 0, 1, -1);
		gl.blendEquationSeparate(BlendEquation.add, BlendEquation.add);
		gl.blendFuncSeparate(BlendFactor.one, BlendFactor.oneMinusSourceAlpha, 
							 BlendFactor.one, BlendFactor.zero);
		particleSystem.render(proj);

		gl.enable(Capability.blend);
		gl.BlendFunc(BlendFactor.srcAlpha, BlendFactor.oneMinusSourceAlpha);

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

		int timeLeft = cast(int)(level.waves[0].pauseTime - level.waves[0].elapsed + 1);

		if(timeLeft > 0) {
			auto str = text(buffer, "Time until next wave: ", 
							timeLeft);
			float2 size = lifeFont.measure(str);

			Game.renderer.addText(lifeFont, str, 
								  float2(Game.window.size.x - size.x, Game.window.size.y), Color(0x88FFFFFF));
		}
	}

	void enemyAtEnd(EnemyCollection enemies, BaseEnemy enemy, uint i)
	{
		if(--lifeTotal == 0) 
			gameOver();
	}

	void killEnemy(EnemyCollection enemies,  BaseEnemy enemy, uint i)
	{
		foreach(player; Game.players)
		{
			sendTransaction(player.id, enemy.worth / Game.players.length);
		}	
	}

	void gameOver()
	{
		std.c.stdlib.exit(0);
	}
}
