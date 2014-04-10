module tower_controller;
import math;
import collections;
import types;
import std.conv;
import enemy_collection;
import std.algorithm : countUntil, min, max;
import graphics;
import game;

enum maxPressure = 1000;

interface ITowerController
{
	@property TileType type();
	void buildTower(uint towerIndex, uint prototypeIndex);
	void removeTower(uint towerIndex);
	void enterTower(int towerIndex, ulong playerID);
	void exitTower(int towerIndex, ulong playerID);
	void update(List!BaseEnemy enemies);
	void render(List!BaseEnemy enemies);
}

struct BaseTower
{
	float2 position;
	bool isBroken;
	ulong ownedPlayerID;
	float pressure;
	float regenRate;
	uint metaIndex;
	float range;
	Frame frame;
}

uint2 cell(T)(T t, uint2 tileSize)
{
	return uint2((t.position.x - tileSize.x/2) / tileSize.x, 
					 (t.position.y - tileSize.y/2) / tileSize.y);
}

alias TowerBrokeHandler = void delegate(TowerCollection, uint);

final class TowerCollection
{
	uint2 tileSize;
	List!ITowerController controllers;
	List!BaseTower baseTowers;
	List!TowerBrokeHandler onTowerBroken;


	List!Tower metas;

	this(A)(ref A allocator, List!Tower metas, uint2 tileSize)
	{
		this.controllers	= List!ITowerController(allocator, 10);
		this.baseTowers		= List!BaseTower(allocator, 200);
		this.onTowerBroken	= List!TowerBrokeHandler(allocator, 10); 
		this.metas = metas;
		this.tileSize = tileSize;
	}

	final void buildTower(float2 position, ubyte metaIndex, ulong ownedPlayerID)
	{
		foreach(tc; controllers)
		{
			if(tc.type == metas[metaIndex].type)
			{
				baseTowers ~= BaseTower(position, false, ownedPlayerID, 
							maxPressure*metas[metaIndex].startPressure, 
										metas[metaIndex].regenRate, 
										metaIndex, 
										metas[metaIndex].range, 
										metas[metaIndex].towerFrame);
				tc.buildTower(metas[metaIndex].typeIndex, baseTowers.length - 1);
				return;
			}
		}
	}

	void addController(T)(T t)
	{
		this.controllers ~= cast(ITowerController)t;
	}


	uint towerIndex(uint2 cell, uint2 tileSize)
	{
		return baseTowers.countUntil!(x => x.cell(tileSize) == cell);
	}

	void removeTower(uint towerIndex)
	{
		baseTowers.removeAt(towerIndex);
		foreach(tc;controllers)
		{
			tc.removeTower(towerIndex);
		}
	}

	void upgradeTower(uint towerIndex, ubyte upgradeIndex)
	{
		auto pos = baseTowers[towerIndex].position;
		auto player = baseTowers[towerIndex].ownedPlayerID;
		removeTower(towerIndex);
		buildTower(pos, upgradeIndex, player);
	}

	final Tower metaTower(uint towerIndex)
	{
		import std.algorithm;
		return metas[baseTowers[towerIndex].metaIndex];
	}

	final int indexOf(uint2 position)
	{
		return baseTowers.countUntil!(x => x.cell(tileSize) == position);
	}

	void breakTower(uint towerIndex)
	{
		if(baseTowers[towerIndex].isBroken == false)
		{
			baseTowers[towerIndex].isBroken = true;
			foreach(handler; onTowerBroken)
				handler(this, towerIndex);
		}
	}

	void repairTower(uint towerIndex)
	{
		baseTowers[towerIndex].isBroken = false;
	}

	void enterTower(uint towerIndex, ulong playerID)
	{
		foreach(tc; controllers)
		{
			if(tc.type == metas[baseTowers[towerIndex].metaIndex].type)
			{
				tc.enterTower(towerIndex, playerID);
			}
		}
	}

	void exitTower(uint towerIndex, ulong playerID)
	{
		foreach(tc; controllers)
		{
			if(tc.type == metas[baseTowers[towerIndex].metaIndex].type)
			{
				tc.exitTower(towerIndex, playerID);
			}
		}
	}

	void update(ref List!BaseEnemy enemies)
	{
		foreach(ref tower; baseTowers)
		{
			tower.pressure = min(tower.pressure + tower.regenRate * Time.delta, maxPressure);
		}

		foreach(tc;controllers)
		{
			tc.update(enemies);
		}
	}

