module game.state;
import collections.list;


interface IGameState
{
	void init();

	void enter();
	void exit();

	void handleInput();
	void update();
	void render();
}


template isState(T)
{
	enum isState = __traits(compiles, 
	{
		T t;
		t.enter();
		t.exit();
	});
}

unittest
{
	alias GameStateFSM = FSM!(IGameState, string);

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
	}

	void addState(T _state, ID id)
	{
		auto state = State(_state, id);
		assert(!states.canFind!(x => x.id == id));
		states ~= state;
	}
	
	auto ref opDispatch(string name, Args...)(Args args)
	{
		mixin("this._currentState.state." ~ name ~ "(args);");
	}
}	

unittest
{
	alias GameStateFSM = FSM!(IGameState, string);

	GSFSM fsm;
	fsm.update();
}