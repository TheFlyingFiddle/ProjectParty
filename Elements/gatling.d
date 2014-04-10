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
import util.bitmanip;

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
	int baseIndex;
	float angle;
	float elapsed;

	this(int prefab, int baseIndex)
	{
		this.prefab = prefab;
		this.baseIndex = baseIndex;
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

	this(A)(ref A allocator, TowerCollection owner)
	{
		super(allocator, TileType.gatling, owner);
		this.autoProjectiles = List!AutoProjectileInstance(allocator, 1000);

		Game.router.setMessageHandler(IncomingMessages.gatlingValue,	&handleGatlingValue);
	}

	override void towerEntered(int towerIndex, ulong playerID)
	{
		GatlingInfoMessage msg;
		msg.pressure = pressure(towerIndex);
		msg.maxPressure = maxPressure;

		Game.server.sendMessage(playerID, msg);
	}

	override void towerExited(int towerIndex, ulong playerID)
	{
	}

	override void update(List!BaseEnemy enemies)
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
			if(isControlled(i))
			{	
				if(tower.elapsed >= tower.anglePerShot)
				{
					tower.elapsed -= tower.anglePerShot;
					if(pressure(i) >= tower.pressureCost)
					{
						pressure(i, pressure(i) - tower.pressureCost);
						auto enemyIndex = findFarthestReachableEnemy(enemies, position(i), tower.range);
						if(enemyIndex != -1) 
						{
							spawnHomingProjectile(tower.gatlingPrefabIndex, enemyIndex, position(i));
						}
					}
				}
			}
			else // Tower is on autopilot. Just shoot projectiles steadily.
			{
				tower.elapsed += Time.delta;
				if(tower.elapsed >= tower.reloadTime)
				{
					auto enemyIndex = findFarthestReachableEnemy(enemies, position(i), tower.range);
					if(enemyIndex != -1) 
					{
						spawnHomingProjectile(tower.homingPrefabIndex, enemyIndex, position(i));
						tower.elapsed = 0;
					}
				}
			}
		}

		foreach(tower; controlled)
		{
			Game.server.sendMessage(
									tower.playerID, 
									PressureInfoMessage(pressure(tower.instanceIndex))
									);
		}
	}

	override void render(List!BaseEnemy enemies)
	{

		auto targetTex = Game.content.loadTexture("crosshair");
		auto targetFrame = Frame(targetTex);
		foreach(i, tower; instances)
		{		

			if(isControlled(i))
			{
				// Calculate origin
				auto enemyIndex = findFarthestReachableEnemy(enemies, position(i), tower.range);
				if(enemyIndex != -1) 
				{
					auto size = float2(targetFrame.width, targetFrame.height);
					auto origin = size/2;
					Game.renderer.addFrame(targetFrame, enemies[enemyIndex].position, Color.white, size, origin);
				}
			}
		}

		foreach(projectile; autoProjectiles)
		{
			auto size = float2(projectile.frame.width, projectile.frame.height);
			auto origin = size/2;
			Game.renderer.addFrame(	projectile.frame, projectile.position, Color(0xFF99FFFF), size, origin, 
								atan2(	enemies[projectile.targetIndex].position.y - projectile.position.y, 
										enemies[projectile.targetIndex].position.x - projectile.position.x));
		}

	}

	private void spawnHomingProjectile(int projectilePrefabIndex, int enemyIndex, float2 position)
	{
		auto projectile = AutoProjectileInstance(projectilePrefabIndex, enemyIndex, position);
		autoProjectiles ~= projectile;
	}

	void handleGatlingValue(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint;
		auto y = msg.read!uint;
		auto value = msg.read!float;

		auto index = indexOf(uint2(x,y));
		if(index != -1)
		{
			instances[index].elapsed += value;
		}
	}
}
