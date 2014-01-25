module collections.map;

import collections.list;
import allocation;

enum uint endOfList = 0xFF_FF_FF_FFu;

private struct Hash(K,V, alias hashFunc)
{
	struct Entry 
	{
		V value;
		K key;
		uint next;
	}

	private struct FindResult
	{
		uint hashIndex;
		uint dataPrev;
		uint dataIndex;
	}

	List!uint _hashes;
	List!Entry _entries;


	this(uint[] hashBuffer, Entry[] entryBuffer)
	{
		this._hashes = List!uint(hashBuffer);
		this._entries = List!Entry(entryBuffer);

		this._hashes.length = this._hashes.capacity;
		this._hashes[] = endOfList;
	}

	private uint addEntry(K key)
	{
		Entry e;
		e.key = key;
		e.next = endOfList;
		_entries ~= e;
		return _entries.length - 1;
	}

	private FindResult find(K key)
	{
		FindResult fr;
		fr.hashIndex = endOfList;
		fr.dataPrev  = endOfList;
		fr.dataIndex = endOfList;

		fr.hashIndex = hashFunc(key) % _hashes.length;
		fr.dataIndex = _hashes[fr.hashIndex];
		while(fr.dataIndex != endOfList)
		{
			if(_entries[fr.dataIndex].key == key)
				return fr;

			fr.dataPrev  = fr.dataIndex;
			fr.dataIndex = _entries[fr.dataIndex].next; 
		}

		return fr;
	}

	private FindResult find(Entry* e)
	{
		FindResult fr;
		fr.hashIndex = fr.dataPrev = fr.dataIndex = endOfList;

		fr.hashIndex = hashFunc(e.key) % _hashes.length;
		fr.dataIndex = _hashes[fr.hashIndex];
		while(fr.dataIndex != endOfList)
		{
			if(&_entries[fr.dataIndex] == e)
				return fr;

			fr.dataPrev  = fr.dataIndex;
			fr.dataIndex = _entries[fr.dataIndex].next; 
		}

		return fr;
	}

	private uint findOrFail(K key)
	{
		return find(key).dataIndex;
	}

	private uint findOrMake(K key)
	{
		const FindResult fr = find(key);
		if(fr.dataIndex != endOfList)
			return fr.dataIndex;


		uint index = addEntry(key);
		if(fr.dataPrev == endOfList)
			_hashes[fr.hashIndex] = index;
		else 
			_entries[fr.dataPrev].next = index;

		return index;
	}

	private uint make(K key)
	{
		const FindResult fr = find(key);
		const uint index = addEntry(key);

		if(fr.dataPrev == endOfList)
			_hashes[fr.hashIndex] = index;
		else 
			_entries[fr.dataPrev].next = index;

		_entries[index].next = fr.dataIndex;
		return index;
	}

	private bool findAndErase(K key)
	{
		const FindResult fr = find(key);
		if(fr.dataIndex != endOfList)
			erase(fr);

		return fr.dataIndex != endOfList;
	}

	void erase(in FindResult fr)
	{
		if(fr.dataPrev == endOfList)
			_hashes[fr.hashIndex] = _entries[fr.dataIndex].next;
		else 
			_entries[fr.dataPrev].next = _entries[fr.dataIndex].next;

		if(fr.dataIndex == _entries.length - 1) {
			_entries.length--;
			return;
		}

		_entries[fr.dataIndex] = _entries[_entries.length - 1];
		auto last = find(_entries[fr.dataIndex].key);

		if(last.dataPrev != endOfList)
			_entries[last.dataPrev].next = fr.dataIndex;
		else 
			_hashes[last.hashIndex] = fr.dataIndex;
	}

	void copy(ref Hash!(K,V, hashFunc) to)
	{	
		foreach(entry; _entries) {
			auto index = to.make(entry.key);
			to._entries[index].value = entry.value;
		}
	}

	bool full()
	{
		enum maxLoadFactor = 0.7f;
		return _entries.length >= _hashes.length * maxLoadFactor;
	}

