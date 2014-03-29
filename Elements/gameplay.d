module gameplay;
import std.math;
import std.algorithm;
import game, math, collections, content, graphics;
import derelict.freeimage.freeimage, util.strings;
import game.debuging;
import types;
import network.message;


class GamePlayState : IGameState
{

	FontID lifeFont;
	Grid!TileType tileMap;
	Path path;
	uint2 tileSize;
	List!Enemy enemies;
	List!Wave waves;

	List!Enemy enemyPrototypes;
	List!Status statusPrototypes;
	List!Projectile projectilePrototypes;
	List!Tower towerPrototypes;
	
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
		tileSize = map.tileSize;
		path = Path(allocator, tileSize, map.path);


		enemyPrototypes = List!Enemy(allocator, map.enemies.length);
		foreach(enemyConfig; map.enemies)
		{
			Enemy enemy;
			enemy.speed = enemyConfig.speed;
			enemy.maxHealth = enemyConfig.health;
			enemy.health = enemy.maxHealth;
			enemy.worth = enemyConfig.worth;
			enemy.frame = Frame(Game.content.loadTexture(enemyConfig.textureResource));
			enemyPrototypes ~= enemy;
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

		statusPrototypes = List!Status(allocator, map.statuses.length);
		foreach(s; map.statuses)
		{
			Status status;
			status.duration = s.duration;
			status.elapsed = 0;
			status.type = s.type;
			switch (status.type) with (ElementType)
			{
				case fire:
					status.fire.amount = s.common1;
					status.fire.numTicks = cast(int)s.common2;
					status.fire.elapsed = 0;
					break;
				case nature:
					status.nature.amount = s.common1;
					break;
				case lightning:
					status.lightning.jumpDistance = s.common1;
					status.lightning.damage = s.common2;
					status.lightning.reduction = s.common3;
					break;
				case wind:
					status.wind.speed = s.common1;
					break;
				default:
					break;
			}
			statusPrototypes ~= status;
		}

		projectilePrototypes = List!Projectile(allocator, map.projectiles.length);
		foreach(p; map.projectiles)
		{
			projectilePrototypes ~= p;
		}

		towerPrototypes = List!Tower(allocator, map.towers.length);
		foreach(t; map.towers)
		{
			Tower tower;
			tower.range = t.range;
			tower.cost = t.cost;
			tower.type = t.type;
			switch(tower.type) with (TowerType)
			{
				case projectile:
					tower.pTower.attackSpeed = t.common1;
					tower.pTower.deltaAttackTime = 0;
					tower.pTower.projectileIndex = t.common3;
					break;
				case cone:
					tower.cTower.width = t.common1;
					tower.cTower.dps = t.common2;
					tower.cTower.statusIndex = t.common3;
					tower.cTower.reactivationTime = t.common4;
					tower.cTower.activeTime = t.common5;
					tower.cTower.elapsed = 0;
					break;
				case effect:
					tower.eTower.attackSpeed = t.common1;
					tower.eTower.deltaAttackTime = 0;
					tower.eTower.statusIndex = t.common3;
					tower.eTower.damage = t.common4;
					break;
			}
			towerPrototypes ~= tower;
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
				auto enemy = enemyPrototypes[spawner.prototypeIndex];
				enemy.distance = 0;
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
			if (enemies[i].distance > path.endDistance)
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

	void updateTowers()
	{
		foreach(ref tower; towers)
		{
			final switch(tower.type) with (TowerType)
			{
				case projectile:
					updatePTower(tower);
					break;
				case cone:
					updateCTower(tower);
					break;
				case effect:
					updateETower(tower);
					break;
			}
		}
	}

	int findFarthestReachableEnemy(float2 towerPos, float range)
	{
		int index = -1;
		foreach(i, ref enemy; enemies)
		{
			float distance = distance(path.position(enemy.distance), towerPos);
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
			float distance = distance(path.position(enemy.distance), towerPos);
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

	void updatePTower(ref Tower tower)
	{
		tower.pTower.deltaAttackTime += Time.delta;
		if(tower.pTower.deltaAttackTime >= tower.pTower.attackSpeed)
		{
			tower.pTower.deltaAttackTime -= tower.pTower.attackSpeed;
			float2 towerPos = tower.pixelPos(tileSize);
			int index = findFarthestReachableEnemy(towerPos, tower.range);
		
			if(index != -1)
			{
				spawnProjectile(index, tower);	
			}
		}
	}

	void updateCTower(ref Tower tower)
	{
		tower.cTower.elapsed += Time.delta;
		if ( tower.cTower.elapsed < tower.cTower.activeTime)
		{
			float2 towerPos = tower.pixelPos(tileSize);
			int index = findNearestReachableEnemy(towerPos, tower.range);
			if(index != -1)
			{
				auto angle = (towerPos - path.position(enemies[index].distance)).toPolar.angle;
				foreach(i, ref enemy; enemies) if(distance(towerPos, path.position(enemy.distance)) < tower.range)
				{
					auto eAngle = (towerPos - path.position(enemy.distance)).toPolar.angle;
					if(eAngle > (angle - tower.cTower.width/2)%TAU && eAngle < (angle + tower.cTower.width/2)%TAU)
					{
						enemy.health -= tower.cTower.dps * Time.delta;
						addStatus(tower.cTower.statusIndex, i);
					}
				}
			}
		} else if ( tower.cTower.elapsed > tower.cTower.reactivationTime) {
			tower.cTower.elapsed = 0;
		}
			
	}

	void updateETower(ref Tower tower)
	{
		tower.eTower.deltaAttackTime += Time.delta;
		if (tower.eTower.deltaAttackTime >= tower.eTower.attackSpeed)
		{
			tower.eTower.deltaAttackTime = 0;
			auto index = findFarthestReachableEnemy(tower.pixelPos(tileSize), tower.range);
			if (index != -1)
			{
				addStatus(tower.eTower.statusIndex, index);
				enemies[index].health -= tower.eTower.damage;
			}
		}
	}
	void updateProjectiles()
	{
		for(int i =  projectiles.length -1; i >= 0; i--)
		{
			float2 target = path.position(enemies[projectiles[i].target].distance);
			float2 dir = (target - projectiles[i].position).normalized();
			projectiles[i].position += dir * Time.delta * 300;
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
		switch (status.type) with (ElementType)
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
		final switch (status.type) with (ElementType)
		{
			case ice:
				enemies[status.targetIndex].speed = status.ice.previousSpeed;
				break;
			case fire:
				break;
			case water:
				break;
			case nature:
				enemies[status.targetIndex].speed /= status.nature.amount;
				break;
			case lightning:
				enemies[status.targetIndex].health -= status.lightning.damage;
				status.lightning.damage *= status.lightning.reduction;
				if (status.lightning.damage < 1 )
					return;
				status.elapsed = 0;
				foreach(i, enemy; enemies) if ( distance(path.position(enemy.distance),
														 path.position(enemies[status.targetIndex].distance))
													<	status.lightning.jumpDistance)
				{
					auto sIndex = statuses.countUntil!(x => x.targetIndex == i 
													   && x.type == ElementType.water
													   && x.targetIndex != status.targetIndex);
					if (sIndex != -1)
					{
						status.targetIndex = i;
						statuses[sIndex] = status;
						return;
					}
				}
				break;
			case wind:
				enemies[status.targetIndex].speed = status.wind.previousSpeed;
				break;
		}
	}
	void render()
	{
		auto imageTex = Game.content.loadTexture("image_map1.png");
		auto imageFrame = Frame(imageTex);
		Game.renderer.addFrame(imageFrame, float4(0,0, 1280, 720));
		
		TextureID towerTexture;

		foreach(cell, item; tileMap) 
		{
			if(item < 2) continue;
			Tower t = towerPrototypes[item - 2];
			final switch (t.type) with (TowerType)
			{
				case projectile:
					towerTexture = Game.content.loadTexture("tower");
					break;
				case cone:
					towerTexture = Game.content.loadTexture("tower_cone");
					break;
				case effect:
					towerTexture = Game.content.loadTexture("tower_effect");
					break;
			}
			auto towerFrame = Frame(towerTexture);

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
			float2 position = path.position(enemy.distance);
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

		foreach(status; statuses)
		{
			auto enemy = enemies[status.targetIndex];
			auto pos = path.position(enemy.distance);
			switch(status.type) with (ElementType)
			{
				case ice:
					Game.renderer.addCircleOutline(pos, max(enemy.frame.width, enemy.frame.height)/2, Color.white);
					break;
				case fire:
					Game.renderer.addCircleOutline(pos, max(enemy.frame.width, enemy.frame.height)/2, Color.red);
					break;
				case water:
					Game.renderer.addCircleOutline(pos, max(enemy.frame.width, enemy.frame.height)/2, Color.blue);
					break;
				case lightning:
					Game.renderer.addCircleOutline(pos, max(enemy.frame.width, enemy.frame.height)/2, Color(0xFF00FFFF));
					break;
				case wind:
					Game.renderer.addCircleOutline(pos, max(enemy.frame.width, enemy.frame.height)/2, Color.black);
					break;
				case nature:
					Game.renderer.addCircleOutline(pos, max(enemy.frame.width, enemy.frame.height)/2, Color.green);
					break;

				default:
					break;
			}
		}
		import util.strings;
		char[128] buffer;
		Game.renderer.addText(lifeFont, text(buffer, lifeTotal), float2(0,Game.window.size.y), Color(0x88FFFFFF));

		auto projectileTexture = Game.content.loadTexture("projectile");
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

		auto coneTexture = Game.content.loadTexture("cone");
		auto coneFrame = Frame(coneTexture);
		foreach(tower; towers) if (tower.type == TowerType.cone)
		{		
			if ( tower.cTower.elapsed < tower.cTower.activeTime)
			{
				auto index = findNearestReachableEnemy(tower.pixelPos(tileSize), tower.range);
				if (index != -1)
				{

					Color color;
					final switch(statusPrototypes[tower.cTower.statusIndex].type) with (ElementType)
					{
						case fire: color = Color(0xFF3366FF); break;
						case water: color = Color.blue; break;
						case ice: color = Color(0xFFFFCC66); break;
						case lightning: color = Color(0xFF00FFFF); break;
						case wind: color = Color(0xFFCCCCCC); break;
						case nature: color = Color.green; break;
					}
					auto towerPos = tower.pixelPos(tileSize),
						 enemyPos = path.position(enemies[index].distance);
					auto polar = (enemyPos - towerPos).toPolar;
					auto angle = polar.angle;
					auto origin = float2(0, coneFrame.height/2);
					Game.renderer.addFrame(coneFrame, towerPos, 
							color, float2(tower.range, coneFrame.height), origin, angle);
				}
			}
		}
	}

	void spawnProjectile(int enemyIndex, Tower tower)
	{
		Projectile projectile = projectilePrototypes[tower.pTower.projectileIndex];
		projectile.target = enemyIndex;
		projectile.position = tower.pixelPos(tileSize);
		projectiles ~= projectile;
	}

	void projectileHit(Projectile projectile)
	{
		if(projectile.type == ProjectileType.normal)
		{
			enemies[projectile.target].health -= projectile.attackDmg;
		
			addStatus(projectile.statusIndex, projectile.target);
		}

		if((projectile.type & ProjectileType.splash) == ProjectileType.splash)
		{
			immutable radius = tileSize.x * 3;
			foreach(i, ref enemy; enemies) if(distanceSquared(path.position(enemy.distance), projectile.position) < radius * radius)
			{
				enemy.health -= projectile.attackDmg;
				addStatus(projectile.statusIndex, i);
			}
		}
	}

	void addStatus(uint statusIndex, uint enemyIndex)
	{
		auto status = statusPrototypes[statusIndex];
		status.targetIndex = enemyIndex;
		auto index = statuses.countUntil!((x) => x.targetIndex == enemyIndex);
		if (index == -1) {
			applyStatus(status);
		} else {
			changeStatus(status, index);
		}
	}

	void applyStatus(ref Status status)
	{
		final switch(status.type) with (ElementType)
		{
			case fire: case water:
				break;
			case lightning:
				return;
			case ice:
				status.ice.previousSpeed = enemies[status.targetIndex].speed;
				enemies[status.targetIndex].speed = 0;
				break;
			case wind:
				status.wind.previousSpeed = enemies[status.targetIndex].speed;
				enemies[status.targetIndex].speed = -status.wind.speed;
				break;
			case nature:
				enemies[status.targetIndex].speed *= status.nature.amount;
				break;
		}
		statuses ~= status;
	}

	void changeStatus(ref Status status, uint currentStatusIndex)
	{
		Status currentStatus = statuses[currentStatusIndex];
		switch(status.type) with (ElementType)
		{
			case wind:
				if (currentStatus.type == ElementType.wind)
					statuses[currentStatusIndex].elapsed = 0;
				else
					applyStatus(status);
				break;
			case fire:
				switch(currentStatus.type)
				{
					case fire:
						statuses[currentStatusIndex].elapsed = 0;
						break;
					case water: case ice:
						statusEnd(currentStatus);
						statuses.removeAt(currentStatusIndex);
						break;
					case nature:
						statusEnd(currentStatus);
						status.fire.amount *= 2;
						statuses[currentStatusIndex] = status;
						break;
					default:
						applyStatus(status);
						break;
				}
				break;
			case lightning:
				if (currentStatus.type == ElementType.water)
				{
					statuses[currentStatusIndex] = status;
				}
				break;
			case nature:
				if (currentStatus.type == ElementType.fire || 
					currentStatus.type == ElementType.nature)
				{
					statuses[currentStatusIndex].elapsed = 0;
				} 
				else
				{
					statusEnd(statuses[currentStatusIndex]);
					statuses.removeAt(currentStatusIndex);
					applyStatus(status);
				}				
				break;
			case water:
				if (currentStatus.type == ElementType.fire)
				{
					statusEnd(currentStatus);
					statuses.removeAt(currentStatusIndex);
				}
				else if (currentStatus.type == ElementType.water)
				{
					statuses[currentStatusIndex].elapsed = 0;
				}
				else
				{
					statusEnd(currentStatus);
					statuses[currentStatusIndex] = status;
				}
				break;
			default:
				break;
		}
		return;
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

	void buildTower(uint2 pos, ubyte type) 
	{
		Tower tower = towerPrototypes[type - 2];
		tower.position = pos;
		towers ~= tower;
		foreach(player; Game.players)
			Game.server.sendMessage(player.id, TowerBuiltMessage(pos.x, pos.y, type));

		tileMap[pos] = cast(TileType)type;
	}

	void gameOver()
	{
		std.c.stdlib.exit(0);
	}
}