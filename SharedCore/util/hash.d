module util.hash;

import std.traits;

struct HashID
{
	@safe nothrow pure:

	uint value;
	alias value this;

	this(uint value)
	{
		this.value = value;
	}

	this(T)(auto ref T t)
	{
		value = bytesHash(t).value;
	}

	this(T...)(auto ref T t)
	{
		uint value = 0;
		foreach(item; t)
		{
			value = bytesHash(item, value).value;
		}

		this.value = value;
	}

	void opAssign(HashID id)
	{
		this.value = id.value;
	}

	void opAssign(T)(auto ref T t)
	{
		this.value = bytesHash(t).value;
	}
}

struct TypeHash
{
	uint value;
}

struct ShortHash
{
	ushort value;
}

@trusted nothrow pure:

template shortHash(T)
{
	enum hash = cHash!T;
	enum shortHash = ShortHash((hash.value & 0xFFFF) ^ ((hash.value >> 16) & 0xFFFF));
}

template shortHash(string name)
{
	enum hash = bytesHash(name.ptr, name.length, 0);
	enum shortHash = ShortHash((hash.value & 0xFFFF) ^ ((hash.value >> 16) & 0xFFFF));
}

///Gets the hash of the type T (hash on the fully qualified name)
template cHash(T)
{
	import std.traits;
	enum name = fullyQualifiedName!T;
	enum cHash = TypeHash(bytesHash(name.ptr, name.length, 0).value);
}

HashID bytesHash(T)(T[] buffer, uint seed = 0)
{
	return bytesHash(buffer.ptr, buffer.length * T.sizeof, seed);
}

HashID bytesHash(T)(T item, uint seed = 0) if(!hasIndirections!T)
{
	auto ptr = (&item);
	return bytesHash(ptr, T.sizeof, seed);
}


//Murmur3 hash algorithm by Austin Appleby in public domain.
//Taken from Dlang/github/druntime
@trusted pure nothrow
HashID bytesHash(const(void)* buf, size_t len, size_t seed = 0)
{
    static uint rotl32(uint n)(in uint x) pure nothrow @safe
    {
        return (x << n) | (x >> (32 - n));
    }

    //-----------------------------------------------------------------------------
    // Block read - if your platform needs to do endian-swapping or can only
    // handle aligned reads, do the conversion here
    static uint get32bits(const (ubyte)* x) pure nothrow
    {
        //Compiler can optimize this code to simple *cast(uint*)x if it possible.
        version(HasUnalignedOps)
        {
            if (!__ctfe)
                return *cast(uint*)x; //BUG: Can't be inlined by DMD
        }
        version(BigEndian)
        {
            return ((cast(uint) x[0]) << 24) | ((cast(uint) x[1]) << 16) | ((cast(uint) x[2]) << 8) | (cast(uint) x[3]);
        }
        else
        {
            return ((cast(uint) x[3]) << 24) | ((cast(uint) x[2]) << 16) | ((cast(uint) x[1]) << 8) | (cast(uint) x[0]);
        }
    }

    //-----------------------------------------------------------------------------
    // Finalization mix - force all bits of a hash block to avalanche
    static uint fmix32(uint h) pure nothrow @safe
    {
        h ^= h >> 16;
        h *= 0x85ebca6b;
        h ^= h >> 13;
        h *= 0xc2b2ae35;
        h ^= h >> 16;

        return h;
    }

    auto data = cast(const(ubyte)*)buf;
    auto nblocks = len / 4;

    uint h1 = cast(uint)seed;

    enum uint c1 = 0xcc9e2d51;
    enum uint c2 = 0x1b873593;
    enum uint c3 = 0xe6546b64;

    //----------
    // body
    auto end_data = data+nblocks*uint.sizeof;
    for(; data!=end_data; data += uint.sizeof)
    {
        uint k1 = get32bits(data);
        k1 *= c1;
        k1 = rotl32!15(k1);
        k1 *= c2;

        h1 ^= k1;
        h1 = rotl32!13(h1);
        h1 = h1*5+c3;
    }

    //----------
    // tail
    uint k1 = 0;

    switch(len & 3)
    {
        case 3: k1 ^= data[2] << 16; goto case;
        case 2: k1 ^= data[1] << 8;  goto case;
        case 1: k1 ^= data[0];
			k1 *= c1; k1 = rotl32!15(k1); k1 *= c2; h1 ^= k1;
			goto default;
        default:
    }

    //----------
    // finalization
    h1 ^= len;
    h1 = fmix32(h1);
    return HashID(h1);
}