	static Hash!(K,V, hashFunc) allocate(IAllocator allocator, size_t capacity)
	{
		auto extra = Entry.alignof - ((capacity * uint.sizeof) % Entry.alignof);

		void[] mapData = allocator.allocate(extra +
											(Entry.sizeof + uint.sizeof) *
											capacity, Entry.alignof);

		uint[] hashBuffer = cast(uint[])mapData[0 .. uint.sizeof * capacity];
		hashBuffer[] = endOfList;
		Entry[] entryBuffer = cast(Entry[])mapData[uint.sizeof * capacity + extra .. $];
		entryBuffer[] = Entry(V.init, K.init, endOfList);

		return Hash!(K,V, hashFunc)(hashBuffer, entryBuffer);
	}

	void deallocate(IAllocator allocator)
	{
		auto capacity = _hashes.capacity;
		auto extra    = Entry.alignof - ((capacity * uint.sizeof) % Entry.alignof);
		auto size     = extra + (Entry.sizeof + uint.sizeof) * capacity;

		void[] buffer = (cast(void*)_hashes.buffer)[0 .. size];
		allocator.deallocate(buffer);
	}
}

struct HashMap(K,V,alias hashFunc = defaultHashFunc!K)
{
	alias Map = Hash!(K,V, hashFunc);

	IAllocator _allocator;
	Map		   _map;

	@property uint length()
	{
		return _map._entries.length;
	}

	@property uint capacity()
	{
		return _map._hashes.length;
	}


	this(IAllocator allocator, size_t initialCapacity)
	{
		assert(initialCapacity > 0);

		this._allocator = allocator;
		this._map       = Map.allocate(_allocator, initialCapacity);		
	}

	~this()
	{
		_map.deallocate(_allocator);
	}

	void set(K key, V value)
	{
		auto index = _map.findOrMake(key);
		_map._entries[index].value = value;

		if(_map.full())
			resize(_map._hashes.length * 2 + 10);
	}

	void opIndexAssign(V value, K key)
	{
		set(key, value);
	}

	ref V opIndex(K key)
	{
		auto index = _map.findOrFail(key);
		assert(index != endOfList);
		return _map._entries[index].value;
	}

	V get(K key, V defaultValue)
	{
		auto index = _map.findOrFail(key);
		return index == endOfList ? defaultValue : _map._entries[index].value;
	}

	bool remove(K key)
	{
		return _map.findAndErase(key);
	}

	T* opBinary(string op : "in")(K key)
	{
		auto index = _map.findOrFail();
		return index == endOfList ? null : &_map.entries[index].value;
	}

	void clear()
	{
		this._map._entries.clear();
		this._map._hashes[] = endOfList;
	}

	int opApply(int delegate(ref V) dg)
	{
		int result;
		foreach(ref elem; _map._entries)
		{
			result = dg(elem.value);
			if(result) break;
		}
		return result;
	}

	int opApply(int delegate(ref K, ref V) dg)
	{
		int result;
		foreach(ref elem; _map._entries)
		{
			result = dg(elem.key, elem.value);
			if(result) break;
		}
		return result;
	}


	private void resize(size_t capacity)
	{
		assert(capacity >= _map._entries.length);

		auto newMap = Map.allocate(_allocator, capacity);
		_map.copy(newMap);
		_map.deallocate(_allocator);
		_map = newMap;
	}

	@disable this(this);
}

struct MultiHashMap(K, V, alias hashFunc = defaultHashFunc!K)
{
	import std.range;

	alias Map = Hash!(K,V, hashFunc);
	alias Entry = Map.Entry;

	IAllocator _allocator;
	Map _map;

	@property uint capacity()
	{
		return _map._hashes.capacity;
	}

	@property uint length()
	{
		return _map._entries.length;
	}

	this(IAllocator allocator, size_t initialCapacity)
	{
		this._allocator = allocator;
		this._map       = Map.allocate(_allocator, initialCapacity);
	}

