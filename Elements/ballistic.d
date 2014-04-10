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
import algorithm;
import network_types;
import network.message;
import tower_controller, enemy_collection;
import util.bitmanip;

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
	int baseIndex;
	float angle;
	float distance;
	float elapsed;

	this(int prefab, int baseIndex)
	{
		this.prefab = prefab;
		this.baseIndex = baseIndex;

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
	float maxDistance; //Separate range for manual projectiles.
	float reloadTime;
	float pressureCost;
	@Convert!stringToFrame() Frame frame;
}

final class BallisticController : TowerController!BallisticInstance
{
	List!BallisticProjectileInstance ballisticProjectiles;
	List!HomingProjectileInstance homingProjectiles;

	this(A)(ref A allocator, TowerCollection owner)
	{
		super(allocator, TileType.rocket, owner);
		this.ballisticProjectiles = List!BallisticProjectileInstance(allocator, 100);
		this.homingProjectiles = List!HomingProjectileInstance(allocator, 1000);

		Game.router.setMessageHandler(IncomingMessages.ballisticValue,			&handleBallisticValue);
		Game.router.setMessageHandler(IncomingMessages.ballisticDirection,	&handleBallisticDirection);
		Game.router.setMessageHandler(IncomingMessages.ballisticLaunch,		&handleBallisticLaunch);
	}

	void launch(int towerIndex)
	{
		pressure(towerIndex, max(0,	pressure(towerIndex)
											-	instances[towerIndex].pressureCost));
		auto target = Polar!float(
							instances[towerIndex].angle,
							instances[towerIndex].distance).toCartesian;
		ballisticProjectiles ~= BallisticProjectileInstance(
												instances[towerIndex].ballisticPrefabIndex,
												position(towerIndex),
												position(towerIndex) + target);
	}

	override void update(List!BaseEnemy enemies)
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
		foreach(i, ref tower; instances) if(!isBroken(i) && !isControlled(i))
		{
			tower.elapsed += Time.delta;
			if(tower.elapsed >= tower.reloadTime)
			{
				auto enemyIndex = findFarthestReachableEnemy(enemies, position(tower), range(tower));
				if(enemyIndex != -1) 
				{
					spawnHomingProjectile(tower.homingPrefabIndex, enemyIndex, position(tower));
					tower.elapsed = 0;
				}
			}
		}

		super.update(enemies);
	}

	void render(List!BaseEnemy enemies)
	{
		auto targetTex = Game.content.loadTexture("crosshair");
		auto targetFrame = Frame(targetTex);
		foreach(i, tower; instances)
		{		
			if(isControlled(i))
			{
				// Calculate origin
				auto size = float2(targetFrame.width, targetFrame.height);
				auto origin = size/2;

				// Calculate the position
				auto distance = min(tower.distance, tower.maxDistance);
				auto vecToTarget = Polar!float(tower.angle, distance).toCartesian();
				auto position = position(tower) + vecToTarget;


				Game.renderer.addFrame(targetFrame, position, Color.white, float2.one, origin);
			}
			auto position = position(tower);
		}

		foreach(projectile; homingProjectiles)
		{
			auto size = float2(projectile.frame.width, projectile.frame.height);
			auto origin = size/2;
			Game.renderer.addFrame(projectile.frame, projectile.position, Color.white, float2.one, origin, 
							  atan2(enemies[projectile.targetIndex].position.y - projectile.position.y, 
									enemies[projectile.targetIndex].position.x - projectile.position.x));
		}

		foreach(projectile; ballisticProjectiles)
		{
			auto size = float2(projectile.frame.width, projectile.frame.height);
			auto origin = size/2;
			Game.renderer.addFrame(	projectile.frame, projectile.position, Color.white, float2.one, origin, 
								atan2(	projectile.target.y - projectile.position.y, 
										projectile.target.x - projectile.position.x));
		}
	}

	override void towerEntered(int towerIndex, ulong playerID)
	{
		BallisticInfoMessage msg;
		msg.pressure = pressure(towerIndex);
		msg.maxPressure = maxPressure;
		msg.direction = instances[towerIndex].angle;
		msg.distance = instances[towerIndex].distance;
		msg.maxDistance = instances[towerIndex].maxDistance;
		msg.pressureCost = instances[towerIndex].pressureCost;

		Game.server.sendMessage(playerID, msg);
	}

	override void towerExited(int towerIndex, ulong playerID) { }

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

	void handleBallisticValue(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint;
		auto y = msg.read!uint;
		auto value = msg.read!float;

		auto index = indexOf(uint2(x,y));
		if(index != -1)
		{
			auto distance = instances[index].maxDistance * value;
			instances[index].distance = distance;
		}
	}

	void handleBallisticDirection(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint;
		auto y = msg.read!uint;
		auto value = msg.read!float;

		auto index = indexOf(uint2(x,y));
		if(index != -1)
			instances[index].angle = value;
	}	

	void handleBallisticLaunch(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint;
		auto y = msg.read!uint;

		auto index = indexOf(uint2(x,y));
		if(index != -1)
			launch(index);
	}

	void onEnemyDeath(EnemyCollection enemies, BaseEnemy enemy, uint index)
	{
		for (int j = homingProjectiles.length - 1; j >= 0; j--)
		{
			if(homingProjectiles[j].targetIndex == index)
			{
				auto nearest = findNearestEnemy(enemies.enemies, homingProjectiles[j].position);
				if(nearest == -1)
					homingProjectiles.removeAt(j);
				else
					homingProjectiles[j].targetIndex = nearest;
			} 
			else if(homingProjectiles[j].targetIndex > index)
			{
				homingProjectiles[j].targetIndex--;
			}
		}
	}
}
