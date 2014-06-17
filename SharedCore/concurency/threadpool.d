module concurency.threadpool;
import allocation;
import concurency.messagepassing;
import core.thread;

alias Inbox  = SPMCQueue!(QueueSerializer);
alias Outbox = MPSCQueue!(QueueSerializer); 

struct ThreadPool
{
	private Inbox	_inbox;
	private Outbox	_outbox;
	private Thread[] threads; 	
	private bool running;
	private void function(Inbox*, Outbox*) func;

	Inbox*   inbox()	{ return &this._inbox; }
	Outbox* outbox()	{ return &this._outbox; }


	this(A)(ref A allocator, size_t numThreads, size_t stackSize,
			size_t inboxSize, size_t outboxSize,
			void function(Inbox*, Outbox*) func)
	{
		_inbox   = Inbox(allocator, inboxSize);
		_outbox  = Outbox(allocator, outboxSize); 
		threads = allocator.allocate!(Thread[])(numThreads); 

		void makeThread(size_t index)
		{
			threads[index] = allocator.allocate!Thread(() => run(index), stackSize);
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

	void receive(Handlers...)(Handlers handlers)
	{
		outbox.receive(handlers);
	}

	~this()
	{	
		foreach(thread; threads)
		{
			thread.__dtor();
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
		_outbox.stop();

		foreach(thread; threads) {
			thread.join();
		}
	}

	private void run(size_t index)
	{		
		while(running)
		{
			try
			{
				func(inbox, outbox);
			}
			catch(Throwable t)
			{
				import std.stdio, std.datetime, std.conv;
				{
					auto file = File("CRASH_" ~ Clock.currTime.to!string ~ ".txt", "+w");
					file.writeln(t);
				}
				import std.c.stdlib;
				readln;
				exit(-1);
			}	
		}
	}

	@disable this(this);
}
