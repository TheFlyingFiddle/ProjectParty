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
	Wave wave;
	float deltaspawn;
	int lifeTotal;
	List!Projectile projectiles;
	List!Tower towers;

	this(A)(ref A allocator, string configFile)
	{
		enemies = List!Enemy(allocator, 100);
		wave = Wave(42, 1);
		deltaspawn = 0;
		lifeTotal = 10;
		projectiles = List!Projectile(allocator, 1000);
		towers = List!Tower(allocator, 100);
		towers ~= Tower(175,7,1,0,0,uint2(6,7));
		towers ~= Tower(175,7,1,0,0,uint2(4,7));
		import std.algorithm;
		auto map = fromSDLFile!MapConfig(allocator, configFile);
		path = map.path;
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

	void spawn()
	{
		if(wave.nbrOfEnemies == 0)
		{
			return;
		}
		float2 position = float2(path[0].x * tileSize.x + tileSize.x / 2, 
								 path[0].y * tileSize.y + tileSize.y / 2);
		enemies ~= Enemy(position, 1, 60, 10);
		wave.nbrOfEnemies -= 1;
	}

	void enter()
	{
		Game.router.connectionHandlers ~= &connect;
	}

	void connect(ulong playerId)
	{
		MapMessage msg;
		msg.width = tileMap.width;
		msg.height = tileMap.height;
		msg.tiles = cast (ubyte[])tileMap.buffer[0 .. tileMap.width * tileMap.height];
		Game.server.sendMessage(playerId, msg);
	}

	void exit()
	{

	}

	void update()
	{

		deltaspawn += Time.delta;
		if(deltaspawn >= wave.spawnRate)
		{
			deltaspawn -= wave.spawnRate;
			spawn();
		}
		updateEnemies();
		updateTowers();
		updateProjectiles();
		killEnemies();
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
				enemies[projectiles[i].target].health -= projectiles[i].attackDmg;
				projectiles.removeAt(i);
			}
		}
	}

	void render()
	{
		foreach(cell, item; tileMap) 
		{
			Color color;
			final switch(item) with (TileType)
			{
				case buildable: color = Color.green; break;
				case nonbuildable: color = Color.white; break;
			}

			Game.renderer.addRect(float4(cell.x * tileSize.x, cell.y * tileSize.y, tileSize.x, tileSize.y), color); 
		}

		auto tex = Game.content.loadTexture("baws");
		auto frame = Frame(tex);

		foreach(ref enemy; enemies)
		{
			Game.renderer.addFrame(frame, float4(enemy.pos.x - tileSize.x / 4, 
												 enemy.pos.y - tileSize.y / 4,
												 tileSize.x / 2, tileSize.x / 2));
		}
		import util.strings;
		char[128] buffer;
		Game.renderer.addText(lifeFont, text(buffer, lifeTotal), float2(0,Game.window.size.y), Color(0xFFFFFFFF));
		

		auto towerTexture = Game.content.loadTexture("tower0");
		auto towerFrame = Frame(towerTexture);

		foreach(tower; towers) 
		{
			Game.renderer.addFrame( towerFrame, float4(tower.position.x * tileSize.x, tower.position.y * tileSize.y, tileSize.x, tileSize.y)); 
		}

		auto projectileTexture = Game.content.loadTexture("tower0");
		auto projectileFrame = Frame(projectileTexture);
		foreach(projectile; projectiles)
		{
			Game.renderer.addFrame(projectileFrame, projectile.position, Color.white, float2(3,3));
		}
	}

	void spawnProjectile(int enemyIndex, Tower tower)
	{
		projectiles ~= Projectile(tower.attackDmg, tower.pixelPos(tileSize), enemyIndex);
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
			}
		}
	}

	void gameOver()
	{
		std.c.stdlib.exit(0);
	}
}