	bool remove(K key, V value)
	{
		auto range = Range(&this, key);
		while(!range.empty())
		{
			if(range._front.value == value)
			{
				auto fr = _map.find(range._front);
				_map.erase(fr);
				return true;
			}
		}

		return false;
	}

	uint removeAll(K key)
	{
		uint count = 0;
		while(_map.findAndErase(key)) 
			count++;
		return count;
	}

	void insert(K key, V value)
	{
		auto index = _map.make(key);
		_map._entries[index].value = value;

		if(_map.full()) 
			resize(_map._hashes.length * 2 + 10);
	}

	void insert(R)(K key, R range) 
		if(isInputRange!R && is(traits.ElementType!R : V))
		{
			foreach(ref elem; range)
				insert(key, elem);
		}

	void opIndexAssign(V value, K key)
	{
		insert(key, value);
	}

	void opIndexAssign(R)(R range, K key)
		if(isInputRange!R && is(traits.ElementType!R : V))
		{
			insert(key, range);
		}

	Range opIndex(K key)
	{
		return Range(&this, key);
	}

	private void resize(size_t capacity)
	{
		assert(capacity >= _map._entries.length);

		auto newMap = Map.allocate(_allocator, capacity);
		_map.copy(newMap);
		_map.deallocate(_allocator);
		_map = newMap;
	}

	private Entry* findFirst(K key)
	{
		auto index = _map.findOrFail(key);
		return index == endOfList ? null : &_map._entries[index];
	}

	private Entry* findNext(Entry* e)
	{
		uint index = e.next;
		while(index != endOfList)
		{
			if(_map._entries[index].key == e.key)
				return &_map._entries[index];
			index = _map._entries[index].next;
		}
		return null;
	}

	struct Range
	{
		MultiHashMap* _map;
		Entry* _front;

		@property ref Entry front()
		{
			return *_front;
		}

		this(MultiHashMap* map, K key)
		{
			this._map = map;
			this._front = map.findFirst(key);
		}

		bool empty() { return _front is null; }
		void popFront()
		{
			_front = _map.findNext(_front);		
		}

		@property uint walkLength()
		{
			Range r = this;
			uint length;
			while(!r.empty()) 
			{
				length++;
				r.popFront();
			}
			return length;
		}

		void put(K key, V value)
		{
			_map.insert(key, value);
		}
	}
}


uint defaultHashFunc(K)(K key)
{
	import std.traits;

	static if(__traits(compiles,{ uint hash = key.toHash(); }))
	{
		return key.toHash();
	} 
	else static if(isArray!K)
	{
		

		import util.hash;
		return bytesHash(key.ptr, key.length * typeof(key[0]).sizeof, 0); 
	}
	else 
	{
		import hash;
		return cast(uint)typeid(K).getHash(&key);
	}
}

unittest
{
	string s  = "Hello";
	string s2 = "Hello";

	assert(defaultHashFunc!string(s) ==
		   defaultHashFunc!string(s2));

}

//Can insert and remove get etc for one element.
unittest
{
	import allocation;
	alias HashMap!(string, int) Map;

	Map map = Map(new CAllocator!(Mallocator)(Mallocator.it), 50);

	map["Hello"] = 10;
	assert(map["Hello"] == 10);
	assert(map.length == 1);
	assert(map.get("Hello", -1) == 10);

	assert(map.remove("Hello"));
	assert(map.length == 0);
}

//Can insert and get multiple elements.
unittest
{
	import allocation, std.random, std.range, std.conv;
	alias HashMap!(string, int) Map;

	auto rng = rndGen();
	auto seed = rng.front;
	rng.seed!()(seed);

	Map map = Map(new CAllocator!(Mallocator)(Mallocator.it), 1000);
	foreach(ref u; 0 .. 100)
		map["String" ~ u.to!string] = u;

	rng.seed!()(seed);

	uint count;
	foreach(ref u; 0 .. 100) {
		assert(map["String" ~ u.to!string] == u);
		count++;
	}
}

