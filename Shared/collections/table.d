module collections.table;

import std.algorithm;
import collections.list;

enum SortStrategy
{
	unsorted,
	sorted
}


alias Table!(K, V, SortStrategy.unsorted) UTable(K, V);
alias Table!(K, V, SortStrategy.sorted)   STable(K, V);

//Represents a map. From ID to T implemented in a space efficient manner.
struct Table(K, V, SortStrategy s = SortStrategy.unsorted) if(is(T == struct)) //Designed for structs only.
{
	List!V values;
	List!K keys;

	this(A)(ref A allocator, size_t capacity)
	{		
		values = List!V(allocator, capacity);
		keys   = List!K(allocator, capacity);
	}

	V* opBinary(string s : "in")(in K key)
	{
		auto index = indexOf(key);
		return index != -1 ? &values[index] : null;
	}

	ref V opIndex(in K key)
	{
		auto index = indexOf(key);
		assert(index != -1, "Key " ~ key ~ " not present in table.");
		return values[index];
	}

	void opIndex(in K key, V value)
	{
		addOrSet(key, value);
	}

	void opApply(int delegate(ref V) dg)
	{
		int result;
		foreach(i; 0 .. keys.length)
		{
			result = dg(values[i]);
		}
		return result;
	}

	void opApply(int delegate(K, ref V) dg)
	{
		int result;
		foreach(i; 0 .. keys.length)
		{
			result = dg(keys[i], values[i]);
		}
		return result;
	}



	static if(s == SortStrategy.sorted)
	{
		int indexOf(in K key)
		{
			int index;
			return bestIndexOf(key, index) ? index : -1;
			auto index = bestIndexOf(key);
			return keys[index] == key ? index : -1;
		}

		bool remove(in K key)
		{
			auto index = indexOf(key);
			if(index == -1) return false;

			keys.removeAt(index);
			values.removeAt(index);
		}

		private void addOrSet(in K key, V value)
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
		private bool bestIndexOf(in K key, out int index)
		{
			auto ptr = keys.buffer;

			//Binary search.
			int first = 0, 
				mid   = keys.length / 2,
				last  = keys.length - 1;

			while(first <= last)
			{
				uint i = key.opCmp(ptr[mid]);
				if(i == 0) 
				{
					index = mid;
					return true;
				}
				else if(i < 0)
					last = mid - 1;
				else 
					first = mid + 1;

				mid = (first + last) / 2;
			}
			
			index = mid;
			return false;
		}
	} 
	else 
	{
		int indexOf(in K key)
		{
			return keys.countUntil!(x => x == key);
		}

		bool remove(in K id)
		{
			auto index = ids.countUntil!(x => x.id == id);
			if(index == -1) return false;

			//Fast removal
			values.removeAt!(SwapStrategy.unstable)(index);
			keys.removeAt!(SwapStrategy.unstable)(index);
			return true;
		}

		private void addOrSet(in K key, V value)
		{
			auto index = indexOf(key);
			if(index != -1) 
			{
				values[index] = value;
			}
			else 
			{
				values ~= value;
				keys   ~= keys;
			}
		}
	}
}


unittest
{
	import allocation;
	auto allocator = RegionAllocator(Mallocator.it, 1024);
	auto ss  = ScopeStack(allocator);
	
	auto table = UTable!(uint, ulong)(allocator, 100);
	
	table[10] = 5;
	table[1]  = 3;
	
	assert(10 in table);
	assert(1 in table);
	assert(table[10] == 5);
	assert(table[1]  == 3);
	assert(table.length == 2);

	foreach(k, v; table)
		assert(table[k] == v);


	auto stable = STable!(uint, ulong)(allocator, 100);

	stable[10] = 5;
	stable[1]  = 3;

	assert(10 in stable);
	assert(1 in stable);
	assert(stable[10] == 5);
	assert(stable[1]  == 3);
	assert(stable.length = 2);

	foreach(k, v; stable)
		assert(stable[k] == v);


	//Now that is enough tests! 
}

unittest
{
	version(benchmark)
	{

	}
}


