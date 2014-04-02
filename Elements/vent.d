module vent;
import math;
import collections;
import types;
import content;
import graphics;
import game;
import game.debuging;
import std.algorithm : max, min;


struct VentInstance
{
	static List!VentTower prototypes;
	int index;
	float2 position;
	float direction;
	float pressure;
	float open;
	

	this(float2 position, int index)
	{
		this.index = index;
		this.position = position;
		this.direction = 0;
		this.pressure = maxPressure;
		this.open = 1;
	}

	@property float damage()
	{
		return prototypes[index].damage;
	}

	@property float range()
	{
		return prototypes[index].range;
	}

	@property float maxPressure()
	{
		return prototypes[index].maxPressure;
	}
	
	@property float regenRate()
	{
		return prototypes[index].regenRate;
	}

	@property ref Frame frame()
	{
		return prototypes[index].frame;
	}

	@property ref Frame towerFrame()
	{
		return prototypes[index].towerFrame;
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

struct VentController
{
	List!VentInstance instances;

	this(A)(ref A allocator)
	{
		this.instances = List!VentInstance(allocator, 100);
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
		auto coneTexture = Game.content.loadTexture("cone");
		auto coneFrame = Frame(coneTexture);

		foreach(tower; instances)
		{		
			renderer.addFrame(tower.towerFrame, tower.position, Color.white, tileSize, tileSize/2);
			if ( tower.open > 0 && tower.pressure > 0) {
				Color color = Color.white;
				auto origin = float2(0, coneFrame.height/2);
				renderer.addFrame(coneFrame, tower.position, 
									   color, float2(tower.range, coneFrame.height), origin, tower.direction);
			}

			float amount = tower.pressure/tower.maxPressure;
			float sBWidth = min(50, tower.maxPressure);
			Game.renderer.addRect(float4(tower.position.x - sBWidth/2, tower.position.y + tileSize.y/2, 
										 sBWidth, 5), Color.blue);
			Game.renderer.addRect(float4(tower.position.x - sBWidth/2, tower.position.y + tileSize.y/2, 
										 sBWidth*amount, 5), Color.white);
		}
	}
}
