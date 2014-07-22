module collections.table;

import std.algorithm;
import collections.list;

@nogc:

enum SortStrategy
{
	unsorted,
	sorted
}

//Represents a map. From ID to T implemented in a space efficient manner.
struct Table(K, V, SortStrategy s = SortStrategy.sorted) 
{
	List!V values;
	List!K keys;

	@property uint length()
	{
		return values.length;
	}

	@property uint capacity()
	{
		return values.capacity;
	}

	this(A)(ref A allocator, size_t capacity)
	{		
		values = List!V(allocator, capacity);
		keys   = List!K(allocator, capacity);
	}


	V* opBinaryRight(string s : "in")(in K key)
	{
		auto index = indexOf(key);
		return index != -1 ? &values[index] : null;
	}

	ref V opIndex(in K key)
	{
		import std.conv;

		auto index = indexOf(key);
		assert(index != -1, "Key " ~ key.to!string ~ " not present in table.");
		return values[index];
	}

	void opIndexAssign(V value, in K key)
	{
		addOrSet(key, value);
	}

	ref V at(size_t index) 
	{
		return values[index];
	}

	K keyAt(size_t index)
	{
		return keys[index];
	}

	int opApply(int delegate(ref V) dg)
	{
		int result;
		foreach(i; 0 .. keys.length)
		{
			result = dg(values[i]);
			if(result)
				break;
		}
		return result;
	}

	int opApply(int delegate(K, ref V) dg)
	{
		int result;
		foreach(i; 0 .. keys.length)
		{
			result = dg(keys[i], values[i]);
			if(result)
				break;
		}
		return result;
	}

	int opApply(int delegate(int, K, ref V) dg)
	{
		int result;
		foreach(i; 0 .. keys.length)
		{
			result = dg(i, keys[i], values[i]);
			if(result)
				break;
		}
		return result;
	}

	void clear()
	{
		this.values.clear();
		this.keys.clear();
	}

	static if(s == SortStrategy.sorted)
	{
		int indexOf(K key)
		{
			int index;
			return bestIndexOf(key, index) ? index : -1;
		}

		bool remove(K key)
		{
			auto index = indexOf(key);
			if(index == -1) return false;
		
			removeAt(index);
			return true;
		}

		void removeAt(size_t index)
		{
			//Fast removal
			keys.removeAt(index);
			values.removeAt(index);
		}

		private void addOrSet(K key, V value)
		{
			int index;
			if(bestIndexOf(key, index))
			{
				values[index] = value;
			} 
			else 
			{
				keys.insert(index, key);
				values.insert(index, value);
			}
		}

		//Finds the most sutable index for the key.
		private bool bestIndexOf(K key, out int index)
		{
			auto ptr = keys.buffer;

			//Binary search.
			int first = 0, 
				mid   = keys.length / 2,
				last  = keys.length - 1;

			while(first <= last)
			{
				K other = ptr[mid];
				if(key == other) 
				{
					index = mid;
					return true;
				}
				else if(key < other)
					last = mid - 1;
				else 
					first = mid + 1;

				mid = (first + last) / 2;

			}
			
			index = first;
			return false;
		}
	} 
	else 
	{
		int indexOf(K key)
		{
			auto index = keys.countUntil!(x => x == key);
			return cast(int)index;
		}

		bool remove(K key)
		{
			auto index = indexOf(key);
			if(index == -1) return false;
			removeAt(index);
			return true;
		}

		void removeAt(size_t index)
		{
			//Fast removal
			values.removeAt!(SwapStrategy.unstable)(index);
			keys.removeAt!(SwapStrategy.unstable)(index);
		}

		private void addOrSet(K key, V value)
		{
			auto index = indexOf(key);
			if(index != -1) 
			{
				values[index] = value;
			}
			else 
			{
				values ~= value;
				keys   ~= key;
			}
		}
	}
}
//TODO: These unittests were broken long ago (removal of GC.it, introduction of @nogc), but should eventually be fixed
//unittest
//{
//    import allocation;
//    auto allocator = RegionAllocator(Mallocator.cit, 1024 * 4);
//    auto ss  = ScopeStack(allocator);
//    
//    auto table = Table!(uint, ulong)(ss, 100);
//    
//    table[10] = 5;
//    table[1]  = 3;
//    
//    assert(10 in table); // <-- Not sure if we should have in...
//    assert(1 in table);
//    assert(table[10] == 5);
//    assert(table[1]  == 3);
//    assert(table.length == 2);
//
//    foreach(k, v; table)
//        assert(table[k] == v);
//
//
//    auto stable = Table!(uint, ulong, SortStrategy.sorted)(ss, 100);
//
//    stable[10] = 5;
//    stable[1]  = 3;
//
//    assert(10 in stable);
//    assert(1 in stable);
//    assert(stable[10] == 5);
//    assert(stable[1]  == 3);
//    assert(stable.length == 2);
//
//    foreach(k, v; stable)
//        assert(stable[k] == v);
//}

