module loader;

import content, std.json, spriter.types, math;

auto readFile(JSONValue[string] file)
{
	File f;
	foreach(k, v; file) switch(k)
	{
		case "height"  : f.height	 = cast(int)v.integer;   break;
		case "width"   : f.width	 = cast(int)v.integer;   break;
		case "name"    : f.name		 = v.str;				    break;
		case "pivot_x" : f.origin.x = cast(float)v.floatOrInt; break;
		case "pivot_y" : f.origin.y = v.floatOrInt; break;

	   default: break;
	}
	return f;
}

auto readFiles(JSONValue[] files)
{
	File[] f;
	foreach(v; files)
		f ~= readFile(v.object);

	return f;
}

auto readFoulder(JSONValue[string] foulder)
{
	Foulder f;
	foreach(k, v; foulder) switch(k)
	{
		case "file": f.files = readFiles(v.array); break;
		case "name": f.name = v.str; break;
		default: break;
	}

	return f;
}

auto readObjectRef(JSONValue[string] ref_)
{
	Ref r;
	foreach(k, v; ref_) switch(k)
	{
		case "key":			r.key			= cast(int)v.integer; break;
		case "timeline":	r.timeline	= cast(int)v.integer; break;
		case "z_index":	r.z_index	= cast(int)v.integer; break;
		default: break;
	}
	return r;
}

auto readObjectRefs(JSONValue[] refs)
{	
	Ref[] r;
	foreach(v; refs) r ~= readObjectRef(v.object);
	return r;
}

auto readMainKey(JSONValue[string] key)
{
	MainlineKey m;
	foreach(k, v; key)
	{
		switch(k)
		{
			case "time": m.time = cast(int)v.integer / 1000f; break;
			case "object_ref": m.objectRefs = readObjectRefs(v.array);	break;
			default: break;
		}
	}

	return m;
}

auto readMainlines(JSONValue[string] mainline)
{
	MainlineKey[] m;
	foreach(v; mainline["key"].array) 
	{
		m ~= readMainKey(v.object);
	}
	return m;
}

float floatOrInt(JSONValue value)
{
	return value.type == JSON_TYPE.FLOAT ? value.floating : value.integer;
}

auto readSpatial(JSONValue[string] spatial)
{
	SpatialInfo info;
	foreach(k, v; spatial) 
	{		
		switch(k)
		{
			case "file"	 :	info.file		= cast(int)v.integer;	  break;
			case "folder": info.foulder	= cast(int)v.integer;     break;
			case "a"		 : info.alpha     = v.floatOrInt;  break;
			case "x"		 : info.pos.x     = v.floatOrInt;  break;
			case "y"     : info.pos.y     = v.floatOrInt;  break;
			case "scale_x": info.scale.x  = v.floatOrInt;  break;
			case "scale_y": info.scale.y  = v.floatOrInt;  break;
			case "pivot_x": info.origin.x = v.floatOrInt;  break;
			case "pivot_y": info.origin.y = v.floatOrInt;  break;
			case "angle":   info.rotation = v.floatOrInt / 360 * TAU;

			default: break;
		}
	}

	return info;
}

auto readTKey(JSONValue[string] tKey)
{
	TimelineKey t;
	foreach(k, v; tKey) switch(k)
	{
		case "object": t.info		= readSpatial(v.object);		 break;
		case "spin"  : t.spin		= cast(int)v.integer;			 break;
		case "time"  : t.time      = cast(int)v.integer / 1000f;	 break;
		case "c0"	 : t.curve0    = v.floatOrInt();					 break;
		case "c1"    : t.curve1    = v.floatOrInt();					 break;
		case "curve_type" : 
			switch(v.str)
			{
				case "instant":
					t.curveType = CurveType.instant;
					break;
				case "linear":
					t.curveType = CurveType.linear;
					break;
				case "quadratic":
					t.curveType = CurveType.quadratic;
					break;
				case "cubic":
					t.curveType = CurveType.cubic;
					break;
				default: assert(0, "Invalid curve type");
			}
			break;

		default: break;
	}

	return t;
}


