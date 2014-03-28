module gameplay;
import game, math, collections, content, graphics;
import derelict.freeimage.freeimage, util.strings;
import game.debuging;
import types;
import network.message;


class GamePlayState : IGameState
{

	FontID lifeFont;
	Grid!TileType tileMap;
	uint2[] path;
	uint2 tileSize;
	List!Enemy enemies;
	List!Wave waves;

	List!Enemy prototypes;
	
	int lifeTotal;
	List!Projectile projectiles;
	List!Tower towers;
	List!uint2 selections;

	List!Status statuses;

	this(A)(ref A allocator, string configFile)
	{
		enemies = List!Enemy(allocator, 100);

		statuses = List!Status(allocator, 1000);

		lifeTotal = 50;
		projectiles = List!Projectile(allocator, 10000);
		towers = List!Tower(allocator, 1000);
		selections = List!uint2(allocator, 10);
		import std.algorithm;
		auto map = fromSDLFile!MapConfig(allocator, configFile);
		path = map.path;

		prototypes = List!Enemy(allocator, map.enemies.length);
		foreach(enemyConfig; map.enemies)
		{
			Enemy enemy;
			enemy.speed = enemyConfig.speed;
			enemy.health = enemyConfig.health;
			enemy.worth = enemyConfig.worth;
			enemy.frame = Frame(Game.content.loadTexture(enemyConfig.textureResource));
			prototypes ~= enemy;
		}

		waves = List!Wave(allocator, map.waves.length);
		foreach (waveConfig; map.waves)
		{
			Wave wave = Wave(List!Spawner(allocator, waveConfig.length));
			foreach (spawnerConfig; waveConfig) {
				Spawner spawner;
				spawner.prototypeIndex = spawnerConfig.prototypeIndex;
				spawner.startTime = spawnerConfig.startTime;
				spawner.spawnInterval = spawnerConfig.spawnInterval;
				spawner.numEnemies = spawnerConfig.numEnemies;
				spawner.elapsed = 0;

				wave.spawners ~= spawner;
			}
			waves ~= wave;
		}

		lifeFont = Game.content.loadFont("Blocked72");

		char* c_path = map.map.toCString();
		FREE_IMAGE_FORMAT format = FreeImage_GetFileType(c_path);
		if(format == FIF_UNKNOWN)
		{
			format = FreeImage_GetFIFFromFilename(c_path);
		}

		FIBITMAP* bitmap = FreeImage_Load(format, c_path, 0);
		scope(exit) FreeImage_Unload(bitmap);

		uint width  = FreeImage_GetWidth(bitmap);
		uint height = FreeImage_GetHeight(bitmap);
		uint bpp    = FreeImage_GetBPP(bitmap);
		uint[] mapBits = (cast(uint*)FreeImage_GetBits(bitmap))[0 .. width * height];

		tileMap = Grid!TileType(allocator, width, height);
		foreach(row; 0 .. height) {
			foreach(col; 0 .. width) {
				uint color = mapBits[row * width + col];
				auto tile  = map.tiles.find!(x => x.color == color);
				if(!tile.length == 0)
					tileMap[uint2(col, row)] = tile[0].type;
			}
		}

		tileSize = map.tileSize;
	}

	void enter()
	{
		Game.router.connectionHandlers ~= &connect;
		Game.router.messageHandlers ~= &handleMessage;
	}

	void connect(ulong playerId)
	{

	}
	
	void handleMessage(ulong playerId, ubyte[] msg)
	{
		import util.bitmanip;
		auto id = msg.read!ubyte;
		if (id == ElementsMessages.towerRequest) {
			auto x = msg.read!uint;
			auto y = msg.read!uint;
			auto type = msg.read!ubyte;
			if (tileMap[uint2(x,y)] == TileType.buildable && 
					towers.countUntil!( tower => tower.position.x == x && tower.position.y == y) == -1) {
				buildTower(uint2(x,y), type);
			}
		} else if (id == ElementsMessages.selectRequest) {
			auto x = msg.read!uint;
			auto y = msg.read!uint;
			auto index = selections.countUntil!(s=> s == uint2(x, y));

			if(index == -1) {
				foreach(player ; Game.players) if (player.id != playerId) 
					Game.server.sendMessage(player.id, SelectedMessage(x, y, 0x88AACCBB));

				selections ~= uint2(x,y);
			}
		} else if (id == ElementsMessages.deselect) {
			auto x = msg.read!uint;
			auto y = msg.read!uint;
			selections.remove(uint2(x,y));

			foreach(player ; Game.players) if (player.id != playerId) 
				Game.server.sendMessage(player.id, DeselectedMessage(x, y));
		} else if (id == ElementsMessages.mapRequest) {
			MapMessage mapmsg;
			mapmsg.width = tileMap.width;
			mapmsg.height = tileMap.height;
			mapmsg.tiles = cast (ubyte[])tileMap.buffer[0 .. tileMap.width * tileMap.height];
			Game.server.sendMessage(playerId, mapmsg);
		}
	}

