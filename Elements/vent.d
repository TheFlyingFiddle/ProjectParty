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

struct VentInstance
{
	static List!VentTower prefabs;
	
	int prefab;
	float direction;
	float pressure;
	float open;
	
	this(int prefab)
	{
		this.prefab = prefab;
		this.direction = 0;
		this.pressure = this.maxPressure;
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
	float range;
	float maxPressure;
	float regenRate;
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
	this(A)(ref A allocator)
	{
		super(allocator, TileType.vent);
	}

	void update(List!BaseEnemy enemies)
	{
		foreach(i, ref instance; instances) if(!isBroken(i))
		{
			if(instance.open>0 && instance.pressure > 0)
			{
				instance.pressure -= instance.open * Time.delta;
				instance.pressure = max(0, instance.pressure);
				foreach(ref enemy; enemies) 
				{

					if(distance(enemy.position, position(i)) <= instance.range) {
						auto angle = (enemy.position - position(i)).toPolar.angle;
						if(instance.direction - instance.spread / 2 < angle && 
							   instance.direction + instance.spread / 2 > angle) {
								hitEnemy(instance, enemy);
						}
					}
				}
			}
			if(instance.open == 0)
				instance.pressure = min(instance.pressure + instance.regenRate * Time.delta, instance.maxPressure);
		}
	}

	void hitEnemy(ref VentInstance vent, ref BaseEnemy enemy) 
	{
		enemy.health -= vent.damage * Time.delta * vent.open;
		enemy.applyStatus(vent.status);
	}

	void render(Renderer* renderer, float2 tileSize)
	{
		foreach(i, tower; instances) if(!isBroken(i))
		{		
			auto position = position(i);

			renderer.addFrame(tower.towerFrame, position, Color.white, tileSize, tileSize/2);
			if ( tower.open > 0 && tower.pressure > 0) {
				Color color = Color.white;
				auto origin = float2(0, tower.frame.height/2);
				renderer.addFrame(tower.frame, position, color, float2(tower.range, tower.frame.height), origin, tower.direction);
			}

			float amount = tower.pressure/tower.maxPressure;
			float sBWidth = min(50, tower.maxPressure);
			Game.renderer.addRect(float4(position.x - sBWidth/2, position.y + tileSize.y/2, 
										 sBWidth, 5), Color.blue);
			Game.renderer.addRect(float4(position.x - sBWidth/2, position.y + tileSize.y/2, 
										 sBWidth*amount, 5), Color.white);

			Game.renderer.addCircleOutline(position, tower.range, Color(0x66FFFFAA));
		}
	}

	void towerEntered(uint towerIndex, ulong playerID)
	{

	}

	void towerExited(uint towerIndex, ulong playerID)
	{

	}
}
