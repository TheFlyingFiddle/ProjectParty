module enemy_collection;
import game, math, graphics, collections, types, tower_controller, spriter.types, spriter.renderer;

enum AnimationState : string
{
	walk = "walk",
	frozen = "frozen"
}

struct BaseEnemy {
	static List!Path paths;

	float distance;
	float speed;
	float health;
	float maxHealth;
	uint pathIndex;
	int worth;
	SpriteInstance sprite;
	Status status;

	this(EnemyPrefab prefab, uint pathIndex)
	{
		this.distance = 0;
		this.speed = prefab.speed;
		this.health = prefab.maxHealth;
		this.maxHealth = prefab.maxHealth;
		this.worth = prefab.worth;
		this.sprite = prefab.spriteID.animationInstance(AnimationState.walk);
		this.pathIndex = pathIndex;
	}

	@property float2 position()
	{
		return paths[pathIndex].position(distance);
	}

	void updateStatus(float delta)
	{
		status.duration -= delta;
		if(status.duration < 0) 
		{
			this.status.type = StatusType.none;
			return;
		} 

		if(status.type == StatusType.burning)
		{
			this.health -= status.value * delta;
		} 
		else if (status.type == StatusType.cold) 
		{
			this.distance -= this.speed * delta * status.value;
		}
	}

	void applyStatus(StatusConfig toApply)
	{
		final switch(toApply.type) 
		{
			case StatusEffect.water:
				applyWater(toApply.duration, toApply.value);
				break;
			case StatusEffect.fire:
				applyFire(toApply.duration, toApply.value);
				break;
			case StatusEffect.oil:
				applyOil(toApply.duration, toApply.value);
				break;
			case StatusEffect.liqNit:
				applyLiqNit(toApply.duration, toApply.value);
				break;
		}
	}

	void applyWater(float duration, float amount)
	{
		import std.algorithm;
		final switch(status.type) with (StatusType)
		{
			case none: 
				status.type = watered;
				status.duration = duration;
				status.value = amount;
				break;
			case watered:
				status.duration = max(status.duration, duration);
				status.value = max(status.value, amount);
				break;
			case burning:
				status.duration = 0;
				break;
			case oiled:
			case cold:
				break;
		}
	}

	void applyFire(float duration, float dps)
	{
		import std.algorithm;
		final switch(status.type) with (StatusType)
		{
			case watered:
				status.type = none;
				break;
			case oiled:
				status.type = burning;
				status.duration = duration * status.value;
				status.value = dps;
				break;
			case cold:
			case burning:
			case none:
				break;
		}
	}

	void applyOil(float duration, float amount)
	{
		import std.algorithm;
		final switch(status.type) with (StatusType)
		{
			case none: 
				status.type = oiled;
				status.duration = duration;
				status.value = amount;
				break;
			case oiled:
				status.duration = max(status.duration, duration);
				status.value = max(status.value, amount);
				break;
			case burning:
				status.duration = max(status.duration, duration);
				break;
			case watered:
			case cold:
				break;
		}
	}

	void applyLiqNit(float duration, float amount)
	{
		import std.algorithm;
		final switch(status.type) with (StatusType)
		{
			case none:
			case oiled:
				status.type = cold;
				status.duration = duration;
				status.value = amount;
				break;
			case burning:
				status.type = none;
				break;
			case watered:
				status.type = cold;
				status.duration = status.value * duration;
				status.value = 1;
				break;
			case cold:
				if(status.value > 0.999) return;
				status.duration = max(status.duration, duration);
				break;
		}
	}
}

alias EnemyDeathHandler = void delegate(EnemyCollection, BaseEnemy, uint);
alias EnemyAtEndHandler = void delegate(EnemyCollection, BaseEnemy, uint);


class EnemyCollection
{
	List!BaseEnemy enemies;
	List!EnemyDeathHandler onDeath;
	List!EnemyAtEndHandler onAtEnd;
	List!IEnemyController controllers;
	List!Path paths;
	List!EnemyPrefab enemyPrototypes;

	this(A)(ref A allocator, List!EnemyPrefab prefabs)
	{
		enemies		= List!BaseEnemy(allocator, 512);
		onDeath		= List!EnemyDeathHandler(allocator, 16);
		onAtEnd		= List!EnemyDeathHandler(allocator, 16);
		controllers = List!IEnemyController(allocator,  16);
		enemyPrototypes = prefabs;
	}