auto readTKeys(JSONValue[] keys)
{
	TimelineKey[] t;
	foreach(v; keys) t ~= readTKey(v.object);
	return t;
}


auto readTimeline(JSONValue[string] timelines)
{
	Timeline t;
	foreach(k, v; timelines) switch(k)
	{
		case "name": t.name = v.str; break;
		case "key":  t.keys = readTKeys(v.array);	break;
		default: break;
	}
	return t;
}

auto readTimelines(JSONValue[] timelines)
{
	Timeline[] t;
	foreach(v; timelines) t ~= readTimeline(v.object);
	return t;
}


auto readAnimation(JSONValue[string] animation)
{
	Animation a;
	foreach(k,v; animation) 
	{
		switch(k)
		{
			case "length":   a.length = v.integer / 1000f; break;
			case "mainline": a.mainlines = readMainlines(v.object); break;
			case "timeline": a.timelines = readTimelines(v.array); break;
			case "name":	  a.name      = v.str;	 
			default: break;
		}
	}

	return a;
}

auto readAnimations(JSONValue[] animations)
{
	Animation[] a;
	foreach(v; animations)	a ~= readAnimation(v.object);
	return a;
}

auto readEntity(JSONValue[string] entity)
{
	Entity e;
	foreach(k, v; entity) 
	{
		switch(k)
		{
			case "name":		 e.name = v.str; break;
			case "animation":  e.animations = readAnimations(v.array);	break;
			default: break;
		}
	}
	return e;
}

auto readEntities(JSONValue[] entities)
{
	Entity[] e;
	foreach(v; entities) e ~= readEntity(v.object);
	return e;
}

void obliterate(SpriterObject object)
{
	//Do nothing right now...
}

SpriterObject loadCollection(const(char)[] path)
{
	import std.file : readText;
	auto json = parseJSON(readText(path));

	auto object = SpriterObject();
	foreach(k, v; json.object)
	{
		if(k == "folder")
		{
			foreach(f; v.array)	
				object.foulders ~= readFoulder(f.object);
		} 
		else if(k == "entity")
		{
			object.entities = readEntities(v.array);
		}
	}

	foreach(entity; object.entities)
		foreach(animation; entity.animations)
			foreach(timeline; animation.timelines)
				foreach(ref key; timeline.keys)
				{
					if(std.math.isNaN(key.info.origin.x) != 0)
					{
						float2 origin = object.foulders[key.info.foulder].files[key.info.file].origin;
						key.info.origin = origin;
					}
				}

	return object;
}

struct SpriteManager
{
	alias Table = ResourceTable!(SpriterObject, obliterate);
	private static Table resources;

	static init(A)(ref A allocator, uint capacity)
	{
		import allocation;
		resources = Table(allocator, capacity);

		FileExtention[1] ext = [FileExtention.scon];
		ContentReloader.registerReloader(AssetType.spriter, ext, &auto_reload);
	}


	static void shutdown()
	{
		foreach(ref resource; resources)
			resource.obliterate();
	}

	void auto_reload(const(char)[] path)
	{
		reload(path);
	}

	static SpriteObjectID load(const(char)[] path)
	{
		auto index = resources.indexOf(path);
		if(index != -1)
			return SpriteObjectID(index);

		import std.path;
		auto col = loadCollection(buildPath(resourceDir, path));
		index = resources.add(col, path);
		return SpriteObjectID(index);

	}

	static void unload(const(char)[] path)
	{
		resources.remove(path);
	}

	static SpriteObjectID reload(const(char)[] path)
	{
		auto index = resources.indexOf(path);
		if (index == -1) {
			return load(path);
		}

		import std.path;
		auto col = loadCollection(buildPath(resourceDir, path));
		resources.replace(col, path);
		return SpriteObjectID(index);
	}

	static bool isLoaded(const(char)[] path)
	{
		import std.algorithm;
		return resources.indexOf(path) != -1;
	}	

	static ref SpriterObject lookup(SpriteObjectID id)
	{
		return resources[id.index];
	}
}