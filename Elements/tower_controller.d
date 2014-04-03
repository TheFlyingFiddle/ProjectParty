module tower_controller;
import math;
import collections;
import types;

interface ITowerController
{
	@property TileType type();
	void buildTower(float2 position, uint prototypeIndex);
	uint hasTower(uint2 cell, uint2 tileSize);
	void removeTower(uint towerIndex);
	void upgradeTower(uint towerIndex, uint upgradeIndex);
	Tower metaTower(uint towerIndex, List!Tower metas);

	void sendTowerInfo(uint towerIndex);
}

abstract class TowerController(T) : ITowerController
{
	List!T instances;
	TileType _type;

	@property TileType type() { return _type; }


	this(List!T instances, TileType type)
	{	
		this.instances = instances;
		this._type = type;
	}

	final Tower metaTower(uint towerIndex, List!Tower metas)
	{
		import std.algorithm;
		return metas.find!(x => x.type == type && x.typeIndex == instances[towerIndex].prefab)[0];
	}
	
	final void buildTower(float2 position, uint prototypeIndex)
	{
		instances ~= T(position, prototypeIndex);
	}

	final uint hasTower(uint2 cell, uint2 tileSize)
	{
		return instances.countUntil!(x => x.cell(tileSize) == cell);
	}

	final void removeTower(uint towerIndex)
	{
		instances.removeAt(towerIndex);
	}

	final void upgradeTower(uint towerIndex, uint upgradeIndex)
	{
		float2 position = instances[towerIndex].position;
		removeTower(towerIndex);
		buildTower(position, upgradeIndex);
	}
}