module game.state;
import collections.list;
import std.variant;


template isState(T)
{
	enum isState = __traits(compiles, 
	{
		T t;
		t.enter(); 
		t.exit();
	});
}

struct FSM(T, ID) 
	if(isState!(T))
{
	import std.algorithm;
	struct State
	{
		T state;
		ID id;
	}

	List!State states;
	State _currentState;
	
	this(A)(ref A allocator, size_t numStates)
	{
		states = List!State(allocator, numStates);
	}
	
	void transitionTo(ID id)
	{
		assert(states.canFind!(x => x.id == id), 
				 "Trying to transition to a state that does not exist!");

		if(_currentState.id != ID.init)
			_currentState.state.exit();

		_currentState = states.find!(x => x.id == id).front;
		_currentState.state.enter();

		import std.stdio;
		writeln(_currentState.state," ", _currentState.id);
	}

	void addState(T _state, ID id)
	{
		auto state = State(_state, id);
		assert(!states.canFind!(x => x.id == id));
		states ~= state;
	}
	
	auto ref opDispatch(string name, Args...)(Args args)
	{
		assert(this._currentState.state, "No state set!");

		mixin("this._currentState.state." ~ name ~ "(args);");
	}

	@disable this(this);
}	
