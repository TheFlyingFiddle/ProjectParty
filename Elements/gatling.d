module gatling;

import math;
import collections;
import types;
import content;
import graphics;
import game;
import game.debuging;
import std.algorithm : max, min;
import std.math : atan2;
import gameplay : findFarthestReachableEnemy;
import tower_controller, enemy_controller;
import network.message;
import network_types;

struct AutoProjectileInstance
{
	static List!AutoProjectilePrefab prefabs;

	int		prefabIndex;
	int		targetIndex;
	float2	position;
	this(int prefabIndex, int target, float2 position)
	{
		this.prefabIndex = prefabIndex;
		this.targetIndex = target;
		this.position = position;
	}

	auto ref opDispatch(string property)()
	{
		mixin("return prefabs[prefabIndex]." ~ property ~ ";");
	}
}

struct AutoProjectilePrefab
{
	float damage;
	float speed;
	float radius;
	@Convert!stringToFrame() Frame frame;
}

struct GatlingInstance
{
	static List!GatlingTower prefabs;

	int prefab;
	float angle;
	float elapsed;
	bool isControlled;

	this(int prefab)
	{
		this.prefab = prefab;
		this.angle = 0;
		this.elapsed = 0;
	}

	auto ref opDispatch(string property)()
	{
		mixin("return prefabs[prefab]." ~ property ~ ";");
	}
}

struct GatlingTower
{
	int homingPrefabIndex;
	int gatlingPrefabIndex;
	float range;
	float maxDistance;
	float reloadTime;
	float anglePerShot;
	float maxPressure;
	float pressureCost;
	@Convert!stringToFrame() Frame frame;
}

final class GatlingController : TowerController!GatlingInstance
{
	List!AutoProjectileInstance autoProjectiles;

	this(A)(ref A allocator)
	{
		super(allocator, TileType.gatling);
		this.autoProjectiles = List!AutoProjectileInstance(allocator, 1000);
	}

	void towerEntered(uint towerIndex, ulong playerId)
	{
		controlled ~= Controlled(towerIndex, playerId);
		instances[towerIndex].isControlled = true;
	}

	void towerExited(uint towerIndex, ulong playerId)
	{
		instances[towerIndex].isControlled = false;
		auto t = cast(int)towerIndex;
		auto index = controlled.countUntil!(c => c.towerIndex == t);
		controlled.removeAt(index);
	}

	void crankTurned(uint towerIndex, float amount)
	{
		instances[towerIndex].elapsed += amount;
	}

	void update(List!BaseEnemy enemies)
	{

		// Update all homing projectiles
		for(int i = autoProjectiles.length - 1; i >= 0; --i)
		{

			// Move the projectile towards the target.
			auto velocity = (enemies[autoProjectiles[i].targetIndex].position 
							 - autoProjectiles[i].position).normalized 
				* autoProjectiles[i].speed 
				* Time.delta;
			autoProjectiles[i].position += velocity;

			// Check for collision between the target and the projectile
			if(distance(enemies[autoProjectiles[i].targetIndex].position, 
						autoProjectiles[i].position) 
			   < autoProjectiles[i].radius)
			{
				enemies[autoProjectiles[i].targetIndex].health -= autoProjectiles[i].damage;
				autoProjectiles.removeAt(i);
			}
		}

		// Update all towers
		foreach(i, ref tower; instances)
		{
			if(tower.isControlled)
			{	
				if(tower.elapsed >= tower.anglePerShot)
				{
					tower.elapsed -= tower.anglePerShot;
					if(common[i].pressure >= tower.pressureCost)
					{
						auto enemyIndex = findFarthestReachableEnemy(enemies, common[i].position, tower.range);
						if(enemyIndex != -1) 
						{
							spawnHomingProjectile(tower.gatlingPrefabIndex, enemyIndex, common[i].position);
						}
					}
				}
	
			}
			else // Tower is on autopilot. Just shoot projectiles steadily.
			{
				tower.elapsed += Time.delta;
				if(tower.elapsed >= tower.reloadTime)
				{
					auto enemyIndex = findFarthestReachableEnemy(enemies, common[i].position, tower.range);
					if(enemyIndex != -1) 
					{
						spawnHomingProjectile(tower.homingPrefabIndex, enemyIndex, common[i].position);
						tower.elapsed = 0;
					}
				}
			}
		}

		foreach(tower; controlled)
		{
			Game.server.sendMessage(tower.playerID, PressureInfoMessage(common[tower.towerIndex].pressure));
		}
	}

	void render(Renderer* renderer, float2 tileSize, List!BaseEnemy enemies /*Quick hack*/)
	{

		auto targetTex = Game.content.loadTexture("crosshair");
		auto targetFrame = Frame(targetTex);
		foreach(i, tower; instances)
		{		
			renderer.addFrame(tower.frame, common[i].position, Color.white, tileSize, tileSize/2);

			if(tower.isControlled)
			{
				// Calculate origin
				auto enemyIndex = findFarthestReachableEnemy(enemies, common[i].position, tower.range);
				if(enemyIndex != -1) 
				{
					auto size = float2(targetFrame.width, targetFrame.height);
					auto origin = size/2;
					renderer.addFrame(targetFrame, enemies[enemyIndex].position, Color.white, size, origin);
				}
			}

			auto position = common[i].position;

			float amount = common[i].pressure/tower.maxPressure;
			float sBWidth = min(50, tower.maxPressure);
			Game.renderer.addRect(float4(position.x - sBWidth/2, position.y + tileSize.y/2, 
										 sBWidth, 5), Color.blue);
			Game.renderer.addRect(float4(position.x - sBWidth/2, position.y + tileSize.y/2, 
										 sBWidth*amount, 5), Color.white);
		}

		foreach(projectile; autoProjectiles)
		{
			auto size = float2(projectile.frame.width, projectile.frame.height);
			auto origin = size/2;
			renderer.addFrame(	projectile.frame, projectile.position, Color(0xFF99FFFF), size, origin, 
								atan2(	enemies[projectile.targetIndex].position.y - projectile.position.y, 
										enemies[projectile.targetIndex].position.x - projectile.position.x));
		}

	}

	private void spawnHomingProjectile(int projectilePrefabIndex, int enemyIndex, float2 position)
	{
		auto projectile = AutoProjectileInstance(projectilePrefabIndex, enemyIndex, position);
		autoProjectiles ~= projectile;
	}

}
