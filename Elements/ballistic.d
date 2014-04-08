module ballistic;

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
import network_types;
import network.message;
import tower_controller, enemy_controller;

struct BallisticProjectileInstance
{
	static List!BallisticProjectilePrefab prefabs;
	int		prefabIndex;
	float2	velocity;
	float2	position;
	float2	target;

	this(int prefabIndex, float2 position, float2 target)
	{
		this.prefabIndex = prefabIndex;

		auto polar = (target - position).toPolar;
		polar.magnitude = this.speed;
		this.velocity = polar.toCartesian;

		this.position = position;
		this.target = target;
	}
	
	auto ref opDispatch(string property)()
	{
		mixin("return prefabs[prefabIndex]." ~ property ~ ";");
	}
}

struct BallisticProjectilePrefab
{
	float damage;
	float radius;
	float speed;
	@Convert!stringToFrame() Frame frame;
}

struct HomingProjectileInstance
{
	static List!HomingProjectilePrefab prefabs;
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

struct HomingProjectilePrefab
{
	float damage;
	float speed;
	float radius;
	@Convert!stringToFrame() Frame frame;
}

struct BallisticInstance
{
	static List!BallisticTower prefabs;

	int prefab;
	float angle;
	float distance;
	float elapsed;
	bool isControlled;

	this(int prefab)
	{
		this.prefab = prefab;
		this.angle = 0;
		this.distance = 0;
		this.elapsed = 0;
	}

	auto ref opDispatch(string property)()
	{
		mixin("return prefabs[prefab]." ~ property ~ ";");
	}
}

struct BallisticTower
{
	int homingPrefabIndex;
	int ballisticPrefabIndex;
	float range;
	float maxDistance; //Separate range for manual projectiles.
	float reloadTime;
	float maxPressure;
	float pressureRegen;
	float pressureCost;
	@Convert!stringToFrame() Frame frame;
}

final class BallisticController : TowerController!BallisticInstance
{
	List!BallisticProjectileInstance ballisticProjectiles;
	List!HomingProjectileInstance homingProjectiles;

	this(A)(ref A allocator)
	{
		super(allocator, TileType.rocket);
		this.ballisticProjectiles = List!BallisticProjectileInstance(allocator, 100);
		this.homingProjectiles = List!HomingProjectileInstance(allocator, 1000);
	}

	void launch(int towerIndex)
	{
		common[towerIndex].pressure = max(0,	common[towerIndex].pressure 
											-	instances[towerIndex].pressureCost);
		auto target = Polar!float(
							instances[towerIndex].angle,
							instances[towerIndex].distance).toCartesian;
		ballisticProjectiles ~= BallisticProjectileInstance(
												instances[towerIndex].ballisticPrefabIndex,
												common[towerIndex].position,
												common[towerIndex].position + target);
	}

	void update(List!BaseEnemy enemies)
	{
		// Update all homing projectiles
		for(int i = homingProjectiles.length - 1; i >= 0; --i)
		{
			
			// Move the projectile towards the target.
			auto velocity = (enemies[homingProjectiles[i].targetIndex].position 
							 - homingProjectiles[i].position).normalized 
							* homingProjectiles[i].speed 
							* Time.delta;
			homingProjectiles[i].position += velocity;

			// Check for collision between the target and the projectile
			if(distance(enemies[homingProjectiles[i].targetIndex].position, 
										homingProjectiles[i].position) 
							< homingProjectiles[i].radius)
			{
				enemies[homingProjectiles[i].targetIndex].health -= homingProjectiles[i].damage;
				homingProjectiles.removeAt(i);
			}
		}

		// Update all non-homing projectiles
		for(int i = ballisticProjectiles.length - 1; i >= 0; --i)
		{
			ballisticProjectiles[i].position += ballisticProjectiles[i].velocity * Time.delta;
			
			if(distance(ballisticProjectiles[i].position, ballisticProjectiles[i].target)
			   < 10)
			{
				foreach(ref enemy; enemies)
				{
					if(distance(enemy.position, ballisticProjectiles[i].position) 
								< ballisticProjectiles[i].radius)
						enemy.health -= ballisticProjectiles[i].damage;
				}
				ballisticProjectiles.removeAt(i);
			}
		}

		// Update all towers
		foreach(i, ref tower; instances)
		{
			common[i].pressure = min(tower.maxPressure, 
									 common[i].pressure + tower.pressureRegen * Time.delta);
			if(tower.isControlled)
			{
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
				auto size = float2(targetFrame.width, targetFrame.height);
				auto origin = size/2;

				// Calculate the position
				auto distance = min(tower.distance, tower.maxDistance);
				auto vecToTarget = Polar!float(tower.angle, distance).toCartesian();
				auto position = common[i].position + vecToTarget;

				renderer.addFrame(targetFrame, position, Color.white, size, origin);
			}
			auto position = common[i].position;

			float amount = common[i].pressure/tower.maxPressure;
			float sBWidth = min(50, tower.maxPressure);
			Game.renderer.addRect(float4(position.x - sBWidth/2, position.y + tileSize.y/2, 
										 sBWidth, 5), Color.blue);
			Game.renderer.addRect(float4(position.x - sBWidth/2, position.y + tileSize.y/2, 
										 sBWidth*amount, 5), Color.white);
		}

		foreach(projectile; homingProjectiles)
		{
			auto size = float2(projectile.frame.width, projectile.frame.height);
			auto origin = size/2;
			renderer.addFrame(projectile.frame, projectile.position, Color.white, size, origin, 
							  atan2(enemies[projectile.targetIndex].position.y - projectile.position.y, 
									enemies[projectile.targetIndex].position.x - projectile.position.x));
		}

		foreach(projectile; ballisticProjectiles)
		{
			auto size = float2(projectile.frame.width, projectile.frame.height);
			auto origin = size/2;
			renderer.addFrame(	projectile.frame, projectile.position, Color.white, size, origin, 
								atan2(	projectile.target.y - projectile.position.y, 
										projectile.target.x - projectile.position.x));
		}
	}

	void towerEntered(uint towerIndex, ulong playerID)
	{
		BallisticInfoMessage msg;
		msg.pressure = common[towerIndex].pressure;
		msg.maxPressure = instances[towerIndex].maxPressure;
		msg.direction = instances[towerIndex].angle;
		msg.distance = instances[towerIndex].distance;
		msg.maxDistance = instances[towerIndex].maxDistance;
		msg.pressureCost = instances[towerIndex].pressureCost;

		Game.server.sendMessage(playerID, msg);
		
		instances[towerIndex].isControlled = true;
		controlled ~= Controlled(towerIndex, playerID);
	}

	void towerExited(uint towerIndex, ulong playerID)
	{
		instances[towerIndex].isControlled = false;
		auto t = cast(int)towerIndex;
		auto index = controlled.countUntil!(c => c.towerIndex == t);
		controlled.removeAt(index);
	}

	private void spawnHomingProjectile(int projectilePrefabIndex, int enemyIndex, float2 position)
	{
		auto projectile = HomingProjectileInstance(projectilePrefabIndex, enemyIndex, position);
		homingProjectiles ~= projectile;
	}
 
	private void spawnBallisticProjectile(int projectilePrefabIndex, float2 position, float2 target)
	{
		auto projectile = BallisticProjectileInstance(projectilePrefabIndex, position, target);
		ballisticProjectiles ~= projectile;
	}
}
