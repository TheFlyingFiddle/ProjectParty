module vent;
import math;
import collections;
import math.polar;
import types;
import content;
import graphics;
import game;
import game.debuging;
import std.algorithm : max, min;
import tower_controller;
import enemy_collection;
import util.bitmanip;
import network_types;

struct VentInstance
{
	static List!VentTower prefabs;
	
	int prefab;
	int baseIndex;
	float direction;
	float open;
	ulong particleID;
	
	this(int prefab, int baseIndex)
	{
		this.prefab = prefab;
		this.baseIndex = baseIndex;
		this.direction = 0;
		this.open = 0;
	}

	auto ref opDispatch(string property)()
	{
		mixin("return prefabs[prefab]." ~ property ~ ";");
	}

}

struct VentTower
{
	float damage;
	float fullyOpen;
	@Convert!unitToRadiance() float spread;
	StatusConfig status;
	@Convert!stringToParticle() ParticleEffectConfig particleConfig;
}

float unitToRadiance(float value)
{
	return value * TAU;
}

final class VentController : TowerController!VentInstance
{

	ParticleCollection particleCollection;
	this(A)(ref A allocator, TowerCollection owner, ParticleCollection coll)
	{
		super(allocator, TileType.vent, owner);

		particleCollection = coll;

		import network_types;
		Game.router.setMessageHandler(IncomingMessages.ventValue,		&handleVentValue);
		Game.router.setMessageHandler(IncomingMessages.ventDirection,	&handleVentDirection);
	}

	override void update(List!BaseEnemy enemies)
	{
		particleCollection.update(Time.delta);
		foreach(i, ref instance; instances) if(!isBroken(instance))
		{
			if(instance.open > 0)
			{
				pressure(i) = max(0, pressure(i) - instance.fullyOpen * instance.open * Time.delta);
				if(pressure(i) > 0)
				{
					foreach(ref enemy; enemies) 
					{
						if(distance(enemy.position, position(i)) <= range(instance)) {
							auto angle = (enemy.position - position(i)).toPolar.angle;
							if(instance.direction - instance.spread / 2 < angle && 
								   instance.direction + instance.spread / 2 > angle) {
									hitEnemy(instance, enemy);
							}
						}
					}
				}
				else
				{
					setOpen(i, 0);
				}
			}
		}

		super.update(enemies);
	}

	void setOpen(int index, float value)
	{
		if(value > 0)
			particleCollection.play(instances[index].particleID);
		else
			particleCollection.pause(instances[index].particleID);
		particleCollection[instances[index].particleID].particleMultiplier = value;
		instances[index].open = value;
	}

	void hitEnemy(ref VentInstance vent, ref BaseEnemy enemy) 
	{
		enemy.health -= vent.damage * Time.delta * vent.open;
		enemy.applyStatus(vent.status);
	}

	void render(List!BaseEnemy enemies)
	{

	}

	override void towerEntered(int towerIndex, ulong playerID)
	{
		VentInfoMessage msg;
		msg.pressure	= pressure(towerIndex);
		msg.maxPressure = maxPressure;
		msg.direction   = instances[towerIndex].direction;
		msg.open        = instances[towerIndex].open;

		import network.message;
		Game.server.sendMessage(playerID, msg);
	}

	override void towerExited(int towerIndex, ulong playerID)
	{

	}

	override void towerBuilt(int baseTowerIndex, int instanceIndex)
	{
		instances[instanceIndex].particleID = particleCollection.addEffect(instances[instanceIndex].particleConfig, position(instanceIndex));
		auto extender = particleCollection.getExtender!(ParticleEmitterExtender!ConeEmitter);
		foreach(i, _; extender.emitters) if (extender.id(i) == instances[instanceIndex].particleID)
		{
			extender.emitters[i].common.speed = range(instanceIndex);
		}
	}

	override void towerRemoved(BaseTower base, VentInstance vent)
	{
		particleCollection.removeID(vent.particleID);
	}

	override void towerRepaired(int instanceIndex)
	{
		if(instances[instanceIndex].open > 0)
			particleCollection.play(instances[instanceIndex].particleID);
		else
			particleCollection.pause(instances[instanceIndex].particleID);
	}

	override void towerBroken(int instanceIndex)
	{
		particleCollection.pause(instances[instanceIndex].particleID);	
	}

	void handleVentValue(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint;
		auto y = msg.read!uint;
		auto value = msg.read!float;

		auto index = indexOf(uint2(x,y));
		if(index != -1)
		{
			setOpen(index, value);
		}
	}

	void handleVentDirection(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint;
		auto y = msg.read!uint;
		auto value = msg.read!float;

		auto index = indexOf(uint2(x,y));
		if(index != -1)
		{
			auto extender = particleCollection.getExtender!(ParticleEmitterExtender!ConeEmitter);
			foreach(i, _; extender.emitters) if (extender.id(i) == instances[index].particleID)
			{
				extender.emitters[i].angle = value;
				extender.emitters[i].width = instances[index].spread;
			}
			instances[index].direction = value;
		}
	}
}
