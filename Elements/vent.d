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
	float2 position;
	float direction;
	float pressure;
	float open;
	

	this(float2 position, int prefab)
	{
		this.prefab = prefab;
		this.position = position;
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

	uint2 cell(uint2 tileSize)
	{
		return uint2((position.x - tileSize.x/2)/tileSize.x, 
					 (position.y - tileSize.y/2)/tileSize.y);
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
		super(List!VentInstance(allocator, 100), TileType.vent);
	}

	void update(List!Enemy enemies)
	{
		foreach(ref instance; instances)
		{
			if(instance.open>0 && instance.pressure > 0)
			{
				instance.pressure -= instance.open * Time.delta;
				instance.pressure = max(0, instance.pressure);
				foreach(ref enemy; enemies) if(distance(enemy.position, instance.position) <= instance.range)
				{
					enemy.health -= instance.damage * Time.delta * instance.open;
				}
			}
			if(instance.open == 0)
				instance.pressure = min(instance.pressure + instance.regenRate * Time.delta, instance.maxPressure);
		}
	}

	void render(Renderer* renderer, float2 tileSize)
	{
		foreach(tower; instances)
		{		
			renderer.addFrame(tower.towerFrame, tower.position, Color.white, tileSize, tileSize/2);
			if ( tower.open > 0 && tower.pressure > 0) {
				Color color = Color.white;
				auto origin = float2(0, tower.frame.height/2);
				renderer.addFrame(tower.frame, tower.position, 
									   color, float2(tower.range, tower.frame.height), origin, tower.direction);
			}

			float amount = tower.pressure/tower.maxPressure;
			float sBWidth = min(50, tower.maxPressure);
			Game.renderer.addRect(float4(tower.position.x - sBWidth/2, tower.position.y + tileSize.y/2, 
										 sBWidth, 5), Color.blue);
			Game.renderer.addRect(float4(tower.position.x - sBWidth/2, tower.position.y + tileSize.y/2, 
										 sBWidth*amount, 5), Color.white);
		}
	}

	void sendTowerInfo(uint towerIndex)
	{
		//Do something at a later point in time.
	}
}
