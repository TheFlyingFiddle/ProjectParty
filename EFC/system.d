module system;
import world;
import entity_table;
import std.traits;

nothrow @nogc:

interface ISystem 
{
	uint hash();
	uint order();

	@property bool enabled(bool value);
	@property bool enabled();

	void initialize(World w);
	void update();
}

template isSystem(T)
{
	enum isSystem = 
	__traits(compiles, 
				{
							});
}

mixin template SystemBase(Collection, alias destructor = void)
{
	private Collection collection;
	auto ref opDispatch(string s)()
	{
		struct Indexer
		{
			TableIndex*	indecies; 
			mixin("typeof(collection.objects." ~ s ~ ") items;");

			ref typeof(*items) opIndex(CompHandle handle)
			{
				return items[indecies[handle.index].index];
			}
		}

		//Voldemort types are so nice! 
		mixin("return Indexer(collection.indecies, collection.objects." ~ s ~ ");");
	}

	void addRef(CompHandle handle)
	{
		collection.addRef(handle);
	}

	void removeRef(CompHandle handle)
	{
		static if(is(destructor == void))
		{
			collection.removeRef(handle);
		} 
		else 
		{
			auto comp = collection[handle];
			if(collection.removeRef(handle))
			{
				destructor(comp);		
			}
		}
	}

	this(A)(ref A allocator, size_t size)
	{
		collection = Collection(allocator, cast(ushort)size);
	}
}

class System(T) if(isSystem!T) : ISystem
{
	T wrapped; 
	uint _order;
	bool _enabled;

	this(A)(ref A allocator, size_t size, uint order)
	{
		wrapped   = T(allocator, size);
		_order   = order;
		_enabled = true; 
	}

	@property bool enabled()
	{
		return _enabled;
	}

	@property bool enabled(bool value)
	{
		_enabled = value;
		return value; 
	}

	static if(hasElaborateDestructor!T)
	~this()
	{
		wraped.__dtor();
	}

	void initialize(World world)
	{
		static if(hasMember!(T, "initialize"))
			wrapped.initialize(world);
	}

	void update() 
	{
		if(_enabled)
			wrapped.update();
	}

	uint hash()
	{
		import util.hash;
		return cHash!T;
	}

	uint order()
	{
		return this._order;
	}	
}

interface IEntitySystem { }