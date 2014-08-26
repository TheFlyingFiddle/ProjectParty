module collections.heap;

import collections.list;
import std.range;
import std.functional;

struct PQueue(T, alias less = "a < b")
{
	BinaryHeap!(List!T, less) heap;
	alias heap this;


	this(A)(ref A all, size_t count)
	{
		auto list = List!(T)(all, count);
		heap = BinaryHeap!(List!(T), less)(list);
	}
}

struct BinaryHeap(Store, alias less = "a < b") if (isRandomAccessRange!(Store) || isRandomAccessRange!(typeof(Store.init[])))
{
    private alias comp = binaryFun!(less);
    private @property ref size_t length()
    {
        return store.length;
    }

	Store store;

    // Assuming the element at index i perturbs the heap property in
    // store r, percolates it down the heap such that the heap
    // property is restored.
    private void percolateDown(Store r, size_t i, size_t length)
    {
        for (;;)
        {
            auto left = i * 2 + 1, right = left + 1;
            if (right == length)
            {
                if (comp(r[i], r[left])) swap(r, i, left);
                return;
            }
            if (right > length) return;
            assert(left < length && right < length);
            auto largest = comp(r[i], r[left])
                ? (comp(r[left], r[right]) ? right : left)
                : (comp(r[i], r[right]) ? right : i);
            if (largest == i) return;
            swap(r, i, largest);
            i = largest;
        }
    }

	void pop(Store store)
    {
        assert(!store.empty, "Cannot pop an empty store.");
        if (store.length == 1) return;
        auto t1 = moveFront(store[]);
        auto t2 = moveBack(store[]);
        store.front = move(t2);
        store.back = move(t1);
        percolateDown(store, 0, store.length - 1);
    }

    private static void swap(Store store, size_t i, size_t j)
    {
        static if (is(typeof(swap(store[i], store[j]))))
        {
            swap(store[i], store[j]);
        }
        else static if (is(typeof(_store.moveAt(i))))
        {
            auto t1 = store.moveAt(i);
            auto t2 = store.moveAt(j);
            store[i] = move(t2);
            store[j] = move(t1);
        }
        else // assume it's a container and access its range with []
        {
            auto t1 = store[].moveAt(i);
            auto t2 = store[].moveAt(j);
            store[i] = move(t2);
            store[j] = move(t1);
        }
    }

public:

	/**
	Returns $(D true) if the heap is _empty, $(D false) otherwise.
	*/
    @property bool empty()
    {
        return !length;
    }

	/**
	Returns the _capacity of the heap, which is the length of the
	underlying store (if the store is a range) or the _capacity of the
	underlying store (if the store is a container).
	*/
    @property size_t capacity()
    {
        static if (is(typeof(store.capacity) : size_t))
        {
            return store.capacity;
        }
        else
        {
            return store.length;
        }
    }

	/**
	Returns a copy of the _front of the heap, which is the largest element
	according to $(D less).
	*/
    @property ElementType!Store front()
    {
        assert(!empty, "Cannot call front on an empty heap.");
        return store.front;
    }

	/**
	Clears the heap by detaching it from the underlying store.
	*/
    void clear()
    {
        store = Store.init;
    }

	/**
	Inserts $(D value) into the store. If the underlying store is a range
	and $(D length == capacity), throws an exception.
	*/
    void insert(ElementType!Store value)
    {		
		store ~= value;

        for (size_t n = length - 1; n; )
        {
            auto parentIdx = (n - 1) / 2;
            if (!comp(store[parentIdx], store[n])) break; // done!
            // must swap and continue
            swap(store, parentIdx, n);
            n = parentIdx;
        }
    }

	/**
	Removes the largest element from the heap.
	*/
    void removeFront()
    {
        assert(!empty, "Cannot call removeFront on an empty heap.");
        if (length > 1)
        {
            auto t1 = moveFront(store[]);
            auto t2 = moveAt(store[], length - 1);
            store.front = move(t2);
            store[length - 1] = move(t1);
        }

		store.length--;
        percolateDown(store, 0, length);
    }

    /// ditto
    alias popFront = removeFront;
}

/** Removes the first item that satisfies the predicate from the heap*/
bool remove(Heap, alias pred)(ref Heap heap)
{
	import std.algorithm;
	int index = -1;
	foreach(i; 0 .. heap.store.length)
	{
		if(pred(heap.store[i])) 
		{
			index = i;
			break;
		}
	}

	if(index == -1) return false;
	swap(heap.store[index], heap.store[$ - 1]);
	heap.store.length--;
	heap.percolateDown(heap.store, index, heap.length);
	return true;
}