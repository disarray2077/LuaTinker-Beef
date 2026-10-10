using System;
using System.Collections;
using SDL2;
using LuaTinker.Helpers;

namespace LuaTinker.Playground;

static class AudioBindings
{
    public static void Register(LuaTinker tinker)
    {
        tinker.AutoTinkClass<SDLMixer>();
    }
}
