module concurency.threadpool;
import allocation;
import concurency.messagepassing;
import core.thread;
import log;

alias Inbox  = SPMCQueue!(QueueSerializer);
struct WorkerPool
{
	private Inbox	_inbox;
	private Thread[] threads; 	
	private bool running;
	private void function(Inbox*) func;

	Inbox*   inbox()	{ return &this._inbox; }

	this(A)(ref A allocator, size_t numThreads, size_t stackSize,
			size_t inboxSize, void function(Inbox*) func)
	{
		_inbox   = Inbox(allocator, inboxSize);
		threads = allocator.allocate!(Thread[])(numThreads); 

		void makeThread(size_t index)
		{
			threads[index] = GlobalAllocator.allocate!Thread(() => run(index), stackSize);
		}

		foreach(i;0 .. numThreads)
		{
			makeThread(i);
		}

		this.func = func;
	}

	void send(T)(auto ref T toSend)
	{
		inbox.send(toSend);
	}

	~this()
	{	
		this.stop();
		_inbox.__dtor();
		foreach(thread; threads)
		{
			thread.__dtor();
			GlobalAllocator.deallocate(thread);
		}
	}	

	void start()
	{
		this.running = true;
		foreach(thread; threads)
			thread.start();
	}

	void stop()
	{
		this.running = false;
		_inbox.stop();
	}

	private void run(size_t index)
	{		
		while(running)
		{
			try
			{
				func(inbox);
			}
			catch(Throwable t)
			{
				logErr("Thread crashed!", t);	
				return;
			}	
		}
	}

	@disable this(this);
}