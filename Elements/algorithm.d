module algorithm;

import math, enemy_collection, collections;

int findNearestEnemy(List!BaseEnemy enemies, float2 position)
{
	int index = -1;
	auto lowestDistance = float.max;

	foreach(i, ref enemy; enemies) 
	{
		float distance = distance(enemy.position, position);

		if(index == -1 || distance < lowestDistance)
		{
			index = i;
			lowestDistance = distance;
		}

	}
	return index;
}

int findFarthestReachableEnemy(List!BaseEnemy enemies, float2 towerPos, float range)
{
	auto index = -1;

	foreach(i, ref enemy; enemies)
	{
		float distance = distance(enemy.position, towerPos);
		if (distance <= range)
		{
			if(index == -1)
				index = i;
			else if (enemy.distance > enemies[index].distance)
				index = i;
		}
	}
	return index;
}

int findNearestReachableEnemy(List!BaseEnemy enemies, float2 towerPos, float range)
{
	int index = -1;
	float lowestDistance = float.infinity;
	foreach(i, ref enemy; enemies)
	{
		float distance = distance(enemy.position, towerPos);
		if (distance <= range)
		{
			if(index == -1)
			{
				index = i;
				lowestDistance = distance;
			}
			else if (distance < lowestDistance)
			{
				index = i;
				lowestDistance = distance;
			}
		}
	}
	return index;
}
