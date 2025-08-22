using System;
using SDL2;
using System.Collections;

namespace LuaTinker.GameSample;

static class Sounds
{
	public static Sound sBallTap;
	public static Sound sBrickBreak;
	public static Sound sPowerUp;

	static List<Sound> sSounds = new .() ~ delete _;

	public static void Dispose()
	{
		ClearAndDeleteItems(sSounds);
	}

	public static Result<Sound> Load(StringView fileName)
	{
		Sound sound = new Sound();
		if (sound.Load(fileName) case .Err)
		{
			delete sound;
			return .Err;
		}
		sSounds.Add(sound);
		return sound;
	}

	public static Result<void> Init()
	{
		sBallTap = Load("sounds/tap.wav").GetValueOrDefault();
		sBrickBreak = Load("sounds/break.wav").GetValueOrDefault();
		sPowerUp = Load("sounds/powerup.wav").GetValueOrDefault();
		return .Ok;
	}

	public static void PlaySound(Sound sound, float volume = 1.0f, float pan = 0.5f)
	{
		if (sound == null)
			return;

		int32 channel = SDLMixer.PlayChannel(-1, sound.mChunk, 0);
		if (channel < 0)
			return;
		SDLMixer.Volume(channel, (int32)(volume * 128));
	}
}
