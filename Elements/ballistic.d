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
import tower_controller;

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
		polar.magnitude = prefabs[prefabIndex].speed;
		this.velocity = polar.toCartesian;

		this.position = position;
		this.target = target;
	}
	
	@property float damage()
	{
		return prefabs[prefabIndex].damage;
	}

	@property float radius()
	{
		return prefabs[prefabIndex].radius;
	}

	@property float speed()
	{
		return prefabs[prefabIndex].speed;
	}

	@property ref Frame frame()
	{
		return prefabs[prefabIndex].frame;
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

	@property float damage()
	{
		return prefabs[prefabIndex].damage;
	}

	@property float speed()
	{
		return prefabs[prefabIndex].speed;
	}

	@property float radius()
	{
		return prefabs[prefabIndex].radius;
	}

	@property ref Frame frame()
	{
		return prefabs[prefabIndex].frame;
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
	float2 position;
	float angle;
	float distance;
	float elapsed;
	bool isControlled;

	this(float2 position, int prefab)
	{
		this.prefab = prefab;
		this.position = position;
		this.angle = 0;
		this.distance = 0;
		this.elapsed = 0;
	}

	@property float range()
	{
		return prefabs[prefab].range;
	}

	@property float maxDistance()
	{
		return prefabs[prefab].maxDistance;
	}

	@property float reloadTime()
	{
		return prefabs[prefab].reloadTime;
	}

	@property int homingPrefabIndex()
	{
		return prefabs[prefab].homingPrefabIndex;
	}

	@property int ballisticPrefabIndex()
	{
		return prefabs[prefab].ballisticPrefabIndex;
	}

	@property ref Frame frame()
	{
		return prefabs[prefab].frame;
	}

	uint2 cell(uint2 tileSize)
	{
		return uint2((position.x - tileSize.x/2)/tileSize.x, 
					 (position.y - tileSize.y/2)/tileSize.y);
	}
}

struct BallisticTower
{
	int homingPrefabIndex;
	int ballisticPrefabIndex;
	float range;
	float maxDistance; //Separate range for manual projectiles.
	float reloadTime;
	@Convert!stringToFrame() Frame frame;
}

final class BallisticController : TowerController!BallisticInstance
{
	List!BallisticProjectileInstance ballisticProjectiles;
	List!HomingProjectileInstance homingProjectiles;

	this(A)(ref A allocator)
	{
		super(List!BallisticInstance(allocator, 100), TileType.rocket);
		this.ballisticProjectiles = List!BallisticProjectileInstance(allocator, 100);
		this.homingProjectiles = List!HomingProjectileInstance(allocator, 1000);
	}

	void sendTowerInfo(uint towerIndex)
	{
		
	}

	void launch(int towerIndex)
	{
		auto target = Polar!float(
							instances[towerIndex].angle,
							instances[towerIndex].distance).toCartesian;
		ballisticProjectiles ~= BallisticProjectileInstance(
									instances[towerIndex].ballisticPrefabIndex,
									instances[towerIndex].position,
									instances[towerIndex].position + target);

	}

	void update(List!Enemy enemies)
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
			if(tower.isControlled)
			{
				//Nothing to do?
			}
			else // Tower is on autopilot. Just shoot projectiles steadily.
			{
				tower.elapsed += Time.delta;
				if(tower.elapsed >= tower.reloadTime)
				{
					auto enemyIndex = findFarthestReachableEnemy(enemies, tower.position, tower.range);
					if(enemyIndex != -1) 
					{
						spawnHomingProjectile(tower.homingPrefabIndex, enemyIndex, tower.position);
						tower.elapsed = 0;
					}
				}
			}
		}
	}

	void render(Renderer* renderer, float2 tileSize, List!Enemy enemies /*Quick hack*/)
	{

		auto targetTex = Game.content.loadTexture("crosshair");
		auto targetFrame = Frame(targetTex);
		foreach(tower; instances)
		{		
			renderer.addFrame(tower.frame, tower.position, Color.white, tileSize, tileSize/2);

			if(tower.isControlled)
			{
				// Calculate origin
				auto size = float2(targetFrame.width, targetFrame.height);
				auto origin = size/2;

				// Calculate the position
				auto distance = min(tower.distance, tower.maxDistance);
				auto vecToTarget = Polar!float(tower.angle, distance).toCartesian();
				auto position = tower.position + vecToTarget;

				renderer.addFrame(targetFrame, position, Color.white, size, origin);
			}
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
