module enemy;

import enemy_collection, tower_controller, types, game, math;

struct SpeedupEnemy
{
	float interval;
	float duration;
	float elapsed;
	float amount;
	uint baseIndex;
	bool  fast;

	this(ref EnemyComponentPrefab prefab)
	{
		this.interval = prefab.interval;
		this.duration = prefab.duration;
		this.amount   = prefab.amount;

		this.elapsed  = 0;
		this.fast	  = false;
	}
}

class SpeedupEnemyController : EnemyController!(SpeedupEnemy, ComponentType.speedup)
{
	this(A)(ref A allocator, EnemyCollection collection)
	{
		super(allocator, collection);
	}

	void update(TowerCollection towers)
	{
		foreach(ref instance; instances)
		{		
			instance.elapsed += Time.delta;
			if(instance.fast && instance.elapsed >= instance.duration)
			{
				instance.elapsed -= instance.duration;
				slowDown(instance);
			}
			else if(!instance.fast && instance.elapsed >= instance.interval)
			{
				instance.elapsed -= instance.interval;
				speedUp(instance);
			}
		}
	}

	void render() 
	{
		//IDK maby put something here or not...
	}

	void speedUp(ref SpeedupEnemy enemy)
	{
		owner.enemies[enemy.baseIndex].speed *= enemy.amount;
		enemy.fast = true;
	}

	void slowDown(ref SpeedupEnemy enemy)
	{
		owner.enemies[enemy.baseIndex].speed /= enemy.amount;
		enemy.fast = false;
	}
}

struct HealerEnemy 
{
	float interval;
	float elapsed;
	float amount;
	uint baseIndex;

	this(ref EnemyComponentPrefab prefab)
	{
		this.interval = prefab.interval;
		this.amount   = prefab.amount;
		this.elapsed  = 0;
	}
}

class HealerEnemyController : EnemyController!(HealerEnemy, ComponentType.heal)
{
	this(A)(ref A allocator, EnemyCollection collection)
	{
		super(allocator, collection);
	}

	void update(TowerCollection towers)
	{
		foreach(ref instance; instances)
		{		
			instance.elapsed += Time.delta;
			if(instance.elapsed >= instance.interval)
			{
				instance.elapsed -= instance.interval;
				heal(instance);
			}
		}
	}

	void render() { } 

	void heal(ref HealerEnemy enemy)
	{
		import std.algorithm;
		base(enemy).health = min(base(enemy).maxHealth, base(enemy).health + enemy.amount);
	}
}


struct TowerBreakerEnemy
{
	float interval;
	float elapsed;
	float range;
	uint baseIndex;

	this(ref EnemyComponentPrefab prefab)
	{
		this.interval = prefab.interval;
		this.range    = prefab.range;
		this.elapsed  = 0;
	}
}

class TowerBreakerEnemyController : EnemyController!(TowerBreakerEnemy, ComponentType.towerBreaker)
{
	this(A)(ref A allocator, EnemyCollection collection)
	{
		super(allocator, collection);
	}

	void update(TowerCollection towers)
	{
		foreach(ref instance; instances)
		{		
			instance.elapsed += Time.delta;
			if(instance.elapsed >= instance.interval)
			{
				instance.elapsed -= instance.interval;
				breakTower(instance, towers);
			}
		}
	}

	void render() 
	{

	}

	void breakTower(ref TowerBreakerEnemy enemy, TowerCollection towers)
	{
		foreach(i, t; towers.baseTowers)
		{
			if( distance(base(enemy).position, t.position) 
				< enemy.range && !t.isBroken)
			{
				towers.breakTower(i);
				return;
			}
		}
	}
}


struct StatusRemoverEnemy
{
	float interval;
	float elapsed;
	StatusType type;
	uint baseIndex;

	this(ref EnemyComponentPrefab prefab)
	{
		this.interval	= prefab.interval;
		this.type       = prefab.statusType;
		this.elapsed = 0;
	}
}

class StatusRemoverEnemyController : EnemyController!(StatusRemoverEnemy, ComponentType.statusRemover)
{
	this(A)(ref A allocator, EnemyCollection collection)
	{
		super(allocator, collection);
	}

	void update(TowerCollection towers)
	{
		foreach(ref instance; instances)
		{		
			instance.elapsed += Time.delta;
			if(instance.elapsed >= instance.interval)
			{
				instance.elapsed -= instance.interval;
				removeStatus(instance);
			}
		}
	}

	void render() 
	{

	}

	void removeStatus(ref StatusRemoverEnemy enemy)
	{
		if(base(enemy).status.type == enemy.type)
			base(enemy).status.type = StatusType.none;
	}
}