	void addEnemy(ref EnemyPrefab prefab, int pathIndex)
	{
		enemies ~= BaseEnemy(prefab, pathIndex);
		foreach(ref component; prefab.components)
		{
			foreach(controller; controllers)
			{
				if(controller.type == component.type)
					controller.addEnemy(component, enemies.length - 1);
			}
		}
	}	

	void update(TowerCollection towers)
	{
		for (int i = enemies.length -1; i >=0; i--)
		{
			enemies[i].sprite.update(Time.delta*enemies[i].speed/50);
			enemies[i].updateStatus(Time.delta);
			enemies[i].distance += enemies[i].speed * Time.delta;
			if (enemies[i].distance < 0)
				enemies[i].distance = 0;
			if (enemies[i].distance > paths[enemies[i].pathIndex].endDistance)
			{
				foreach(method; onAtEnd)
					method(this, enemies[i], i);
				
				//Super temp fix for crashing bugs 
				//(need to use location of enemy to handle death, needs to be valid)
				enemies[i].distance = paths[enemies[i].pathIndex].endDistance - 10f;

				killEnemy(i);
			}
		}

		foreach(controller; controllers)
			controller.update(towers);
	}

	void killEnemies()
	{
		for(int i = enemies.length -1; i >= 0; i--)
		{
			if(enemies[i].health <= 0)
			{
				killEnemy(i);
			}
		}
	}


	void killEnemy(int enemyIndex)
	{
		auto enemy = enemies[enemyIndex];
		enemies.removeAt(enemyIndex);
		foreach(handler; onDeath)
			handler(this, enemy, enemyIndex);

	}

	void render() 
	{
		foreach(ref enemy; enemies)
		{
			Color color;

			final switch(enemy.status.type) with (StatusType)
			{
				case none:
					color = Color.white;
					break;
				case watered:
					color = Color.blue;
					break;
				case burning:
					color = Color.red;
					break;
				case oiled:
					color = Color.black;
					break;
				case cold:
					color = Color(0xFFFF5500);
					break;
			}

			float2 position = enemy.position;
			Game.renderer.addSprite(enemy.sprite, position, color, Game.window.relativeScale);
		}
	
		import std.algorithm, game.debuging;

		foreach(ref enemy; enemies)
		{
			float2 position = enemy.position;
			
			//TODO: This is not good. Fix this.
			float2 origin = float2(32,32) * Game.window.relativeScale;
			float amount = enemy.health/enemy.maxHealth;
			float width = min(50, enemy.maxHealth) * Game.window.relativeScale.x;
			float height = 5 * Game.window.relativeScale.y;
			Game.renderer.addRect(float4(position.x - width/2, position.y + origin.y, 
										 width, height), Color.red);
			Game.renderer.addRect(float4(position.x - width/2, position.y + origin.y, 
										 width*amount, height), Color.green);
		}

		foreach(controller; controllers)
			controller.render();
	}

	void addController(T)(T t)
	{
		this.controllers ~= cast(IEnemyController)t;
	}
}

interface IEnemyController
{
	@property ComponentType type();
	void addEnemy(ref EnemyComponentPrefab prefab, uint baseIndex);
	void update(TowerCollection towers);
	void render();
}

template isValidEnemyType(T)
{
	enum isValidEnemyType = 
	__traits(compiles,
	{
		EnemyComponentPrefab prefab;
		T t = T(prefab);
		t.baseIndex = 0;
	});
}

abstract class EnemyController(T, ComponentType _type) : IEnemyController
	if(isValidEnemyType!T)
{
	EnemyCollection owner;
	List!T instances;

	@property ComponentType type() { return _type; }

	this(A)(ref A allocator, EnemyCollection collection)
	{
		this.instances  = List!T(allocator, 100);

		this.owner = collection;
		this.owner.addController(this);
		this.owner.onDeath ~= &onEnemyRemoval;
	}

	auto ref opDispatch(string method)(int instanceIndex)
	{
		mixin("return owner.enemies[instances[instanceIndex]]." ~ method ~ "();");
	}

	void addEnemy(ref EnemyComponentPrefab prefab, uint baseIndex)
	{
		T instance = T(prefab);
		instance.baseIndex = baseIndex;
		instances ~= instance;
	}

	auto ref BaseEnemy base(ref T instance)
	{
		return owner.enemies[instance.baseIndex];
	}

	void onEnemyRemoval(EnemyCollection collection, BaseEnemy enemy, uint index)
	{
		for(int i = instances.length - 1; i >= 0; i--)
		{
			if(instances[i].baseIndex > index)
				instances[i].baseIndex--;
			else if(instances[i].baseIndex == index)
				instances.removeAt(i);
		}
	}
}