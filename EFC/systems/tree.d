module systems.tree;
import math.vector, entity, systems;

struct Transform
{
	float2 position, scale;
	float  rotation;
}

struct TreeTransform
{
	Transform locals, globals;
	ushort parents; 
}

struct TreeTransformSystem
{
	mixin SystemBase!(CompCollection!(SOA!(TreeTransform)));

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

	void update()
	{
		auto parents = collection.parents;
		auto locals  = collection.locals;
		auto globals = collection.globals;

		foreach(i; 0 .. collection.numObjects)
		{
			ushort parent = parents[i];
			if(parent == ushort.max)
				globals[i] = locals[i];
			else 
			{		
				Transform* t = &globals[i],
					l = &locals[i], 
					g = &globals[parent];

				t.position = rotate(l.position, g.rotation) * g.scale + g.position;
				t.scale    = l.scale	* g.scale; 
				t.rotation = l.rotation + g.rotation;
			}
		}
	}
}