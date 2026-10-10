using System;
using KeraLua;
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
        case "Init", "InitSubSystem", "Quit", "GetTicks", "Delay", "GetError", "CreateWindow", "CreateRenderer",
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
    private static void Nest(Lua lua, StringView name)
    {
        lua.GetGlobal("SDL");
        lua.GetGlobal(name);
        lua.SetField(-2, name);
        lua.Pop(1);
    }

    public static void Register(LuaTinker tinker, Lua lua)
    {
        tinker.AutoTinkClass<SDL, const "", SDLExportExclusions>();
        lua.GetGlobal("SDL2");
        lua.GetField(-1, "SDL");
        lua.SetGlobal("SDL");
        lua.Pop(1);

        tinker.AddNamespace("SDL2.SDL.WindowPos");
        tinker.AddNamespaceVar("SDL2.SDL.WindowPos", "Undefined", (int32)SDL.WindowPos.Undefined);
        tinker.AddNamespaceVar("SDL2.SDL.WindowPos", "Centered", (int32)SDL.WindowPos.Centered);

        // SDL handles are borrowed by Lua; the script destroys them explicitly.
        tinker.AddClass<SDL.Window>("Window");
        tinker.AddClass<SDL.Renderer>("Renderer");
        tinker.AddClass<SDL.Texture>("Texture");

        tinker.AutoTinkClass<SDL.Rect>();
        Nest(lua, "Rect");
        tinker.AutoTinkClass<SDL.Event>();
        tinker.AddClassCtor<SDL.Event, void>();
        Nest(lua, "Event");

        tinker.AutoTinkClass<SDL.CommonEvent>();
        tinker.AutoTinkClass<SDL.DisplayEvent>();
        tinker.AutoTinkClass<SDL.WindowEvent>();
        tinker.AutoTinkClass<SDL.KeyboardEvent>();
        tinker.AutoTinkClass<SDL.KeySym>();
        tinker.AutoTinkClass<SDL.TextEditingEvent>();
        tinker.AutoTinkClass<SDL.TextEditingExtEvent>();
        tinker.AutoTinkClass<SDL.TextInputEvent>();
        tinker.AutoTinkClass<SDL.MouseMotionEvent>();
        tinker.AutoTinkClass<SDL.MouseButtonEvent>();
        tinker.AutoTinkClass<SDL.MouseWheelEvent>();
        tinker.AutoTinkClass<SDL.JoyAxisEvent>();
        tinker.AutoTinkClass<SDL.JoyBallEvent>();
        tinker.AutoTinkClass<SDL.JoyHatEvent>();
        tinker.AutoTinkClass<SDL.JoyButtonEvent>();
        tinker.AutoTinkClass<SDL.JoyDeviceEvent>();
        tinker.AutoTinkClass<SDL.JoyBatteryEvent>();
        tinker.AutoTinkClass<SDL.ControllerAxisEvent>();
        tinker.AutoTinkClass<SDL.ControllerButtonEvent>();
        tinker.AutoTinkClass<SDL.ControllerDeviceEvent>();
        tinker.AutoTinkClass<SDL.ControllerTouchpadEvent>();
        tinker.AutoTinkClass<SDL.ControllerSensorEvent>();
        tinker.AutoTinkClass<SDL.AudioDeviceEvent>();
        tinker.AutoTinkClass<SDL.TouchFingerEvent>();
        tinker.AutoTinkClass<SDL.MultiGestureEvent>();
        tinker.AutoTinkClass<SDL.DollarGestureEvent>();
        tinker.AutoTinkClass<SDL.DropEvent>();
        tinker.AutoTinkClass<SDL.SensorEvent>();
        tinker.AutoTinkClass<SDL.QuitEvent>();

        tinker.AddNamespaceEnum<SDL.InitFlag>("SDL2.SDL");
        tinker.AddNamespaceEnum<SDL.WindowFlags>("SDL2.SDL");
        tinker.AddNamespaceEnum<SDL.RendererFlags>("SDL2.SDL");
        tinker.AddNamespaceEnum<SDL.BlendMode>("SDL2.SDL");
        tinker.AddNamespaceEnum<SDL.EventType>("SDL2.SDL");
        tinker.AddNamespaceEnum<SDL.Keycode>("SDL2.SDL");
        tinker.AddNamespaceEnum<SDL.SDL_GLAttr>("SDL2.SDL");
        tinker.AddNamespaceEnum<SDL.SDL_GLProfile>("SDL2.SDL", typed: true);
        tinker.AddNamespaceEnum<SDL.WindowEventID>("SDL2.SDL");
        tinker.AddNamespaceEnum<SDL.Scancode>("SDL2.SDL");
        tinker.AddNamespaceEnum<SDL.KeyMod>("SDL2.SDL", typed: true);
        tinker.AddNamespaceEnum<SDL.DisplayEventID>("SDL2.SDL");
        tinker.AddNamespaceEnum<SDL.DisplayOrientation>("SDL2.SDL");
        tinker.AddNamespaceEnum<SDL.MouseWheelDirection>("SDL2.SDL");
        tinker.AddNamespaceEnum<SDL.SDL_JoystickPowerLevel>("SDL2.SDL");
        tinker.AddNamespaceEnum<SDL.SDL_GameControllerAxis>("SDL2.SDL");
        tinker.AddNamespaceEnum<SDL.SDL_GameControllerButton>("SDL2.SDL");
        tinker.AddNamespaceEnum<SDL.SDL_SensorType>("SDL2.SDL");
    }

}
