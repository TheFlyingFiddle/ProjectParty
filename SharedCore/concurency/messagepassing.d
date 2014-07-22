module concurency.messagepassing;

import std.traits, std.typetuple;
import core.stdc.stdlib;
import core.sync.condition;
import core.atomic;
import allocation;


struct MPSCQueue(Serializer)
{
	private SPSCQueue!(Serializer) queue;
	private Condition cond;
	private bool shouldStop;
	
	this(A)(ref A allocator, size_t size)
	{
		queue			 = SPSCQueue!(Serializer)(allocator, size);
		auto mt			 = GlobalAllocator.allocate!Mutex;
		cond			 = GlobalAllocator.allocate!Condition(mt);
		shouldStop		 = false;
	}

	~this()
	{
		cond.mutex.__dtor();
		cond.__dtor();
		GlobalAllocator.deallocate(cond.mutex);
		GlobalAllocator.deallocate(cond);
	}

	void send(T)(auto ref T value) if(Serializer.constraints!T)
	{
		synchronized(cond.mutex)
		{
			while(!queue.trySend(value)) {
				if(shouldStop) return;

				cond.wait();
			}
		}
	}

	void stop() 
	{
		synchronized(cond.mutex)
		{
			shouldStop = true;
		}

		cond.notifyAll();
	}

	bool receive(Handlers...)(Handlers handlers)  if(allSatisfy!(typeof(queue).isMessageHandler, Handlers))
	{
		bool result = false;
		if(queue.tryReceive(handlers)) {
			result = true;
		}

		cond.notifyAll();
		return result;
	}

	@disable this(this);
}

//Multi recive - single send. 
struct SPMCQueue(Serializer)
{
	private SPSCQueue!(Serializer) queue;
	private Condition	cond;
	private shared uint items;
	private bool shouldStop;

	this(A)(ref A allocator, size_t size)
	{
		import allocation;

		queue			 = SPSCQueue!(Serializer)(allocator, size);
		auto mt			 = GlobalAllocator.allocate!Mutex;
		cond			 = GlobalAllocator.allocate!Condition(mt);
		items			 = 0;
		shouldStop		 = false;
	}	

	~this()
	{
		cond.mutex.__dtor();
		cond.__dtor();
		GlobalAllocator.deallocate(cond.mutex);
		GlobalAllocator.deallocate(cond);
	}
	
	bool send(T)(auto ref T value) if(Serializer.constraints!T)
	{
		if(queue.trySend(value))
		{
			atomicOp!"+="(items, 1);
			cond.notify();
			return true;
		} 
		return false;
	}

	void stop() 
	{
		synchronized(cond.mutex)
		{
			shouldStop = true;
		}

		cond.notifyAll();
	}

	void receive(Handlers...)(Handlers handlers) if(allSatisfy!(typeof(queue).isMessageHandler, Handlers))
	{
		ubyte[] data; 
		Serializer.header header;

		synchronized(cond.mutex)
		{
			while(atomicLoad(items) == 0) {
				if(shouldStop) return;

				try
				{
					cond.wait();
				}
				catch(Exception e)
				{
					import log;
					logErr(e);
				}
			}

			atomicOp!"-="(items, 1);
			header = queue.deserializeHeader();
			bool found = false;
			foreach(handler; handlers)
			{
				alias type = ParameterTypeTuple!(typeof(handler))[0]; //Only deal with single args atm. 
				enum typeHeader  = Serializer.typeHeader!type;
				if(typeHeader == header)
				{
					found = true;
					auto dataSize = Serializer.dataSize!type(header) + Serializer.header.sizeof;
					data = (cast(ubyte*)alloca(dataSize))[0 .. dataSize];
					data[] = 0;

					queue.nextMessage!type(data);
					break;
				}
			}

			assert(found);
		}

		foreach(handler; handlers)
		{
			alias type = ParameterTypeTuple!(typeof(handler))[0]; //Only deal with single args atm. 
			enum typeHeader  = Serializer.typeHeader!type;
			if(typeHeader == header)
			{
				type value;
				Serializer.deserialize!type(value, header, data[Serializer.header.sizeof .. $]);
				handler(value);
			}
		}
	}

