module enemy_controller;
import game, math, graphics, collections, types;

struct BaseEnemy {
	static List!Path paths;

	float distance;
	float speed;
	float health;
	float maxHealth;
	uint pathIndex;
	int worth;
	Frame frame;

	Status status;

	this(EnemyPrototype prefab, uint pathIndex)
	{
		this.distance = 0;
		this.speed = prefab.speed;
		this.health = prefab.maxHealth;
		this.maxHealth = prefab.maxHealth;
		this.worth = prefab.worth;
		this.frame = prefab.frame;
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

alias EnemyDeathHandler = void delegate(BaseEnemy, uint);
alias EnemyAtEndHandler = void delegate(BaseEnemy, uint);

class BaseEnemyController
{
	List!BaseEnemy enemies;
	List!EnemyDeathHandler onDeath;
	List!EnemyAtEndHandler onAtEnd;
	List!Path paths;

	this(A)(ref A allocator, Level level)
	{
		enemies = List!BaseEnemy(allocator, 1024);
		onDeath = List!EnemyDeathHandler(allocator, 16);
		onAtEnd = List!EnemyDeathHandler(allocator, 16);
		paths    = level.paths;
	}

	void update()
	{
		for (int i = enemies.length -1; i >=0; i--)
		{
			enemies[i].updateStatus(Time.delta);
			enemies[i].distance += enemies[i].speed * Time.delta;
			if (enemies[i].distance < 0)
				enemies[i].distance = 0;
			if (enemies[i].distance > paths[enemies[i].pathIndex].endDistance)
			{
				foreach(method; onAtEnd)
					method(enemies[i], i);

				killEnemy(i);
			}
		}
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
			handler(enemy, enemyIndex);
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
			float2 origin = float2(enemy.frame.width/2, enemy.frame.height/2);
			Game.renderer.addFrame(enemy.frame, float4(position.x, 
													   position.y,
													   enemy.frame.width, enemy.frame.height),
								   color, origin);
		}
	
		import std.algorithm, game.debuging;

		foreach(ref enemy; enemies)
		{
			float2 position = enemy.position;
			float2 origin = float2(enemy.frame.width/2, enemy.frame.height/2);
			float amount = enemy.health/enemy.maxHealth;
			float hBWidth = min(50, enemy.maxHealth);
			Game.renderer.addRect(float4(position.x - hBWidth/2, position.y + enemy.frame.height/2, 
										 hBWidth, 5), Color.red);
			Game.renderer.addRect(float4(position.x - hBWidth/2, position.y + enemy.frame.height/2, 
										 hBWidth*amount, 5), Color.green);
		}
	}
}