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
import enemy_controller;
import util.bitmanip;

struct VentInstance
{
	static List!VentTower prefabs;
	
	int prefab;
	int baseIndex;
	float direction;
	float open;
	
	this(int prefab, int baseIndex)
	{
		this.prefab = prefab;
		this.baseIndex = baseIndex;
		this.direction = 0;
		this.open = 1;
	}

	auto ref opDispatch(string property)()
	{
		mixin("return prefabs[prefab]." ~ property ~ ";");
	}

}

struct VentTower
{
	float damage;
	@Convert!unitToRadiance() float spread;
	StatusConfig status;
	@Convert!stringToFrame() Frame frame;
	@Convert!stringToFrame() Frame towerFrame;
}

float unitToRadiance(float value)
{
	return value * TAU;
}

final class VentController : TowerController!VentInstance
{
	this(A)(ref A allocator, TowerCollection owner)
	{
		super(allocator, TileType.vent, owner);

		import network_types;
		Game.router.setMessageHandler(IncomingMessages.ventValue,		&handleVentValue);
		Game.router.setMessageHandler(IncomingMessages.ventDirection,	&handleVentDirection);
	}

	void update(List!BaseEnemy enemies)
	{
		foreach(i, ref instance; instances) if(!isBroken(instance))
		{
			if(instance.open>0 && pressure(i) > 0)
			{
				pressure(i, max(0, instance.open * Time.delta));
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
		}
	}

	void hitEnemy(ref VentInstance vent, ref BaseEnemy enemy) 
	{
		enemy.health -= vent.damage * Time.delta * vent.open;
		enemy.applyStatus(vent.status);
	}

	void render(List!BaseEnemy enemies)
	{
		foreach(i, tower; instances) if(!isBroken(tower))
		{
			auto position = position(i);



			if ( tower.open > 0 && pressure(i) > 0) {
				Color color = Color.white;
				auto origin = float2(0, tower.frame.height/2);
				float2 scale = float2(range(tower) / tower.frame.width, 1);

				Game.renderer.addFrame(tower.frame, position, color, scale, origin, tower.direction);
			}
		}
	}

	override void towerEntered(int towerIndex, ulong playerID)
	{

	}

	override void towerExited(int towerIndex, ulong playerID)
	{

	}


	void handleVentValue(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint;
		auto y = msg.read!uint;
		auto value = msg.read!float;

		auto index = indexOf(uint2(x,y));
		if(index != -1)
			instances[index].open = value;
	}

	void handleVentDirection(ulong id, ubyte[] msg)
	{
		auto x = msg.read!uint;
		auto y = msg.read!uint;
		auto value = msg.read!float;

		auto index = indexOf(uint2(x,y));
		if(index != -1)
			instances[index].direction = value;
	}
}
