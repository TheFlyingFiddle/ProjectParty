module tower_controller;
import math;
import collections;
import types;
import std.conv;

interface ITowerController
{
	@property TileType type();
	void buildTower(float2 position, uint prototypeIndex);
	uint towerIndex(uint2 cell, uint2 tileSize);
	void removeTower(uint towerIndex);
	void upgradeTower(uint towerIndex, uint upgradeIndex);
	Tower metaTower(uint towerIndex, List!Tower metas);
	void breakTower(uint towerIndex);
	void repairTower(uint towerIndex);
	void towerEntered(uint towerIndex, ulong playerID);
	void towerExited(uint towerIndex, ulong playerID);
	void update(List!Enemy enemies);
}

struct TowerCommon
{
	float2 position;
	bool isBroken;
}

uint2 cell(T)(T t, uint2 tileSize)
{
	return uint2((t.position.x - tileSize.x/2) / tileSize.x, 
					 (t.position.y - tileSize.y/2) / tileSize.y);
}

struct TowerCollection
{
	List!ITowerController controllers;

	this(A)(ref A allocator)
	{
		this.controllers = List!ITowerController(allocator, 10);
	}

	final void buildTower(float2 position, ubyte type, uint prototype)
	{
		foreach(tc; controllers)
		{
			if(tc.type == type)
			{
				tc.buildTower(position, prototype);
			}
		}

	}

	auto ref opDispatch(string method, Args...)(uint2 pos, uint2 tileSize, Args args)
	{	
		
		foreach(tc; controllers)
		{
			auto index = tc.towerIndex(pos, tileSize);
			if(index != -1)
			{
				mixin("return tc." ~ method ~ "(index, args);");
			}
		}

		assert(0, text("Failed to find a tower for cell ",pos));
	}

	void update(List!Enemy enemies)
	{
		foreach(tc; controllers)
			tc.update(enemies);
	}

	void add(T)(T t)
	{
		this.controllers ~= cast(ITowerController)t;
	}
}

abstract class TowerController(T) : ITowerController
{
	List!T instances;
	List!TowerCommon common;

	TileType _type;

	@property TileType type() { return _type; }

	this(A)(ref A allocator, TileType type)
	{	
		this.instances				= List!T(allocator, 100);
		this.common					= List!TowerCommon(allocator, 100);
		this._type = type;
	}

	final Tower metaTower(uint towerIndex, List!Tower metas)
	{
		import std.algorithm;
		return metas.find!(x => x.type == type && x.typeIndex == instances[towerIndex].prefab)[0];
	}

	final float2 position(uint towerIndex)
	{
		return common[towerIndex].position;
	}

	final bool isBroken(uint towerIndex)
	{
		return common[towerIndex].isBroken;
	}
	
	final void buildTower(float2 position, uint prototypeIndex)
	{
		common    ~= TowerCommon(position, false);
		instances ~= T(prototypeIndex);
	}

	final uint towerIndex(uint2 cell, uint2 tileSize)
	{
		return common.countUntil!(x => x.cell(tileSize) == cell);
	}

	final void removeTower(uint towerIndex)
	{
		instances.removeAt(towerIndex);
		common.removeAt(towerIndex);
	}

	final void upgradeTower(uint towerIndex, uint upgradeIndex)
	{
		float2 position = common[towerIndex].position;
		removeTower(towerIndex);
		buildTower(position, upgradeIndex);
	}

	final void repairTower(uint towerIndex)
	{
		common[towerIndex].isBroken = false;
	}

	final void breakTower(uint towerIndex)
	{
		common[towerIndex].isBroken = true;
	}
}