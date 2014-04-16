module content.sound;

import content, sound.sound, util.strings;

struct SoundID
{
	import derelict.sdl2.mixer;
	uint index;
}

struct SoundManager
{
	alias Table = ResourceTable!(Sound, sound.sound.obliterate); 
	private static Table resources;

	static init(A)(ref A allocator, uint capacity)
	{
		resources = Table(allocator, capacity);

		import content.reloading;
		FileExtention[5] exts =
		[ FileExtention.ogg, 
		FileExtention.wav, 
		FileExtention.aiff, 
		FileExtention.riff, 
		FileExtention.voc ];

		ContentReloader.registerReloader(AssetType.sound, exts, &auto_reload);
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

	static SoundID load(const(char)[] path)
	{
		auto index = resources.indexOf(path);
		if(index != -1)
			return SoundID(index);


		import std.path;
		const(char)* c_path = buildPath(resourceDir, path).toCString();

		auto sound = loadSound(c_path);
		index = resources.add(sound, path);
		return SoundID(index);
	}

	static void unload(const(char)[] path)
	{
		resources.remove(path);
	}

	static SoundID reload(const(char)[] path, uint paramConfig = 0)
	{
		auto index = resources.indexOf(path);
		if (index == -1) {
			return load(path);
		}

		import std.path;
		const(char)* c_path = buildPath(resourceDir, path).toCString();

		auto tex = loadSound(c_path);
		resources.replace(tex, path);

		return SoundID(index);
	}

	static bool isLoaded(const(char)[] path)
	{
		import std.algorithm;
		return resources.indexOf(path) != -1;
	}	

	static ref Sound lookup(SoundID id)
	{
		return resources[id.index];
	}
}

Sound loadSound(const(char*) path)
{
	import derelict.sdl2.mixer, std.conv;

	Mix_Chunk* chunk = Mix_LoadWAV(path);
	assert(chunk, text("Failed to load sound! ", path));

	return Sound(chunk);
}