	void exit()
	{

	}

	void update()
	{
		updateWave();
		updateStatuses();
		updateEnemies();
		updateTowers();
		updateProjectiles();
		killEnemies();
	}

	void updateWave()
	{
		for(int i = waves[0].spawners.length - 1; i >= 0; --i)
		{
			updateSpawner(waves[0].spawners[i]);
			if (waves[0].spawners[i].numEnemies == 0)
				waves[0].spawners.removeAt(i);
		}
		if (waves[0].spawners.length == 0 &&
			enemies.length == 0) {
			if (waves.length > 1)
				waves.removeAt(0);
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
				auto enemy = prototypes[spawner.prototypeIndex];
				enemy.index = 1;
				enemy.pos = float2(tileSize * path[0] + tileSize/2);
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

			float2 targetPosition = float2(path[enemies[i].index].x * tileSize.x + tileSize.x / 2, 
										   path[enemies[i].index].y * tileSize.y + tileSize.y / 2);

			float2 dir = (targetPosition - enemies[i].pos).normalized();

			enemies[i].pos += dir * Time.delta * enemies[i].speed;

			if(distanceSquared(enemies[i].pos, targetPosition) < 2) 
			{
				enemies[i].index += 1;
				if(enemies[i].index == path.length)
				{
					enemies[i].health = 0;
					lifeTotal--;
					if(lifeTotal == 0)
					{
						gameOver();
					}
				}
			}
		}
	}

	void updateTowers()
	{
		foreach(ref tower; towers)
		{
			tower.deltaAttackTime += Time.delta;
			if(tower.deltaAttackTime >= tower.attackSpeed)
			{
				tower.deltaAttackTime -= tower.attackSpeed;
				import std.algorithm;
				auto index = enemies.countUntil!(x => distanceSquared(x.pos, tower.pixelPos(tileSize)) <= tower.range * tower.range);
				
				if(index != -1)
				{
					spawnProjectile(index, tower);	
				}
			}
		}
	}

	void updateProjectiles()
	{
		for(int i =  projectiles.length -1; i >= 0; i--)
		{
			float2 target = enemies[projectiles[i].target].pos;
			float2 dir = (target - projectiles[i].position).normalized();
			projectiles[i].position += dir * Time.delta * 150;
			if(distanceSquared(target, projectiles[i].position) <= 9)
			{
				projectileHit(projectiles[i]);
				projectiles.removeAt(i);
			}
		}
	}

	void updateStatuses()
	{
		for(int i = statuses.length -1; i>= 0; i--)
		{
			statuses[i].elapsed += Time.delta;
			updateStatus(statuses[i]);
			if (statuses[i].elapsed >= statuses[i].duration) {
				statusEnd(statuses[i]);
				statuses.removeAt(i);
			}
		}
	}

	void updateStatus(ref Status status)
	{
		switch (status.type) with (StatusType)
		{
			case fire:
				status.fire.elapsed += Time.delta;
				if (status.duration / status.fire.numTicks < status.fire.elapsed) {
					enemies[status.targetIndex].health -= status.fire.amount;
					status.fire.elapsed = 0;
				}
				break;
			case water:
				break;
			case nature:
				break;
			case wind:
				break;
			default:
				break;
		}
	}

