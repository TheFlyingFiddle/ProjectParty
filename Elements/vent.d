module vent;
import math;
import collections;
import types;
import content;
import graphics;
import game;
import std.algorithm : max;


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
		this.pressure = 0;
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
			if(instance.open>0)
			{
				instance.pressure -= instance.open;
				instance.pressure = max(0, instance.pressure);
				
				foreach(ref enemy; enemies) if(distance(enemy.position, instance.position) <= instance.range)
				{
					enemy.health -= instance.damage * Time.delta * instance.open;
				}
			}
		}

//		tower.elapsed += Time.delta;
//		if ( tower.cTower.elapsed < tower.cTower.activeTime)
//		{
//			float2 towerPos = tower.pixelPos(level.tileSize);
//			int index = findNearestReachableEnemy(towerPos, tower.range);
//			if(index != -1)
//			{
//				auto angle = (towerPos - level.path.position(enemies[index].distance)).toPolar.angle;
//				foreach(i, ref enemy; enemies) if(distance(towerPos, level.path.position(enemy.distance)) < tower.range)
//				{
//					auto eAngle = (towerPos - level.path.position(enemy.distance)).toPolar.angle;
//					if(eAngle > (angle - tower.cTower.width/2)%TAU && eAngle < (angle + tower.cTower.width/2)%TAU)
//					{
//						enemy.health -= tower.cTower.dps * Time.delta;
//					}
//				}
//			}
//		} else if ( tower.cTower.elapsed > tower.cTower.reactivationTime) {
//			tower.cTower.elapsed = 0;
//		}
	}

	void render(Renderer* renderer)
	{
		auto coneTexture = Game.content.loadTexture("cone");
		auto coneFrame = Frame(coneTexture);
		foreach(tower; instances)
		{		
			auto size = float2(tower.towerFrame.width, tower.towerFrame.height);
			renderer.addFrame(tower.towerFrame, tower.position, Color.white, size, size/2);
			if ( tower.open > 0) {
				Color color = Color.white;
				auto origin = float2(0, coneFrame.height/2);
				renderer.addFrame(coneFrame, tower.position, 
									   color, float2(tower.range, coneFrame.height), origin, tower.direction);
			}
		}
	}
}
