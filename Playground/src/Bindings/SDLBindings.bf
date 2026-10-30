using System;
using SDL2;
using LuaTinker.Helpers;
using System.Collections;

using internal LuaTinker.Playground;

namespace LuaTinker.Playground;

// One export scan per AutoTinkClass expansion, not one subprocess per method.
struct SDLExportExclusions : IMethodExclusionProvider
{
    [Comptime]
    public static void CollectExcludedMethods(Type type, HashSet<StringView> excluded)
    {
        if (type != typeof(SDL))
            return;
        String exports = scope .();
        HashSet<StringView> symbols = scope .();
        let scanned = PlatformTools.TryCollectSDLExports(exports, symbols);

        for (let method in type.GetMethods(.Public | .DeclaredOnly))
        {
            if (scanned)
            {
                if (!method.HasCustomAttribute<LinkNameAttribute>())
                    continue;
                // SDL2.bf uses SDL_ + method name for its extern LinkNames.
                String symbol = scope $"SDL_{method.Name}";
                // SDL2.bf misspells this LinkName without the SDL_ prefix.
                if (!symbols.Contains(symbol) || method.Name == "JoystickRumbleTriggers")
                    excluded.Add(method.Name);
            }
            else if (!FallbackIncludes(method.Name))
                excluded.Add(method.Name);
        }
    }

    [Comptime]
    private static bool FallbackIncludes(StringView name)
    {
        switch (name)
        {
        case "Init", "InitSubSystem", "Quit", "GetTicks", "Delay", "GetError", "GetVersion", "CreateWindow", "CreateRenderer",
             "CreateTextureFromSurface", "FreeSurface",
             "DestroyWindow", "DestroyRenderer", "DestroyTexture", "PushEvent", "PollEvent",
             "SetRenderDrawColor", "RenderClear", "RenderPresent", "RenderFillRect",
             "RenderDrawRect", "RenderDrawLine", "RenderCopy", "RenderSetLogicalSize",
             "QueryTexture", "SetTextureBlendMode", "SetTextureColorMod", "SetTextureAlphaMod",
             "GL_CreateContext", "GL_MakeCurrent", "GL_DeleteContext",
             "GL_SetAttribute", "GL_SwapWindow", "GL_GetProcAddress":
            return true;
        default:
            return false;
        }
    }
}

static class SDLBindings
{
    public static void Register(LuaTinker tinker)
    {
        using (let sdl = tinker.BeginNamespace("SDL"))
        {
            sdl.AutoTinkClass<SDL.Color>(.Shallow);
            sdl.AutoTinkClass<SDL, SDLExportExclusions, ?>(.Deep, .IncludeAll, .Inline);
            using (let positions = sdl.BeginNamespace("WindowPos"))
            {
                positions.AddVar("Undefined", (int32)SDL.WindowPos.Undefined);
                positions.AddVar("Centered", (int32)SDL.WindowPos.Centered);
            }
            // These enum values select the corresponding numeric overloads.
            sdl.AddEnum<SDL.SDL_GLProfile>(typed: true);
            sdl.AddEnum<SDL.KeyMod>(typed: true);
        }
        tinker.AddClassCtor<SDL.Event, void>();
    }
}
