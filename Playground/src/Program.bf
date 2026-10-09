using System;
using System.IO;
using KeraLua;

namespace LuaTinker.Playground;

static class Program
{
    public static int Main(String[] args)
    {
        StringView scriptPath = args.Count > 0 ? args[0] : "Playground/sdl_render.lua";
        String script = scope .();
        if (File.ReadAllText(scriptPath, script) case .Err(let error))
        {
            Console.Error.WriteLine($"Cannot read {scriptPath}: {error}");
            return 1;
        }

        let lua = scope Lua(true);
        lua.Encoding = System.Text.Encoding.UTF8;
        let tinker = scope LuaTinker(lua);
        SDLBindings.Register(tinker, lua);
        lua.PushString(scriptPath);
        lua.SetGlobal("PlaygroundScript");

        if (lua.DoString(script, scriptPath))
        {
            Console.Error.WriteLine(lua.ToString(-1, .. scope .()));
            return 1;
        }
        return 0;
    }
}
