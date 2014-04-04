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
import tower_controller;

struct GatlingProjectileInstance
{
	static List!GatlingProjectilePrefab prefabs;
	int		prefabIndex;
	float2	position;
	float2	velocity;

	this(int prefabIndex, float2 position, float2 velocity)
	{
		this.prefabIndex = prefabIndex;

		this.position = position;
		this.velocity = velocity;
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

struct GatlingProjectilePrefab
{
	float damage;
	float radius;
	float speed;
	@Convert!stringToFrame() Frame frame;
}

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

	@property int gatlingPrefabIndex()
	{
		return prefabs[prefab].gatlingPrefabIndex;
	}

	@property ref Frame frame()
	{
		return prefabs[prefab].frame;
	}
}

struct GatlingTower
{
	int homingPrefabIndex;
	int gatlingPrefabIndex;
	float range;
	float maxDistance; //Separate range for manual projectiles.
	float reloadTime;
	@Convert!stringToFrame() Frame frame;
}

final class GatlingController : TowerController!GatlingInstance
{
	List!GatlingProjectileInstance gatlingProjectiles;
	List!AutoProjectileInstance autoProjectiles;

	this(A)(ref A allocator)
	{
		super(allocator, TileType.gatling);
		this.gatlingProjectiles = List!GatlingProjectileInstance(allocator, 100);
		this.autoProjectiles = List!AutoProjectileInstance(allocator, 1000);
	}

	void towerEntered(uint towerIndex, ulong playerId)
	{
		instances[towerIndex].isControlled = true;
	}

	void towerExited(uint towerIndex, ulong playerId)
	{
		instances[towerIndex].isControlled = false;
	}

	void launch(int towerIndex)
	{
		auto velocity = Polar!float(
								  instances[towerIndex].angle,
								  GatlingProjectileInstance.prefabs[instances[towerIndex].homingPrefabIndex].speed).toCartesian;
		gatlingProjectiles ~= GatlingProjectileInstance(
															instances[towerIndex].gatlingPrefabIndex,
															common[towerIndex].position,
															velocity);

	}

	void update(List!Enemy enemies)
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

		// Update all non-homing projectiles
		for(int i = gatlingProjectiles.length - 1; i >= 0; --i)
		{
			gatlingProjectiles[i].position += gatlingProjectiles[i].velocity * Time.delta;


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
					auto enemyIndex = findFarthestReachableEnemy(enemies, common[i].position, tower.range);
					if(enemyIndex != -1) 
					{
						spawnHomingProjectile(tower.homingPrefabIndex, enemyIndex, common[i].position);
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
		foreach(i, tower; instances)
		{		
			renderer.addFrame(tower.frame, common[i].position, Color.white, tileSize, tileSize/2);

			if(tower.isControlled)
			{
				// Calculate origin
				auto size = float2(targetFrame.width, targetFrame.height);
				auto origin = size/2;

				// Calculate the position
				auto vecToTarget = Polar!float(tower.angle, tower.maxDistance).toCartesian();
				auto position = common[i].position + vecToTarget;
				import game.debuging;
				renderer.addLine(position, common[i].position);

				renderer.addFrame(targetFrame, position, Color.white, size, origin);
			}
		}

		foreach(projectile; autoProjectiles)
		{
			auto size = float2(projectile.frame.width, projectile.frame.height);
			auto origin = size/2;
			renderer.addFrame(	projectile.frame, projectile.position, Color(0xFF99FFFF), size, origin, 
								atan2(	enemies[projectile.targetIndex].position.y - projectile.position.y, 
										enemies[projectile.targetIndex].position.x - projectile.position.x));
		}

		foreach(projectile; gatlingProjectiles)
		{
			auto size = float2(projectile.frame.width, projectile.frame.height);
			auto origin = size/2;
			renderer.addFrame(	projectile.frame, projectile.position, Color.white, size, origin, 
								atan2(	projectile.velocity.y, 
										projectile.velocity.x));
		}
	}

	private void spawnHomingProjectile(int projectilePrefabIndex, int enemyIndex, float2 position)
	{
		auto projectile = AutoProjectileInstance(projectilePrefabIndex, enemyIndex, position);
		autoProjectiles ~= projectile;
	}

	private void spawnGatlingProjectile(int projectilePrefabIndex, float2 position, float2 target)
	{
		auto projectile = GatlingProjectileInstance(projectilePrefabIndex, position, target);
		gatlingProjectiles ~= projectile;
	}
}