//
unittest
{
	import allocation, std.random, std.range, std.conv;
	alias HashMap!(string, int) Map;

	auto rng = rndGen();
	auto seed = rng.front;
	rng.seed!()(seed);
	

	Map map = Map(new CAllocator!Mallocator(Mallocator.it), 100);
	assert(map.capacity == 100);
	foreach(ref int u; rng.take(200)) {
		map["String" ~ u.to!string] = u;
	}

	rng.seed!()(seed);
	foreach(ref int u; rng.take(200))
		assert(map["String" ~ u.to!string] == u);
}


unittest
{
	import allocation;
	alias MultiHashMap!(string, int) MultiMap;

	auto map = MultiMap(new CAllocator!Mallocator(Mallocator.it), 10);
	assert(map.capacity == 10);
	assert(map.length == 0);

	map["Test"] = 1;
	map["Test"] = 2;

	assert(map["Test"].walkLength == 2);

	auto range = map["Test"];

	auto value1 = range.front.value;
	range.popFront();
	auto value2 = range.front.value;

	assert(value1 != value2);
	assert(value1 == 1 || value1 == 2);
	assert(value2 == 1 || value2 == 1);

	map.remove("Test", 2);
	assert(map["Test"].walkLength == 1);

	range = map["Test"];

	assert(range.front.value == 1);
}

version(benchmark)
{
	uint f(uint a) { return a; }

	unittest
	{
		import std.datetime, allocation, std.random, std.range;
		alias HashMap!(uint, int, f) Map;

		Map map = Map(new CAllocator(Mallocator.it), 1024 * 1024 * 2);
		uint[int] aa;

		Map map2 = Map(new CAllocator(Mallocator.it), 1024 * 1024 * 2);
		uint[int] aa2;

		auto rng = rndGen();
		auto seed = rng.front;

		enum loopCount = 1024 * 1024;

		void fillFirst()
		{	
			rng.seed!()(seed);
			foreach(ref elem; rng.take(loopCount))
				map[elem] = elem;
		}

		void fillSecond()
		{
			rng.seed!()(seed);
			foreach(ref elem; rng.take(loopCount))
				aa[elem] = elem;
		}

		void findFirst()
		{
			rng.seed!()(seed);
			foreach(ref elem; rng.take(loopCount))
				assert(map[elem] == elem);
		}

		void findSecond()
		{
			rng.seed!()(seed);
			foreach(ref elem; rng.take(loopCount))
				assert(aa[elem] == elem);
		}


		void fillThird()
		{	
			rng.seed!()(seed);
			foreach(elem; 0 .. loopCount)
				map2[elem] = elem;
		}

		void fillForth()
		{
			rng.seed!()(seed);
			foreach(elem; 0 .. loopCount)
				aa2[elem] = elem;
		}

		void findThird()
		{
			rng.seed!()(seed);
			foreach(elem; 0 .. loopCount)
				assert(map2[elem] == elem);
		}

		void findForth()
		{
			rng.seed!()(seed);
			foreach(elem; 0 .. loopCount)
				assert(aa2[elem] == elem);
		}

		void loopFirst()
		{
			foreach(ref elem; map)
			{
				int i; //Simply loop;
			}
		}

		void loopSecond()
		{
			foreach(ref elem; aa)
			{
				int i; //Simply loop;
			}
		}

		void loopThird()
		{
			foreach(ref elem; map2)
			{
				int i; //Simply loop;
			}
		}

		void loopForth()
		{
			foreach(ref elem; aa2)
			{
				int i; //Simply loop;
			}
		}

		auto bm = benchmark!(fillFirst, fillSecond, 
							 fillThird, fillForth,
							 findFirst, findSecond,
							 findThird, findForth,
							 loopFirst, loopSecond,
							 loopThird, loopForth)(1);

		import std.stdio;
		foreach(result; bm)
			writeln(result.nsecs);
	}
}