	@disable this(this);
}

struct SPSCQueue(Serializer)
{
	private size_t first; 
	private size_t last; 
	private size_t length;
	private ubyte* buffer;

	this(A)(ref A allocator, size_t size)
	{
		import allocation;

		this.first = this.last = 0;
		this.length = size;
		buffer = allocator.allocate!(ubyte[])(size).ptr;
	}

	void send(T)(auto ref T value) if(Serializer.constraints!T)
	{
		assert(trySend(value));
	}

	bool full(T)(auto ref T value) 
	{
		const first = this.first, 
			last  = this.last;

		const rem = (first <= last) ? length - (last - first) : first - last;
		const dataSize = Serializer.dataSize(value);
		return rem < dataSize;
	}

	uint remaining()
	{
		const first = this.first, last  = this.last;
		return (first <= last) ? length - (last - first) : first - last;
	}

	bool trySend(T)(auto ref T value) if(Serializer.constraints!T)
	{	
		const dataSize = Serializer.dataSize(value);
		auto nLast = (last + dataSize) % length;

		const first = this.first;

		if(last < nLast)
		{
			if(first > last && first <= nLast) return false;
			Serializer.serialize(value, buffer[last .. nLast]);
		} 
		else 
		{
			if(nLast >= first || (nLast < first && last < first)) return false; 

			ubyte* tmp = cast(ubyte*)alloca(dataSize);
			Serializer.serialize(value, tmp[0 .. dataSize]);

			auto left					 = length - last;
			buffer[last .. length]		 = tmp[0 .. left];
			buffer[0 .. nLast]			 = tmp[left .. dataSize];
		}

		last = nLast;
		return true;
	}

	bool tryReceive(Handlers...)(Handlers handlers) if(allSatisfy!(isMessageHandler, Handlers))
	{
		import std.typetuple, std.traits;

		if(first == last) return false;
		auto header = deserializeHeader();
		foreach(handler; handlers)
		{
			alias type = ParameterTypeTuple!(typeof(handler))[0]; //Only deal with single args atm. 
			enum typeHeader  = Serializer.typeHeader!type;
			if(typeHeader == header)
			{
				const start = (first + Serializer.header.sizeof) % length;
				type value;
				auto dataSize = Serializer.dataSize!type(header);
				if(dataSize < length - start)
				{
					Serializer.deserialize!type(value, header, buffer[start .. start + dataSize]);
					handler(value);
				}
				else 
				{

					ubyte* tmp = cast(ubyte*)alloca(dataSize);
					tmp[0 .. length - start]		 = buffer[start .. length];
					tmp[length - start .. dataSize]  = buffer[0 .. dataSize - (length - start)];
					Serializer.deserialize!type(value, header, tmp[0 .. dataSize]);
					handler(value);
				}

				first = (start + dataSize) % length;
				return true;
			}
		}


		assert(0, "Wrong type");
	}

	private void nextMessage(T)(ubyte[] storage)
	{
		auto header = deserializeHeader();
		auto dataSize = Serializer.dataSize!T(header) + Serializer.header.sizeof;
		if(dataSize < length - first)
		{
			storage[0 .. dataSize] = buffer[first .. first + dataSize];
		}
		else 
		{
			storage[0 .. length - first] = buffer[first .. length];
			storage[length - first .. dataSize] = buffer[0 .. dataSize - (length - first)];
		}

		first = (first + dataSize) % length;
	}

	private template isMessageHandler(T)
	{
		alias params = ParameterTypeTuple!(T);
		enum isMessageHandler = params.length == 1 &&
			Serializer.constraints!(params[0]);
	}