	void statusEnd(Status status)
	{
		final switch (status.type) with (StatusType)
		{
			case ice:
				enemies[status.targetIndex].speed /= status.ice.amount;
				break;
			case fire:
				break;
			case water:
				break;
			case nature:
				break;
			case wind:
				break;
		}
	}
	void render()
	{
		auto imageTex = Game.content.loadTexture("image_map1.png");
		auto imageFrame = Frame(imageTex);
		Game.renderer.addFrame(imageFrame, float4(0,0, 1280, 720));
		
		auto towerTexture = Game.content.loadTexture("tower");
		auto towerFrame = Frame(towerTexture);

		foreach(cell, item; tileMap) 
		{
			if(item < 2) continue;

			Color color;
			final switch(item) with (TileType)
			{
				case buildable: color = Color.green; break;
				case nonbuildable: color = Color.white; break;
				case fireTower: color = Color(0xFF3366FF); break;
				case waterTower: color = Color.blue; break;
				case iceTower: color = Color(0xFFFFCC66); break;
				case lightningTower: color = Color(0xFF00FFFF); break;
				case windTower: color = Color(0xFFCCCCCC); break;
				case natureTower: color = Color.green; break;
			}

			Game.renderer.addFrame(towerFrame,float4(cell.x * tileSize.x, cell.y * tileSize.y, tileSize.x, tileSize.y), color); 
		}


		foreach(ref enemy; enemies)
		{
			Game.renderer.addFrame(enemy.frame, float4(enemy.pos.x - tileSize.x / 4, 
												 enemy.pos.y - tileSize.y / 4,
												 enemy.frame.width, enemy.frame.height));
		}
		import util.strings;
		char[128] buffer;
		Game.renderer.addText(lifeFont, text(buffer, lifeTotal), float2(0,Game.window.size.y), Color(0x88FFFFFF));

		auto projectileTexture = Game.content.loadTexture("towe");
		auto projectileFrame = Frame(projectileTexture);
		foreach(projectile; projectiles)
		{
			Game.renderer.addFrame(projectileFrame, projectile.position, Color.white, float2(3,3));
		}

		auto selectionTexture = Game.content.loadTexture("pixel");
		auto selectionFrame = Frame(selectionTexture);
		foreach(selection; selections) 
		{
			Game.renderer.addFrame(selectionFrame, float4(selection.x * tileSize.x, selection.y * tileSize.y, tileSize.x, tileSize.y), Color(0x55FF0000)); 
		}
	}

	void spawnProjectile(int enemyIndex, Tower tower)
	{
		projectiles ~= Projectile(tower.attackDmg, tower.pixelPos(tileSize), enemyIndex, tower.projectileType);
	}

	void projectileHit(Projectile projectile)
	{
		if(projectile.type == ProjectileType.normal)
		{
			enemies[projectile.target].health -= projectile.attackDmg;
		}

		if((projectile.type & ProjectileType.splash) == ProjectileType.splash)
		{
			immutable radius = tileSize.x * 3;
			foreach(ref enemy; enemies) if(distanceSquared(enemy.pos, projectile.position) < radius * radius)
			{
				enemy.health -= projectile.attackDmg;
			}
		}
		
		if((projectile.type & ProjectileType.slow) == ProjectileType.slow)
		{
			auto index = statuses.countUntil!((x) => x.targetIndex == projectile.target
											  && x.type == StatusType.ice);
			if (index == -1) {
				enemies[projectile.target].speed *= 0.5;
				statuses ~= Status(projectile.target, 5, 0, 
								   StatusType.ice, IceStatus(0.5));
			} else {
				statuses[index].elapsed = 0;
			}
		}

		if((projectile.type & ProjectileType.dot) == ProjectileType.dot)
		{
			auto index = statuses.countUntil!((x) => x.targetIndex == projectile.target
											  && x.type == StatusType.fire);
			if (index == -1) {
				Status s;
				s.targetIndex = projectile.target;
				s.duration = 30;
				s.elapsed = 0;
				s.type = StatusType.fire;
				s.fire = FireStatus(1, 50, 0);
				statuses ~= s;
			} else {
				statuses[index].elapsed = 0;
			}
		}
	}

	void killEnemies()
	{
		for(int i = enemies.length -1; i >= 0; i--)
		{
			if(enemies[i].health <= 0)
			{
				enemies.removeAt(i);
				for(int j = projectiles.length -1; j >= 0; j--)
				{
					if(projectiles[j].target == i)
					{
						projectiles.removeAt(j);
					}
					else if(projectiles[j].target > i)
					{
						projectiles[j].target--;
					}
				}
				for(int j = statuses.length -1; j >= 0; j--)
				{
					if(statuses[j].targetIndex == i)
					{
						statuses.removeAt(j);
					}
					else if(statuses[j].targetIndex > i)
					{
						statuses[j].targetIndex--;
					}
				}
			}
		}
	}

	void buildTower(uint2 pos, ubyte type) 
	{
		int projectileType;

		switch(type) with (TileType)
		{
			case fireTower: 
				projectileType = ProjectileType.dot;
			break;
			case waterTower:
				projectileType = ProjectileType.splash;
			break;
			case iceTower:
				projectileType = ProjectileType.slow;
			break;
			default:
				projectileType = ProjectileType.normal;
			break;
		}

		towers ~= Tower(175, 7, projectileType, 1, 0, 0, pos);
		foreach(player; Game.players)
			Game.server.sendMessage(player.id, TowerBuiltMessage(pos.x, pos.y, type));

		tileMap[pos] = cast(TileType)type;
	}

	void gameOver()
	{
		std.c.stdlib.exit(0);
	}
}