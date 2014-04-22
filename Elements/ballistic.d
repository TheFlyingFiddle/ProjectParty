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

	this(int prefabIndex, float2 position, float2 target, float scale)
	{
		this.prefabIndex = prefabIndex;

		auto polar = (target - position).toPolar;
		polar.magnitude = this.speed * scale;
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
	@Convert!stringToParticle() ParticleEffectConfig explosion;
	@Convert!stringToSound() SoundID sound;
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
	int bigBoomPrefabIndex;
	int smallBoomPrefabIndex;
	float bigBoomCost;
	float smallBoomCost;
}

final class BallisticController : TowerController!BallisticInstance
{
	List!BallisticProjectileInstance projectiles;

	ParticleCollection particleCollection;

	this(A)(ref A allocator, TowerCollection owner, ParticleCollection coll)
	{
		super(allocator, TileType.rocket, owner);
		projectiles = List!BallisticProjectileInstance(allocator, 100);
		particleCollection = coll;
		
		Game.router.setMessageHandler(IncomingMessages.ballisticValue,		&handleValue);
		Game.router.setMessageHandler(IncomingMessages.ballisticDirection,	&handleDirection);
		Game.router.setMessageHandler(IncomingMessages.ballisticLaunch,		&handleLaunch);
	}

	void launch(int towerIndex, bool bigBoom)
	{
		auto pressureCost = bigBoom ? instances[towerIndex].bigBoomCost : instances[towerIndex].smallBoomCost;
		auto  prefabIndex = bigBoom ? instances[towerIndex].bigBoomPrefabIndex 
									: instances[towerIndex].smallBoomPrefabIndex;
		pressure(towerIndex, max(0,	pressure(towerIndex)
											-	pressureCost));
		auto target = Polar!float(
							instances[towerIndex].angle,
							instances[towerIndex].distance).toCartesian;
		projectiles ~= BallisticProjectileInstance(
									prefabIndex,
									position(towerIndex),
									position(towerIndex) + target,
									owner.tileSize.x);
	}

	override void update(List!BaseEnemy enemies)
	{


		// Update all non-homing projectiles
		for(int i = projectiles.length - 1; i >= 0; --i)
		{
			projectiles[i].position += projectiles[i].velocity * Time.delta;
			
			if(distance(projectiles[i].position, projectiles[i].target)
			   < 10)
			{
				auto proj = projectiles[i];
				Game.sound.playSound(proj.sound);
				void makeExplosion()
				{
					foreach(ref enemy; enemies)
					{
						if(distance(enemy.position, proj.position) 
						   < proj.radius * owner.tileSize.x)
							enemy.health -= proj.damage;
					}
				}
				particleCollection.addEffect(proj.explosion, 
											 proj.position,
											 &makeExplosion);

				projectiles.removeAt(i);
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
				auto distance = min(tower.distance, range(tower));
				auto vecToTarget = Polar!float(tower.angle, distance).toCartesian();
				auto position = position(tower) + vecToTarget;


				Game.renderer.addFrame(targetFrame, position, Color.white, Game.window.relativeScale, origin);
			}
			auto position = position(tower);
		}

		foreach(projectile; projectiles)
		{
			auto size = float2(projectile.frame.width, projectile.frame.height);
			auto origin = size/2;
			Game.renderer.addFrame(	projectile.frame, projectile.position, Color.white, Game.window.relativeScale, origin, 
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
		msg.smallBoomCost = instances[towerIndex].smallBoomCost;
		msg.bigBoomCost = instances[towerIndex].bigBoomCost;

		Game.server.sendMessage(playerID, msg);
	}

	override void towerExited(int towerIndex, ulong playerID) { }

	void handleValue(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint;
		auto y = msg.read!uint;
		auto value = msg.read!float;

		auto index = indexOf(uint2(x,y));
		if(index != -1)
		{
			auto distance = range(index) * value;
			instances[index].distance = distance;
		}
	}

	void handleDirection(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint;
		auto y = msg.read!uint;
		auto value = msg.read!float;

		auto index = indexOf(uint2(x,y));
		if(index != -1)
			instances[index].angle = value;
	}	

	void handleLaunch(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint;
		auto y = msg.read!uint;
		auto bigBoom = msg.read!ubyte == 1;

		auto index = indexOf(uint2(x,y));
		if(index != -1)
			launch(index, bigBoom);
	}
}