	void receive(Handlers...)(Handlers handlers)
	{
		assert(tryReceive(handlers));
	}

	private auto deserializeHeader()
	{
		Serializer.header header; 
		enum hSize = Serializer.header.sizeof;
		if(hSize < length - first)
		{
			header = *(cast(Serializer.header*)(&buffer[first]));
		} 
		else 
		{
			auto hPtr = cast(ubyte*)(&header);
			hPtr[0 .. length - first]	  = buffer[first .. length];
			hPtr[length - first .. hSize] = buffer[0 .. hSize - (length - first)];
		}

		return header;
	}

	@disable this(this);
}

template isSerializer(T)
{
	enum isSerializer = 
		__traits(compiles, 
				 {
					 T.header h = T.typeHeader!int;
					 uint size  = T.dataSize(123);
					 ubyte[] array;

					 T.serialize(123, array);
					 int i;
					 T.deserialize(i, array);
				 });
}

//Gives Serializer interface of the following: 
struct QueueSerializer
{
	//Can make this arbitrary complex. 
	import util.hash;
	struct header
	{
		TypeHash value;
	}

	static header typeHeader(T)()
	{
		return header(cHash!T);
	}

	static uint dataSize(T)(auto ref T value)
	{
		return T.sizeof + uint.sizeof;
	}

	static uint dataSize(T)(header h)
	{
		return T.sizeof;
	}

	static void serialize(T)(auto ref T value, ubyte[] sink)
	{
		(*cast(header*)sink.ptr) = header(cHash!T);
		(*cast(T*)(sink.ptr + uint.sizeof)) = value;
	}

	static void deserialize(T)(ref T value, header h, ubyte[] source)
	{
		value = *cast(T*)(source.ptr);
	}

	template constraints(T)
	{
		enum constraints = true;
	}
}


//import std.stdio;
//import std.conv;
//unittest
//{
//    try
//    {
//        import allocation;
//        Queue messageQue = Queue(GC.it, 17);
//
//        messageQue.send(123);
//        messageQue.send(321);
//
//        void is123(int x) 
//        { 
//            assert(x == 123, text("X ",cast(uint)x)); 
//        }
//        void is321(int x) 
//        { 
//            assert(x == 321); 
//        }
//        void is412(int x) 
//        { 
//            writeln(x);
//            assert(x == 412); 
//        }
//        void is4123i(int i)
//        {
//            assert(0, "This should never be called!");
//        }
//        void is4123l(ulong x)
//        {
//            assert(x == 4123);
//        }
//
//        messageQue.receive(&is123);
//        messageQue.receive(&is321);
//
//        assert(!messageQue.tryReceive((int x) => assert(0)));
//
//        messageQue.send(412);
//        messageQue.receive(&is412);
//
//        messageQue.send(4123UL);
//        messageQue.receive(&is4123i, &is4123l);
//
//
//        struct A 
//        {
//            void* pointer;
//        }
//
//        static assert(!__traits(compiles, messageQue.send(A())));
//    } 
//    catch(Throwable e)
//    {
//        import std.stdio;
//        writeln(e);
//        readln;
//    }
//}
//
//alias Queue		 = SPSCQueue!(BaseSerializer);
//alias MTQueue	 = SPMCQueue!(BaseSerializer);
//alias MTQueue2	 = MPSCQueue!(BaseSerializer);
//const iterations = 10;

