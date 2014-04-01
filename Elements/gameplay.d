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
	Level level;

	FontID lifeFont;
	List!Enemy enemies;

	int lifeTotal;
	List!Projectile projectiles;
	List!Tower towers;
	List!Status statuses;
	List!uint2 selections;

	List!Boulder boulders;

	this(A)(ref A allocator, string configFile)
	{
		enemies = List!Enemy(allocator, 100);

		statuses = List!Status(allocator, 1000);

		boulders = List!Boulder(allocator, 1000);

		lifeTotal = 1000;
		projectiles = List!Projectile(allocator, 10000);
		towers = List!Tower(allocator, 1000);
		selections = List!uint2(allocator, 10);
		import std.algorithm;

		lifeFont = Game.content.loadFont("Blocked72");

		level = fromSDLFile!Level(allocator, configFile);

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
		if (id == IncomingMessages.towerRequest) {
			auto x = msg.read!uint;
			auto y = msg.read!uint;
			auto type = msg.read!ubyte;
			if (level.tileMap[uint2(x,y)] == TileType.buildable && 
					towers.countUntil!( tower => tower.position.x == x && tower.position.y == y) == -1) {
				buildTower(uint2(x,y), type);
			}
		} else if (id == IncomingMessages.selectRequest) {
			auto x = msg.read!uint;
			auto y = msg.read!uint;
			auto index = selections.countUntil!(s=> s == uint2(x, y));

			if(index == -1) {
				foreach(player ; Game.players) if (player.id != playerId) 
					Game.server.sendMessage(player.id, SelectedMessage(x, y, 0x88AACCBB));

				selections ~= uint2(x,y);
			}
		} else if (id == IncomingMessages.deselect) {
			auto x = msg.read!uint;
			auto y = msg.read!uint;
			selections.remove(uint2(x,y));

			foreach(player ; Game.players) if (player.id != playerId) 
				Game.server.sendMessage(player.id, DeselectedMessage(x, y));
		} else if (id == IncomingMessages.mapRequest) {
			MapMessage mapmsg;
			mapmsg.width = level.tileMap.width;
			mapmsg.height = level.tileMap.height;
			mapmsg.tiles = cast (ubyte[])level.tileMap.buffer[0 .. level.tileMap.width * level.tileMap.height];
			Game.server.sendMessage(playerId, mapmsg);
		} else if (id == IncomingMessages.towerEntered) {
			auto x = msg.read!uint;
			auto y = msg.read!uint;

			foreach(player; Game.players) if (player.id != playerId)
				Game.server.sendMessage(player.id, TowerEnteredMessage(x, y));
		} else if (id == IncomingMessages.towerExited) {
			auto x = msg.read!uint;
			auto y = msg.read!uint;

			foreach(player; Game.players) if (player.id != playerId)
				Game.server.sendMessage(player.id, TowerExitedMessage(x, y));
		} else if (id == IncomingMessages.slingshotStart) {
			auto x = msg.read!uint;
			auto y = msg.read!uint;
			auto startPos = float2(msg.read!(float), msg.read!(float));

			auto index = towers.countUntil!(t => t.position == uint2(x,y));

			if(index != -1) {
				towers[index].sTower.startPos = startPos;
				towers[index].sTower.endPos = startPos;
			}
		} else if (id == IncomingMessages.slingshotUpdate) {
			auto x = msg.read!uint;
			auto y = msg.read!uint;
			auto endPos = float2(msg.read!(float), msg.read!(float));

			auto index = towers.countUntil!(t => t.position == uint2(x,y));

			if(index != -1) {
				towers[index].sTower.endPos = endPos;
			}
		} else if (id == IncomingMessages.slingshotEnd) {
			auto x = msg.read!uint;
			auto y = msg.read!uint;
			auto index = towers.countUntil!(t => t.position == uint2(x,y));

			if(index != -1) {
				auto diff = towers[index].sTower.startPos - towers[index].sTower.endPos;
				auto polar = diff.toPolar();
				if(polar.magnitude > 100 && polar.magnitude < 200)
				{
					auto boulder = Boulder(50, towers[index].pixelPos(level.tileSize), towers[index].sTower.startPos - towers[index].sTower.endPos, 50);
					boulders ~= boulder;
				}
			}
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
		updateBoulders();
		killEnemies();
	}

	void updateBoulders()
	{
		for(int i = boulders.length - 1; i >= 0; --i)
		{
			boulders[i].position += boulders[i].velocity * Time.delta;
			auto index = enemies.countUntil!(x => distance(level.path.position(x.distance),
					boulders[i].position) < boulders[i].radius);
			if (index != -1)
			{
				enemies[index].health -= boulders[i].attackDmg;
				boulders.removeAt(i);
			}
		}
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
				auto enemy = Enemy(level.enemyPrototypes[spawner.prototypeIndex]);
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
			if (enemies[i].distance > level.path.endDistance)
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
				case interaction:
					break;
			}
		}
	}

	int findFarthestReachableEnemy(float2 towerPos, float range)
	{
		int index = -1;
		foreach(i, ref enemy; enemies)
		{
			float distance = distance(level.path.position(enemy.distance), towerPos);
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
			float distance = distance(level.path.position(enemy.distance), towerPos);
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
			float2 towerPos = tower.pixelPos(
							level.tileSize);
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
			float2 towerPos = tower.pixelPos(level.tileSize);
			int index = findNearestReachableEnemy(towerPos, tower.range);
			if(index != -1)
			{
				auto angle = (towerPos - level.path.position(enemies[index].distance)).toPolar.angle;
				foreach(i, ref enemy; enemies) if(distance(towerPos, level.path.position(enemy.distance)) < tower.range)
				{
					auto eAngle = (towerPos - level.path.position(enemy.distance)).toPolar.angle;
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
			auto index = findFarthestReachableEnemy(tower.pixelPos(level.tileSize), tower.range);
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
			float2 target = level.path.position(enemies[projectiles[i].target].distance);
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
				foreach(i, enemy; enemies) if ( distance(level.path.position(enemy.distance),
														 level.path.position(enemies[status.targetIndex].distance))
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
		auto imageTex = Game.content.loadTexture("map2.png");
		auto imageFrame = Frame(imageTex);
		Game.renderer.addFrame(imageFrame, float4(0,0, Game.window.size.x, Game.window.size.y));
		TextureID towerTexture;

		foreach(cell, item; level.tileMap) 
		{
			if(item < 2) continue;
			auto t = level.towerPrototypes[item - 2];
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
				case interaction:
					towerTexture = Game.content.loadTexture("slingshot");
					break;
			}
			auto towerFrame = Frame(towerTexture);

			Color color;
			final switch(item) with (TileType)
			{
				case buildable:      color = Color.green; break;
				case nonbuildable:   color = Color.white; break;
				case fireTower:      color = Color(0xFF3366FF); break;
				case waterTower:     color = Color.blue; break;
				case iceTower:       color = Color(0xFFFFCC66); break;
				case lightningTower: color = Color(0xFF00FFFF); break;
				case windTower:      color = Color(0xFFCCCCCC); break;
				case natureTower:    color = Color.green; break;
				case slingshotTower: color = Color(0xFFAC838A); break;
			}

			Game.renderer.addFrame(towerFrame,float4(cell.x * level.tileSize.x, 
					cell.y * level.tileSize.y, level.tileSize.x, level.tileSize.y), color); 
		}


		foreach(ref enemy; enemies)
		{
			float2 position = level.path.position(enemy.distance);
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
			auto pos = level.path.position(enemy.distance);
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
			Game.renderer.addFrame(selectionFrame, 
						float4(selection.x * level.tileSize.x, selection.y * level.tileSize.y, level.tileSize.x, level.tileSize.y), Color(0x55FF0000)); 
		}

		auto coneTexture = Game.content.loadTexture("cone");
		auto coneFrame = Frame(coneTexture);
		foreach(tower; towers) if (tower.type == TowerType.cone)
		{		
			if ( tower.cTower.elapsed < tower.cTower.activeTime)
			{
				auto index = findNearestReachableEnemy(tower.pixelPos(level.tileSize), tower.range);
				if (index != -1)
				{

					Color color;
					final switch(level.statusPrototypes[tower.cTower.statusIndex].type) with (ElementType)
					{
						case fire: color = Color(0xFF3366FF); break;
						case water: color = Color.blue; break;
						case ice: color = Color(0xFFFFCC66); break;
						case lightning: color = Color(0xFF00FFFF); break;
						case wind: color = Color(0xFFCCCCCC); break;
						case nature: color = Color.green; break;
					}
					auto towerPos = tower.pixelPos(level.tileSize),
						 enemyPos = level.path.position(enemies[index].distance);
					auto polar = (enemyPos - towerPos).toPolar;
					auto angle = polar.angle;
					auto origin = float2(0, coneFrame.height/2);
					Game.renderer.addFrame(coneFrame, towerPos, 
							color, float2(tower.range, coneFrame.height), origin, angle);
				}
			}
		}

		auto boulderTex = Game.content.loadTexture("baws");
		auto boulderFrame = Frame(boulderTex);

		foreach(boulder; boulders)
		{
			Game.renderer.addFrame(boulderFrame, boulder.position, 
					Color.white, float2(boulderFrame.width, boulderFrame.height), float2(boulderFrame.width/2, boulderFrame.height/2), 4*Time.total);
		}
	}

	void spawnProjectile(int enemyIndex, Tower tower)
	{
		Projectile projectile = Projectile(level.projectilePrototypes[tower.pTower.projectileIndex], 
										   tower.pixelPos(level.tileSize), enemyIndex);
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
			immutable radius = level.tileSize.x * 3;
			foreach(i, ref enemy; enemies) if(distanceSquared(level.path.position(enemy.distance), projectile.position) < radius * radius)
			{
				enemy.health -= projectile.attackDmg;
				addStatus(projectile.statusIndex, i);
			}
		}
	}

	void addStatus(uint statusIndex, uint enemyIndex)
	{
		auto status = Status(level.statusPrototypes[statusIndex], enemyIndex);
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
				{
					statusEnd(currentStatus);
					statuses.removeAt(currentStatusIndex);
					applyStatus(status);
				}
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
		Tower tower = Tower(level.towerPrototypes[type - 2], pos);
		towers ~= tower;
		foreach(player; Game.players)
			Game.server.sendMessage(player.id, TowerBuiltMessage(pos.x, pos.y, type));

		level.tileMap[pos] = cast(TileType)type;
	}

	void gameOver()
	{
		std.c.stdlib.exit(0);
	}
}