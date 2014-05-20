module test_state;
import content.sdl, network.message, collections,
	   allocation, game.state, game, std.datetime;

struct TestSession
{
	ushort packetSize;
	float sendInterval;
}

struct TestConfig
{
	TestSession[] sessions;
	float  sessionInterval;
	string saveFile;
}

struct Roundtrip
{
	TickDuration start;
	TickDuration end;
	bool done = false;
}

struct Session
{
	Table!(ulong, Roundtrip[]) roundtrips;
	ushort sendSequence;
}

@(OutgoingNetworkMessage(50)) struct OutMsg
{
	ushort sequence;
	ubyte[] load;
}

@(IncommingNetworkMessage(50)) struct InMsg
{
	ushort sequence;
	ubyte[] load;
}

class TestState : IGameState
{
	TestConfig config;
	bool testing = false;
	bool firstTestFrame = true;
	uint sessionIndex = 0;
	float elapsedTime = 0;
	float timeSinceLastPacket = 0;
	Session[] sessions;

	TickDuration[] sensorTimes;
	TickDuration lastSensorValue;

	this(string configFile)
	{
		import allocation;
		config = fromSDLFile!TestConfig(GC.it, configFile);
		sessions = new Session[config.sessions.length];
	}
	
	void update()
	{
		if(testing)
		{
			elapsedTime += Time.delta;
			timeSinceLastPacket += Time.delta;
			if(elapsedTime >= config.sessionInterval)
			{
				timeSinceLastPacket = 0;
				if(allPacketsRecived())
					nextSession();

				return;
			}

			while(timeSinceLastPacket >= config.sessions[sessionIndex].sendInterval)
			{
				sendPacket();	
				timeSinceLastPacket -= config.sessions[sessionIndex].sendInterval;
			}
		}
		else 
		{
			if(Keyboard.isDown(Key.enter))
			{
				firstSession();
			}
		}
	}

	void firstSession()
	{
		foreach(i, ref session; sessions) {
			session.roundtrips = Table!(ulong, Roundtrip[])(GC.it, Game.players.length);
			foreach(player; Game.players)
			{
				session.roundtrips[player.id] 
					= new Roundtrip[cast(uint)(config.sessionInterval / config.sessions[i].sendInterval)];
			}
		}
		sessionIndex = 0;
	    testing = true;
		lastSensorValue = Clock.currSystemTick;
	}

	void nextSession()
	{
		sessionIndex++;
		elapsedTime = 0;
		timeSinceLastPacket = 0;

		if(sessionIndex == sessions.length)
		{	
			end();
		}
	}

	void end()
	{
		import std.algorithm, std.math;
		testing = false;

		import std.stdio;
		foreach(i, ref session; sessions)
		{
			writeln("Session ", i , ":");
			int count = 0;
			foreach(roundtrips; session.roundtrips)
			{		
				writeln("Phone ", count++); 
				auto rtMap = roundtrips.map!(x => (x.end - x.start).msecs);
				auto total = reduce!"a + b"(0L, rtMap);
				auto avg = total / roundtrips.length;
				auto stdev = sqrt(cast(float)total / cast(float)(roundtrips.length - avg) * avg);
				writeln("Average ", avg , " stdev ", stdev);
				writeln("Min: ", reduce!((a, b) => min(a, b))( 1000L, rtMap));
				writeln("Max: ", reduce!((a, b) => max(a, b))(-1000L, rtMap));
			}
		}

		auto sMap = sensorTimes.map!(x => x.msecs);
		auto total = reduce!"a + b"(0L, sMap);
		auto avg = total / sensorTimes.length;
		auto s = sqrt(cast(float)total / cast(float)(sensorTimes.length - avg) * avg);
		writeln("Average ", avg , " stdev ", s);
		writeln("Min: ", reduce!((a, b) => min(a, b))(1000L, sMap));
		writeln("Max: ", reduce!((a, b) => max(a, b))(-1000L, sMap));
	}

	bool allPacketsRecived()
	{
		foreach(roundTrips; sessions[sessionIndex].roundtrips)
		{
		}

		return true;
	}

	void sendPacket()
	{
		import std.stdio;
		writeln("Sending packet");
		ubyte[0xFFFF] load = void;
		ushort id = cast(ushort)(sessions[sessionIndex].sendSequence++);
	
		foreach(player; Game.players) {
			sessions[sessionIndex].roundtrips[player.id][id].start = Clock.currSystemTick;
			Game.server.sendMessage(player.id, OutMsg(id, load[0 .. config.sessions[sessionIndex].packetSize]));
		}
	}

	void receivePacket(ulong id, ubyte[] msg)
	{
		if(!testing) return;
		
		import std.stdio;
		writeln("Reviced packet");	
		import util.bitmanip;
		auto sequence = msg.read!ushort;
		sessions[sessionIndex].roundtrips[id][sequence].end  = Clock.currSystemTick;
		sessions[sessionIndex].roundtrips[id][sequence].done = true;
	}

	void reciveSensorData(ulong id, ubyte[] msg)
	{
		if(!testing) return;

		auto tick = Clock.currSystemTick;
		if((tick - lastSensorValue).msecs == 0) return;
		
		sensorTimes ~= (tick - lastSensorValue);
		lastSensorValue = tick;
	}

	void enter()
	{
		Game.router.setMessageHandler(50, &receivePacket);
		Game.router.setMessageHandler(1,  &reciveSensorData);
	}

	void exit()
	{

	}

	void render()
	{

	}
}