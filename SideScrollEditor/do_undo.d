module do_undo;

import std.traits;
import allocation;
import log;
import virtual_dispatch;
import collections.list;

struct DoUndoCommands(T...)
{
	template isCommand(U)
	{
		enum isCommand = is(U == struct) &&
		__traits(compiles, 
		{
			T t;
			U u;
			u.apply(t);
			u.revert(t);
		});
	}

	struct ICommand
	{
		void apply(T t) { }
		void revert(T t) { }

		@Optional void clear() { }
	}

	alias Command = ClassN!(ICommand, 64);
	GrowingList!Command commands;
	private size_t redoCount;

	//Will fix this later...
	//Better fix is to add gc allocator...
	this(size_t initialSize)
	{
		redoCount  = 0;
		commands   = GrowingList!(Command)(Mallocator.cit, initialSize);
	}

	bool canRedo()
	{
		return redoCount > 0;
	}
	
	void add(U)(T t, auto ref U u) if(isCommand!U)
	{
		if(redoCount > 0)
		{
			foreach(i; commands.length - redoCount .. commands.length)
				commands[i].clear();

			commands.length = commands.length - redoCount;
			redoCount = 0;
		}

		commands ~= Command(u);
	}

	void apply(U)(T t, auto ref U u) if(isCommand!U)
	{
		add!(U)(t, u);
		commands[$ - 1].apply(t);
	}

	void undo(T t)
	{
		if(commands.length > redoCount)
		{
			commands[$ - redoCount - 1].revert(t);
			redoCount++;
		}
	}

	void redo(T t)
	{
		if(redoCount > 0)
		{
			commands[$ - redoCount].apply(t);
			redoCount--;
		}
	}

	void clear()
	{
		foreach(ref cmd; commands)
			cmd.clear();

		commands.clear();
		redoCount = 0;
	}
}