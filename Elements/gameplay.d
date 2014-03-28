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
	List!uint2 selections;

	this(A)(ref A allocator, string configFile)
	{
		enemies = List!Enemy(allocator, 100);
		wave = Wave(42, 1);
		deltaspawn = 0;
		lifeTotal = 50;
		projectiles = List!Projectile(allocator, 10000);
		towers = List!Tower(allocator, 1000);
		selections = List!uint2(allocator, 10);
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
		enemies ~= Enemy(position, 1, 60, 22);
		wave.nbrOfEnemies -= 1;
	}

	void enter()
	{
		Game.router.connectionHandlers ~= &connect;
		Game.router.messageHandlers ~= &handleMessage;
	}

	void connect(ulong playerId)
	{
		MapMessage msg;
		msg.width = tileMap.width;
		msg.height = tileMap.height;
		msg.tiles = cast (ubyte[])tileMap.buffer[0 .. tileMap.width * tileMap.height];
		Game.server.sendMessage(playerId, msg);
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
		}
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

	void buildTower(uint2 pos, ubyte type) 
	{
		towers ~= Tower(175,7,1,0,0,pos);
		foreach(player; Game.players)
			Game.server.sendMessage(player.id, TowerBuiltMessage(pos.x, pos.y, type));

		tileMap[pos] = cast(TileType)type;
	}

	void gameOver()
	{
		std.c.stdlib.exit(0);
	}
}