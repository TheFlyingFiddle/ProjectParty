module concurency.task;
import concurency.threadpool;
import concurency.messagepassing;
import core.sync.condition;
import core.sync.mutex;
import allocation;
import std.traits;

__gshared IAllocator messageAllocator;
__gshared TaskThread*[] threads;
__gshared TaskThreadPool*   taskpool;


//Thread local 
private string g_id;
void registerThread(string id)
{
	assert(g_id == "");

	static bool threadIndex(TaskThread x)
	{
		return x.id == "";
	}

	import std.algorithm, core.thread;
	foreach(ref thread; threads) if(thread.id == "")
	{
		thread.id = id;
		g_id = id;
		return;
	}

	assert(0, "Can't register thread!");
}

void consumeTasks()
{
	foreach(ref thread; threads) 
		if(thread.id == g_id)
	{
		thread.consumeTasks();
		return;
	}
}

struct ConcurencyConfig
{
	size_t numThreads;
	size_t stackSize;
	size_t inboxSize;
}

void initialize(A)(ref A allocator, ConcurencyConfig config)
{
	messageAllocator = Mallocator.cit;

	taskpool	= allocator.allocate!TaskThreadPool(allocator, config.numThreads, config.stackSize, config.inboxSize);
	taskpool.start();

	threads = allocator.allocate!(TaskThread*[])(config.numThreads); 
	foreach(ref thread; threads) 
		thread = allocator.allocate!TaskThread(allocator, 1024);

	registerThread("main");
}

//Special thread!
ReturnType!fun doTaskOnMain(alias fun, Args...)(Args args)
{
	return doBlockingTaskOn!("main", fun, Args)(args);
}


void doTaskOnMain(T)(T task)
{
	foreach(ref thread; threads) if(thread.id == "main")
	{
		return thread.doTask!(T)(task);
	}
	assert(0, "Thread not found!");
}


ReturnType!fun doBlockingTaskOn(string threadID, alias fun, Args...)(Args args)
{
	foreach(ref thread; threads) if(thread.id == threadID)
	{
		return thread.doWaitingTask!(fun, Args)(args);
	}
	assert(0, "Thread not found!");
}

void doPoolTask(alias fun, Args...)(Args args)
{
	taskpool.doTask!(fun, Args)(args);
}

struct Task(alias fun, Args...)
{
	bool isDone;

	Args args;
	static if(!is(ReturnType!fun == void))
		ReturnType!fun rt;

	this(Args a)
	{
		this.args		= a;
		this.isDone		= false;
	}

	void run()
	{
		static if(!is(ReturnType!fun == void))
			rt = fun(args);
		else 
			fun(args);

		isDone = true;
	}
}



auto task(F, Args...)(F fun, Args args)
{
	struct WrappedTask
	{
		F fun;
		Args args;

		this(F fun, Args args)
		{
			this.fun = fun;
			this.args = args;
		}

		void run()
		{
			fun(args);
		}
	}
	
	WrappedTask* task = messageAllocator.allocate!(WrappedTask)(fun, args);
	return task;
}

struct TaskThread
{
	MPSCQueue!(QueueSerializer) queue;
	Condition waitCond;
	string id = "";
	bool shouldStop;

	struct Message
	{
		void delegate() del;
		bool ownsData;
	}

	this(A)(ref A allocator, size_t queueSize)
	{
		queue = MPSCQueue!(QueueSerializer)(allocator, queueSize);
		auto mutex = GlobalAllocator.allocate!(Mutex)();
		waitCond   = GlobalAllocator.allocate!Condition(mutex);
		this.shouldStop = false;
	}

	~this()
	{
		waitCond.mutex().__dtor();
		waitCond.__dtor();
		GlobalAllocator.deallocate(waitCond.mutex);
		GlobalAllocator.deallocate(waitCond);
	}

	void doTask(T)(T task)
	{
		auto del = &task.run;
		queue.send(Message(del, true));
	}

	void doTask(alias fun, Args...)(Args args)
	{
		auto t = messageAllocator.allocate!(Task!(fun, Args))(args);
		auto del = &t.run;
		queue.send(Message(del, true));
	}

	ReturnType!fun doWaitingTask(alias fun, Args...)(Args args)
	{
		auto t = messageAllocator.allocate!(Task!(fun, Args))(args);
		scope(exit)	messageAllocator.deallocate(t[0 .. 1]);

		auto del = &t.run;
		queue.send(Message(del, false));

		synchronized(waitCond.mutex)
		{
			while(!t.isDone)
			{
				waitCond.wait();
			}
		}

		static if(!is(ReturnType!fun == void))
		{
			return t.rt;
		}
	}

	void consumeTasks()
	{
		static void taskfun(Message message)
		{
			message.del();
			if(message.ownsData)
				messageAllocator.deallocate(message.del.ptr[0 .. 1]);
		}
	
		while(queue.receive(&taskfun))
		{
			waitCond.notifyAll();
		}
	}
}

struct TaskThreadPool
{
	private WorkerPool pool;
	this(A)(ref A allocator, size_t numThreads, size_t stackSize, size_t inboxSize)
	{
		pool = WorkerPool(allocator, numThreads, stackSize,
						  inboxSize, &threadLoop);
	}

	~this()
	{
		pool.__dtor();
	}

	void start() { pool.start(); }
	void stop() { pool.stop(); }

	void doTask(alias fun, Args...)(Args args)
	{
		auto t = messageAllocator.allocate!(Task!(fun, Args))(args);
		auto del = &t.run;
		pool.send(del);
	}

	static void threadLoop(Inbox* inbox)
	{
		static void taskfun(void delegate() del)
		{
			try
			{
				del();
			}
			catch(Throwable t)
			{
				import log;
				auto chnl = LogChannel("Thread Crash!");
				chnl.info("Threre has been a crash in the thread!");
				chnl.info(t.toString);

				import std.stdio;
				writeln(t.toString);
				throw t;
			}
				messageAllocator.deallocate(del.ptr[0 .. 1]);
		}

		inbox.receive(&taskfun);
	}

	@disable this(this);
}