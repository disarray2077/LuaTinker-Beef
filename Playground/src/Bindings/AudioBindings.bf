using System;
using System.Collections;
using SDL2;
using LuaTinker.Helpers;

namespace LuaTinker.Playground;

struct MixerExclusions : IMethodExclusionProvider
{
    [Comptime]
    public static void CollectExcludedMethods(Type type, HashSet<StringView> excluded)
    {
        // The nightly SDL2 binding still gives this method the invalid LinkName "Version ".
        excluded.Add("MIX_Linked_Version");
    }
}

static class AudioBindings
{
    public static void Register(LuaTinker tinker)
    {
        tinker.AutoTinkClass<SDLMixer, MixerExclusions>(.Shallow);
    }
}