	void render(List!BaseEnemy enemies)
	{
		foreach(tower;baseTowers)
		{
			Color color = tower.isBroken ? Color(0xFF777777) : Color.white;
			Game.renderer.addFrame(tower.frame, float4(	tower.position.x, 
														tower.position.y, 
														tileSize.x, 
														tileSize.y), 
								color, float2(tileSize)/2);
		}



		foreach(tc;controllers)
		{
			tc.render(enemies);
		}
	
		foreach(ref tower; baseTowers) if(!tower.isBroken)
		{

			float amount = tower.pressure/maxPressure;
			float sBWidth = min(50, maxPressure);
			import game.debuging;
			Game.renderer.addRect(float4(tower.position.x - sBWidth/2, tower.position.y + tileSize.y/2, 
										 sBWidth, 5), Color.blue);
			Game.renderer.addRect(float4(tower.position.x - sBWidth/2, tower.position.y + tileSize.y/2, 
										 sBWidth*amount, 5), Color.white);
		}
	}
}

template isValidTowerType(T)
{
	enum isValidTowerType = __traits(compiles,
						 { 
							T t;
							 t.baseIndex = 1;
							 t.prefab = 1;
							 t = T(1,1);
						 });
}

abstract class TowerController(T) : ITowerController
{
	List!T instances;

	TowerCollection owner;

	struct Controlled { int instanceIndex; ulong playerID; }
	List!Controlled controlled;

	TileType _type;

	override @property TileType type() { return _type; }

	this(A)(ref A allocator, TileType type, TowerCollection owner)
	{	
		this.instances				= List!T(allocator, 100);
		this.controlled				= List!Controlled(allocator, 10);
		this._type = type;
		this.owner = owner;
		this.owner.addController(this);
	}

	final int indexOf(uint2 pos)
	{
		foreach(i, tower; instances)
		{
			if(owner.baseTowers[tower.baseIndex].cell(owner.tileSize) == pos)
				return i;
		}
		return -1;
	}

	final ref float2 position(ref T instance)
	{
		return owner.baseTowers[instance.baseIndex].position;
	}

	final float2 position(int instanceIndex)
	{
		return position(instances[instanceIndex]);
	}

	final ref bool isBroken(ref T instance)
	{
		return owner.baseTowers[instance.baseIndex].isBroken;
	}

	final ref bool isBroken(int instanceIndex)
	{
		return isBroken(instances[instanceIndex]);
	}

	final bool isControlled(int instanceIndex)
	{
		return controlled.countUntil!(x => x.instanceIndex == instanceIndex) != -1;
	}

	final ref float pressure(ref T instance)
	{
		return owner.baseTowers[instance.baseIndex].pressure;
	}

	final ref float pressure(int instanceIndex)
	{
		return pressure(instances[instanceIndex]);
	}

	final float range(ref T instance)
	{
		return owner.baseTowers[instance.baseIndex].range;
	}

	final void buildTower(uint prototypeIndex, uint towerIndex)
	{
		instances ~= T(prototypeIndex, towerIndex);
	}

	final void removeTower(uint towerIndex)
	{
		for(int i = instances.length - 1; i >= 0; i--)
		{
			if(instances[i].baseIndex > towerIndex)
			{
				instances[i].baseIndex--;
			}
			else if(instances[i].baseIndex == towerIndex)
			{
				instances.removeAt(i);
			}
		}
	}


	void update(List!BaseEnemy enemies)
	{
		import network.message, network_types;
		foreach(tower; controlled)
		{
			Game.server.sendMessage(
									tower.playerID, 
									PressureInfoMessage(pressure(tower.instanceIndex))
									);
		}
	}

	final void enterTower(int towerIndex, ulong playerID)
	{
		auto index = instances.countUntil!( x => x.baseIndex == towerIndex);
		if(isBroken(index))
			return;

		controlled ~= Controlled(index, playerID);
		towerEntered(index, playerID);
	}

	final void exitTower(int towerIndex, ulong playerID)
	{
		auto index = controlled.countUntil!( x => x.playerID == playerID);
		if(index != -1)
			controlled.removeAt(index);

		towerExited(index, playerID);
	}

	final void pressure(int towerIndex, float newPressure)
	{
		owner.baseTowers[instances[towerIndex].baseIndex].pressure = newPressure;
	}

	abstract void towerEntered(int instanceIndex, ulong playerID);
	abstract void towerExited(int instanceIndex, ulong playerID);
}
