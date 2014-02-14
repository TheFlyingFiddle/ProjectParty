module achtung_game_data;

import collections.list;
import graphics.color;

struct PlayerData
{
	ulong playerId;
	Color color;
	int score;
}

class AchtungGameData
{
	this(A)(ref A allocator, size_t maxPlayers)
	{
		data = List!PlayerData(allocator, maxPlayers);
	}
	
	List!PlayerData data;
}