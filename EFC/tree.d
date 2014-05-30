module tree;
import math.vector, entity_table, system;

struct Transform
{
	float2 position, scale;
	float  rotation;

	Transform opBinary(string op : "*")(auto ref Transform other)
	{
		float2 pos  = this.position.rotate(other.rotation) * other.scale;
		pos += other.position;
	
		float2 scale   = other.scale * this.scale; 
		float rotation = other.rotation + rotation;
		return Transform(pos, scale, rotation);
	}
}

struct TreeTransform
{
	Transform locals, globals;
	ushort parents; 
}

struct TreeTransformSystem
{
	mixin SystemBase!(CompCollection!(SOA!(TreeTransform)), destructor);

	CompHandle create(Transform local)
	{
		//This is a very simple system so we don't need anything more complex!
		return collection.create(local, Transform.init, ushort.max);
	}

	CompHandle create(Transform local, CompHandle parent)
	{
		//Sould maby expand the API of component collection? 
		auto index = collection.indecies[parent.index].index;
		//This is a very simple system so we don't need anything more complex!
		return collection.create(local, Transform.init, index);
	
	}


	void destructor(TreeTransform t) { }
	void update()
	{
		import std.parallelism, std.range;
		foreach(i; taskPool.parallel(iota(0,collection.numObjects), 2048))
		{
			ushort parent = collection.parents[i];
			if(parent == ushort.max)
				collection.globals[i] = collection.locals[i];
			else 
				collection.globals[i] = collection.locals[i] * collection.globals[parent];
		}
	}
}