//unittest
//{
//    try
//    {
//        import allocation, core.thread;
//        Queue messageQue = Queue(GC.it, 1024);
//        
//        Thread t = new Thread(() => process(&messageQue));
//        t.start();
//
//        foreach(i; 0 .. iterations)
//        {
//            while(!messageQue.tryReceive( 
//                 (int x) 
//                 {
//                     assert(x == i);
//                 })) 
//            {
//            }
//        }
//    } 
//    catch(Throwable e)
//    {
//        import std.stdio;
//        writeln(e);
//        readln;
//    }
//}
//
//unittest
//{
//
//    try
//    {
//        import allocation, core.thread;
//        Queue messageQue = Queue(GC.it, 1024);
//    }
//    catch(Throwable e)
//    {
//        import std.stdio;
//        writeln(e);
//        readln;
//    }
//
//
//}
//
//import allocation, core.thread;
//class BT(T) : Thread
//{
//    size_t id;
//    T* queue;
//    void function(T*, size_t) p;
//    this(T* queue, uint id, void function(T*, size_t) p)
//    {
//        super(&run);
//        this.id = id;
//        this.queue = queue;
//        this.p = p;
//    }
//
//    void run()
//    {
//        p(queue, id);
//    }
//}
//
//unittest
//{
//    //auto g_ptr = &g_counter;
//    //
//    //auto queue = MTQueue(GC.it, 1019 * 117);
//    //foreach(uint i; 0 .. 4)
//    //{
//    //    Thread thread = new BT(&queue, i);
//    //    thread.start();
//    //
//    //    atomicOp!("+=")(g_counter, 1);
//    //}
//    //
//    //import std.datetime;
//    //StopWatch watch;
//    //watch.start();
//    //foreach(k; 0 .. 100)
//    //{
//    //    foreach(uint i; 0 .. 4 * 1024 * 1024)
//    //    {
//    //        while(!queue.send(i))
//    //        {
//    //            int j = 512 * 32 - i;
//    //        }
//    //    }
//    //    writeln("Time: ", watch.peek.msecs);
//    //    Thread.sleep(250.msecs);	
//    //    watch.reset();
//    //}
//    //
//    //writeln("Time: ", watch.peek.msecs);
//    //Thread.sleep(2.seconds);
//}
//
//struct Message
//{
//    int x;
//    size_t id;
//}
//
//unittest
//{
//    MTQueue2 queue = MTQueue2(GC.it, 1024 * 1024);
//    foreach(uint i; 0 .. 4)
//    {
//        Thread t = new BT!(MTQueue2)(&queue, i, &mtProcess2);
//        t.start();
//    }
//
//    import std.datetime;
//    StopWatch watch;
//    watch.start();
//
//    foreach(k; 0 .. 100)
//    {
//        foreach(i; 0 .. 4 * 1024 * 64)
//        {
//            while(!queue.receive(
//                (Message x)
//                {
//                }))
//            {
//                //writeln("Waiting for stuff come on guys!");
//            }
//        }
//        writeln("IT took ", watch.peek().msecs);
//        watch.reset();
//    }
//    
//    writeln("DONE!");
//}
//
//shared int g_counter = 0;
//void mtProcess(MTQueue* queue, size_t id)
//{
//    try
//    {
//
//    //writeln("Thread: ", id, " was spawned!");
//    foreach(i; 0 .. 1024 * 1024 * 50)
//    {
//        queue.receive(
//        (uint x) 
//        {
//        });
//    }
//
//    //writeln("Thread: ", id, " is done!");
//
//    }
//    catch(Throwable t)
//    {
//        writeln(t);
//        readln;
//    }
//
//    atomicOp!("-=")(g_counter, 1);
//    //writeln(atomicLoad(g_counter), " threads left!");
//}
//
//void mtProcess2(MTQueue2* queue, size_t id)
//{
//    try 
//    {
//        foreach(int i; 0 .. 1024 * 64 * 100)
//        {
//            queue.send(Message(i, id));
//        }
//    }
//    catch(Throwable t)
//    {
//        writeln(t);
//    }
//}
//
//void process(Queue* queue)
//{
//    try
//    {
//        foreach(int i; 0 .. iterations)
//        {
//            while(!queue.trySend(i)) 
//            {
//            }
//        }
//    }
//    catch(Throwable t)
//    {
//        writeln(t);
//    }
//
//    writeln("Done!");
//}