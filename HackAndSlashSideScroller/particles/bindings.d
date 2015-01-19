module particles.bindings;

import util.traits;
import util.hash;
import util.variant;
import content.sdl;
import math.vector, graphics.color;
import std.traits;
import std.typetuple;
import particles.system;
import particles.updaters;
import particles.generators;

alias TypeTuple TT;
alias float2	F2;

//Particle Variables
alias PosVar        = TT!(float2,    "position");
alias VelVar        = TT!(float2,    "velocity");
alias ColorVar		= TT!(Color,	 "color");
alias StartColorVar = TT!(Color,     "startColor");
alias EndColorVar   = TT!(Color,     "endColor");
alias LifeTimeVar   = TT!(LifeSpan,  "lifeTime");

//System Variables
alias Origin		   = TT!(float2,	 "origin");

//Generator Variables

//For circlePosGen
alias CirclePosRadius   = TT!(float,      "circlePosRadius");

//For boxPosGen
alias BoxPosOffset		= TT!(float2,		"boxPosOffset");

//For circleVelGen
alias CircleSpeed       = TT!(Interval!float, "circleSpeed");

//For coneSpeedGen
alias ConeSpeed		    = TT!(Interval!float, "coneSpeed");
alias ConeAngle		    = TT!(Interval!float, "coneAngle");

//For basicVelGen
alias Velocity		    = TT!(Interval!float2,   "velocity");

//For basicColorGen
alias StartColor	    = TT!(Interval!Color,   "startColor");
alias EndColor		    = TT!(Interval!Color,   "endColor");

//For basicTimeGen
alias LifeTime			= TT!(Interval!float, "lifeTime");

struct Named(T)
{
	HashID name;
	T	   value;
}

__gshared ParticleSDLContext		sdlContext;

struct ParticleSDLContext
{
	template isPVar(alias T)
	{
		alias Type = Alias!(T.value);
		enum ident = T.ident;
		static if(is(typeof(Type.length == 2)) && is(typeof(Type[1]) == string))
		{
			enum isPVar = ident[$ - 3 .. $] != "Var";
		}
		else 
			enum isPVar = false;
	}
	
	alias ParticleVariable = Filter!(isPVar, Aliases!(particles.bindings));
	T read(T, C)(SDLIterator!(C)* iter) if(is(T == VariantTable!(32)))
	{
		auto loader(U)()
		{
			return variant!(32)(iter.as!U);
		}

		auto all   = iter.allocator;

		auto index = iter.currentIndex;
		auto len   = iter.walkLength;
		auto table = VariantTable!(32)(all, len + 1);

		iter.goToChild();
		foreach(i; 0 .. len)
		{
			auto obj = iter.over.root[iter.currentIndex];
			auto next = obj.nextIndex;
			auto name = iter.readName();

			bool found = false;
			foreach(varIndex, var; ParticleVariable)
			{
				if(ParticleVariable[varIndex].value[1] == name)
				{
					auto v = loader!(ParticleVariable[varIndex].value[0]);
					table.add(name, v);
					found = true;
					break;
				}
			}

			assert(found, "Name not found " ~ name);
			iter.currentIndex = next;
		}

		return table;
	}
}

Func[] stringToFunc(Func, string module_)(string[] array)
{
	mixin("import " ~ module_ ~ ";");
	alias functions = Filter!(isFunctionType!Func, Callables!(mixin(module_)));

	Func[] funcs;
	funcs.length = array.length;

	foreach(i, elem; array)
	{
		foreach(func; functions)
		{
			enum id = Identifier!(func);
			if(elem == id)
				funcs[i] = &func;
		}
	}

	return funcs;
}


ParticleVariable[] varConv(string[] array)
{
	template isPVar(alias T)
	{
		alias Type = Alias!(T.value);
		enum ident = T.ident;
		static if(is(typeof(Type.length == 2)) && is(typeof(Type[1]) == string))
		{
			enum isPVar = ident[$ - 3 .. $] == "Var";
		}
		else 
			enum isPVar = false;
	}

	alias ParticleVariables = Filter!(isPVar, Aliases!(particles.bindings));

	ParticleVariable[] vars;
	vars.length = array.length;

	foreach(i, elem; array)
	{
		bool found = false;
		foreach(part; ParticleVariables)
		{
			if(part.value[1] == elem)
			{
				ParticleVariable data;
				data.id = bytesHash(part.value[1]);
				data.type = cHash!(part.value[0]);
				data.elementSize = part.value[0].sizeof;
				data.data	= null;

				vars[i] = data;;
				found = true;
				break;
			}
			
		}
		
		assert(found, "Failed to find a particleVariable for " ~ elem);
	}

	return vars;
}

shared static this()
{
	//pragma(msg, "Classes");
	//pragma(msg, Classes!(particles.bindings));
	//pragma(msg, "Structs");
	//pragma(msg, Structs!(particles.bindings));
	//pragma(msg, "Interfaces");
	//pragma(msg, Interfaces!(particles.bindings));
	//pragma(msg, "Aliases");
	//pragma(msg, Aliases!(particles.bindings).stringof);
	//pragma(msg, "Imports");
	//pragma(msg, Imports!(particles.bindings).stringof);
	//pragma(msg, "Enums");
	//pragma(msg, Enums!(particles.bindings));
	//pragma(msg, "Types");
	//pragma(msg, Types!(particles.bindings));
	//pragma(msg, "Callables");
	//pragma(msg, Callables!(particles.updaters));

	try
	{
		import allocation;
		auto a = fromSDLFile!(ParticleSystem)(Mallocator.it, "particleTest.sdl", sdlContext);
		import log;
		logInfo(a);
		int dummy;
	}
	catch(Throwable t)
	{
		import log;
		logErr(t);
		
		import std.stdio;
		readln;
	}

}