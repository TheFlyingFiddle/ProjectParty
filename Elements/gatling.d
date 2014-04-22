module gatling;

import math;
import collections;
import types;
import content;
import graphics;
import game;
import game.debuging;
import sound;
import std.algorithm : max, min;
import std.math : atan2;
import algorithm : findFarthestReachableEnemy;
import tower_controller, enemy_collection;
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
	int gatlingPrefabIndex;
	float anglePerShot;
	float pressureCost;
	@Convert!stringToSound() SoundID sound;
}

final class GatlingController : TowerController!GatlingInstance
{
	List!AutoProjectileInstance autoProjectiles;

	//This is a quick and dirty way of doing this i don't know what 
	//way is best if any but this works.

	this(A)(ref A allocator, TowerCollection owner)
	{
		super(allocator, TileType.gatling, owner);
		this.autoProjectiles = List!AutoProjectileInstance(allocator, 1000);
		Game.router.setMessageHandler(IncomingMessages.gatlingValue,  &handleGatlingValue);
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

		

		foreach(i, c; controlled) 
		{
			auto tower = &instances[c.instanceIndex];
			if(tower.elapsed >= tower.anglePerShot)
			{
				tower.elapsed -= tower.anglePerShot;
				if(pressure(instances[c.instanceIndex]) >= tower.pressureCost)
				{
					Game.sound.playSound(tower.sound);
					pressure(instances[c.instanceIndex]) -= tower.pressureCost;
					auto enemyIndex = findFarthestReachableEnemy(enemies, position(instances[c.instanceIndex]), range(c.instanceIndex));
					if(enemyIndex != -1) 
					{
						spawnHomingProjectile(tower.gatlingPrefabIndex, enemyIndex, position(instances[c.instanceIndex]));
					}
				}
			}
		}

		super.update(enemies);
	}

	void render(List!BaseEnemy enemies)
	{

		auto targetTex = Game.content.loadTexture("crosshair");
		auto targetFrame = Frame(targetTex);
		foreach(c; controlled)
		{
			auto tower = instances[c.instanceIndex];
			auto enemyIndex = findFarthestReachableEnemy(enemies, position(c.instanceIndex), range(c.instanceIndex));
			if(enemyIndex != -1) 
			{
				auto size = float2(targetFrame.width, targetFrame.height);
				auto origin = size/2;
				Game.renderer.addFrame(targetFrame, enemies[enemyIndex].position, Color.white, Game.window.relativeScale, origin);
			}
		}

		foreach(projectile; autoProjectiles)
		{
			auto size = float2(projectile.frame.width, projectile.frame.height);
			auto origin = size/2;
			Game.renderer.addFrame(	projectile.frame, projectile.position, Color(0xFF99FFFF), Game.window.relativeScale, origin, 
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

	void onEnemyDeath(EnemyCollection enemies, BaseEnemy enemy, uint index)
	{
		for (int j = autoProjectiles.length - 1; j >= 0; j--)
		{
			if(autoProjectiles[j].targetIndex == index)
			{
				autoProjectiles.removeAt(j);
			} 
			else if(autoProjectiles[j].targetIndex > index)
			{
				autoProjectiles[j].targetIndex--;
			}
		}
	}
}