import std.stdio;
//TODO: These unittests were broken long ago (removal of GC.it, introduction of @nogc), but should eventually be fixed
//unittest
//{
//    auto keys = [3, 1, 2, 4, 6, 0, 8, 9, 5, 7];
//    auto values = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0];
//
//    import allocation;
//    auto allocator = RegionAllocator(Mallocator.cit, 1024 * 4);
//    auto ss  = ScopeStack(allocator);
//
//    auto table = Table!(uint, ulong)(ss, 100);
//
//    foreach(i; 0 .. values.length) {		
//        table[keys[i]] = values[i];
//
//        logInfo(table.keys.array);
//        logInfo(table.values.array);
//    }
//    
//}

version(benchmark_table)
{
	unittest
	{
		import allocation, std.random, std.range, collections.map;

		auto region = RegionAllocator(Mallocator.cit, 1024 * 1024 * 100);		

		auto ss       = ScopeStack(region);

		auto unsorted = Table!(ulong, ulong)(ss, 100_000);
		auto sorted   = Table!(ulong, ulong, SortStrategy.sorted)(ss, 100_000_0);
		auto map	  = HashMap!(ulong, ulong, f)(Mallocator.cit, 100_000_0);

		auto rng = rndGen();
		auto seed = rng.front;

		void fillRandomUnsorted(size_t num)()
		{	
			rng.seed(seed);
			foreach(elem; rng.take(num))
				unsorted[elem] = elem;
		}

		void fillRandomSorted(size_t num)()
		{			
			rng.seed(seed);
			foreach(elem; rng.take(num))
				sorted[elem] = elem;
		}

		void fillRandomHashMap(size_t num)()
		{
			rng.seed(seed);
			foreach(elem; rng.take(num))
				map[elem] = elem;
		}

		void removeRandomUnsorted(size_t num)()
		{	
			rng.seed(seed);
			foreach(elem; rng.take(num))
				unsorted.remove(elem);
		}

		void removeRandomSorted(size_t num)()
		{			
			rng.seed(seed);
			foreach(elem; rng.take(num))
				sorted.remove(elem);
		}

		void removeRandomHashMap(size_t num)()
		{
			rng.seed(seed);
			foreach(elem; rng.take(num))
				map.remove(elem);
		}


		import std.datetime;

		auto r = benchmark!(fillRandomUnsorted!(10),
							removeRandomUnsorted!(10),
							fillRandomUnsorted!(100),
							removeRandomUnsorted!(100),
							fillRandomUnsorted!(1000),
							removeRandomUnsorted!(100),
							fillRandomUnsorted!(10000),
							removeRandomUnsorted!(100),

							fillRandomSorted!(10),
							removeRandomSorted!(10),
							fillRandomSorted!(100),
							removeRandomSorted!(100),
							fillRandomSorted!(1000),
							removeRandomSorted!(1000),
							fillRandomSorted!(10000),
							removeRandomSorted!(10000),
							fillRandomSorted!(100000),
							removeRandomSorted!(100000),

							fillRandomHashMap!(10),
							removeRandomHashMap!(10),
							fillRandomHashMap!(100),
							removeRandomHashMap!(100),
							fillRandomHashMap!(1000),
							removeRandomHashMap!(1000),
							fillRandomHashMap!(10000),
							removeRandomHashMap!(10000),
							fillRandomHashMap!(100000),
							removeRandomHashMap!(100000))(1);

		import std.stdio;
		foreach(e; r)
			writeln(e);
		readln;

	}

	auto f = (ulong x) => x;

}