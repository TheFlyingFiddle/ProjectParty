module util.servicelocator;
import util.hash;
import collections;
import util.strings;
import std.conv;
import std.algorithm;

struct ServiceLocator
{
	struct Service
	{
		HashID hash;
		void* ptr; 
	}	

	List!Service  services;
	this(A)(ref A allocator, size_t size)
	{
		services = List!Service(allocator, size);
	}

	private HashID hashOf(T)(string name)
	{
		auto hash = bytesHash(T.stringof, bytesHash(name));
		return hash;
	}

	void add(T)(T* service, string name = "") if(is(T == struct))
	{
		auto hash = hashOf!T(name);
		assert(!services.canFind!(x => x.hash == hash), text("Already present in locator: Type: ", T.stringof, " Name: ", name));
		services ~= Service(hash, cast(void*)service);
	}

	bool tryFind(T)(out T* item, string name = "")
	{		
		auto hash = hashOf!(T)(name);
		foreach(service; services)
		{
			if(hash == service.hash)
			{
				item = cast(T*)service.ptr;
			}
		}
		return false;
	}	

	bool tryFind(T)(out T item, string name = "")
	{		
		auto hash = hashOf!(T)(name);
		foreach(service; services)
		{
			if(hash == service.hash)
			{
				item = cast(T)service.ptr;
			}
		}
		return false;
	}	



	T* find(T)(string name = "") if(is(T == struct))
	{
		auto hash = hashOf!(T)(name);
		foreach(service; services)
		{
			if(hash == service.hash)
				return cast(T*)service.ptr;
		}

		assert(0, "Failed to find service :" ~ T.stringof);
	}

	void add(T)(T service, string name = "") if(is(T == class) || is(T == interface)) 
	{		
		auto hash = hashOf!(T)(name);
		services ~= Service(hash, cast(void*)service);
	}

	T find(T)(string name = "") if(is(T == class) || is(T == interface))
	{
		auto hash = hashOf!(T)(name);
		foreach(service; services)
		{
			if(hash == service.hash)
				return cast(T*)service.ptr;
		}

		assert(0, "Failed to find service");
	}

	void remove(T)()
	{
		auto hash = cHash!T;
		foreach(i, s; services) if(s.hash == hash)
		{
			services.removeAt(i);
			return;
		}	
	}

	void remove(string name = "")
	{
		auto hash = bytesHash(name);
		foreach(i, s; services) if(s.hash == hash)
		{
			services.removeAt(i);
			return;
		}	
	}
}
