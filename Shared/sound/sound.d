module sound.sound;

import derelict.sdl2.sdl;
import derelict.sdl2.mixer;
import content.sound;
import std.algorithm;


struct Sound
{
	Mix_Chunk* mixChunk;
}

void obliterate(Sound sound)
{
	auto numChannels = Mix_AllocateChannels(-1);
	foreach(i; 0 .. numChannels)
	{
		auto chunk = Mix_GetChunk(i);
		if(chunk is sound.mixChunk)
		{
			Mix_HaltChannel(i);
		}
	}
	Mix_FreeChunk(sound.mixChunk);
}

struct SoundInstance
{
	SoundPlayer* player;
	SoundID playing;
	int channel;

	void pause()
	{
		assert(channel != int.max, "The sound instance has already been discarded!");
		player.pauseSound(channel);
	}

	void resume()
	{
		assert(channel != int.max, "The sound instance has already been discarded!");
		player.resumeSound(channel);
	}

	void stop()
	{
		assert(channel != int.max, "The sound instance has already been discarded!");
		player.stopSound(channel);
		channel = int.max;
	}
}


struct SoundConfig
{
	uint freq;
	uint numChannels;
	uint bufferSize;

	float musicVolume;
	float soundVolume;
	float masterVolume;

	string musicFoulderPath;
}

struct SoundPlayer
{
	private Mix_Music* music = null;
	private string musicFoulderPath;
	private float _masterVolume, _musicVolume, _soundVolume;
	
	this(A)(ref A allocator, SoundConfig config)
	{
		auto err = Mix_OpenAudio(config.freq, 
								 MIX_DEFAULT_FORMAT, 
								 MIX_DEFAULT_CHANNELS,
								 config.bufferSize);
		Mix_AllocateChannels(config.numChannels);
		musicFoulderPath = config.musicFoulderPath;
		_masterVolume = config.masterVolume;

	}

	~this()
	{
		unloadMusic();
		Mix_HaltChannel(-1);
		Mix_CloseAudio();
	}

	SoundInstance playSound(SoundID toPlay, int loopCount = 0)
	{
		auto sound = SoundManager.lookup(toPlay);
		auto channel = Mix_PlayChannel(-1, sound.mixChunk, loopCount);

		return SoundInstance(&this, toPlay, channel);
	}

	void pauseSound(int channel)
	{
		Mix_Pause(channel);
	}

	void resumeSound(int channel)
	{
		Mix_Resume(channel);
	}

	void stopSound(int channel)
	{
		Mix_HaltChannel(channel);
	}

	@property float masterVolume()
	{
		return _masterVolume;
	}

	@property void masterVolume(float volume)
	{
		volume = min(1, max(0, volume));
		_masterVolume = volume;

		//Must update device volume.
		soundVolume = _soundVolume;
		musicVolume = _musicVolume;
	}

	@property float soundVolume()
	{
		return _soundVolume;
	}

	@property void soundVolume(float volume)
	{
		volume = min(1, max(0, volume)) * masterVolume;
		_soundVolume = volume;

		 Mix_Volume(-1, cast(int)(_soundVolume * _masterVolume * MIX_MAX_VOLUME));
	}

	//Music stuff.
	@property void musicVolume(float volume)
	{
		import std.algorithm;
		volume = min(1, max(0, volume)) * masterVolume;
		_musicVolume = volume;
		Mix_VolumeMusic(cast(int)(_musicVolume * _masterVolume * MIX_MAX_VOLUME));
	}

	@property float musicVolume()
	{
		return _musicVolume;
	}

	void playMusic(string file, int loopCount = -1)
	{
		unloadMusic();
		loadMusic(file);

		Mix_PlayMusic(music, loopCount);
	}
	
	void pauseMusic()
	{
		assert(music, "Can't pause music if it's not playing!");
		Mix_PauseMusic();
	}

	void resumeMusic()
	{
		Mix_ResumeMusic();
	}

	void stopMusic()
	{
		Mix_HaltMusic();
	}

	private void loadMusic(string path)
	{
		import std.path, util.strings, std.conv;
		auto c_path = buildPath(musicFoulderPath, path).toCString();
		music = Mix_LoadMUS(c_path);
		assert(music, text("Failed to load music file ", c_path));
	}

	private void unloadMusic()
	{
		if(music)
		{
			Mix_HaltMusic();
			Mix_FreeMusic(music);
			music = null;
		}
	}
}