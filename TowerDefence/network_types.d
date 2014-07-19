module network_types;

import network.message;
import network.luagen;
import math;

@InMessage struct TestMessageA
{
	int a;
	float b;
}

@OutMessage struct TestMessageB
{
	int a;
	float b;
}

@InMessage struct TestMessageC
{
	string a, b, c;
}

@OutMessage struct TestMessageD
{
	string a, b, c;
}

@InoutMessage struct TestMessageE
{
	float a;
}

struct TestA
{
	int a;
}

@InoutMessage struct TestMessageF
{
	TestA a;
}

struct TestB
{
	TestA a;
	string b;
}

@InoutMessage struct TestMessageG
{
	TestA a;
	TestB b;
}

@InoutMessage struct TestMessageH
{
	TestMessageG a;
	TestB b;
	string c;
	long d;
	ubyte[] e;
	float4 f;
}

@InoutMessage struct TestMessageI
{
	uint frame;
}

shared static this()
{
	auto luaCode = generateLuaCode!(network_types);
	import network.file;
	addGeneratedFile("tower_defence_network_types.luag", cast(void[])luaCode);
}