module vent;
import math;
import collections;
import types;
import content;
import graphics;
import game;
import game.debuging;
import std.algorithm : max, min;
import tower_controller;

struct VentInstance
{
	static List!VentTower prototypes;
	int prefab;
	float direction;
	float pressure;
	float open;
	

	this(int prefab)
	{
		this.prefab = prefab;
		this.direction = 0;
		this.pressure = maxPressure;
		this.open = 1;
	}

	@property float damage()
	{
		return prototypes[prefab].damage;
	}

	@property float range()
	{
		return prototypes[prefab].range;
	}

	@property float maxPressure()
	{
		return prototypes[prefab].maxPressure;
	}
	
	@property float regenRate()
	{
		return prototypes[prefab].regenRate;
	}

	@property ref Frame frame()
	{
		return prototypes[prefab].frame;
	}

	@property ref Frame towerFrame()
	{
		return prototypes[prefab].towerFrame;
	}
}

struct VentTower
{
	float damage;
	float range;
	float maxPressure;
	float regenRate;
	@Convert!stringToFrame() Frame frame;
	@Convert!stringToFrame() Frame towerFrame;
}

final class VentController : TowerController!VentInstance
{
	this(A)(ref A allocator)
	{
		super(allocator, TileType.vent);
	}

	void update(List!Enemy enemies)
	{
		foreach(i, ref instance; instances) if(!isBroken(i))
		{
			if(instance.open>0 && instance.pressure > 0)
			{
				instance.pressure -= instance.open * Time.delta;
				instance.pressure = max(0, instance.pressure);
				foreach(ref enemy; enemies) 
				{

					if(distance(enemy.position, position(i)) <= instance.range)
						enemy.health -= instance.damage * Time.delta * instance.open;
				}
			}
			if(instance.open == 0)
				instance.pressure = min(instance.pressure + instance.regenRate * Time.delta, instance.maxPressure);
		}
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
		}
	}

	void towerEntered(uint towerIndex, ulong playerID)
	{

	}

	void towerExited(uint towerIndex, ulong playerID)
	{

	}
}
