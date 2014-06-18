module framework.player;
import std.traits;
import network.router;
import collections.table;
import allocation;

template isPlayer(T)
{
	enum isPlayer = hasMember!(T, "name") && is(typeof(T.init.name) == string); 
}

enum playerDefaultName = "Unkown";


struct PlayerService(P) if(isPlayer!P)
{
	alias PlayerTable = Table!(ulong, P, SortStrategy.sorted);
	PlayerTable players;

	this(A)(ref A al, size_t numPlayers, Router* router)
	{
		players = PlayerTable(al, numPlayers);

		router.connections		~= &onConnect;
		router.reconnections	~= &onConnect;
		router.disconnections	~= &onDisconnect;
	}

	void onConnect(ulong id)	 
	{
		P player;
		player.name = playerDefaultName;
		players[id] = player;
	}

	void onDisconnect(ulong id)	
	{
		auto player = id in players;
		if(player.name != playerDefaultName)
			Mallocator.it.deallocate(cast(void[])player.name);

		players.remove(id);
	}
}