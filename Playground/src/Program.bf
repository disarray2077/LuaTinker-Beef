using System;
using System.IO;
using System.Collections;
using BeefGL.Helpers;
using KeraLua;

namespace LuaTinker.Playground;

static class Program
{
    private static Lua sLua;
    private static LuaTinker sTinker;

    public static int Main(String[] args)
    {
        String scriptPath = scope .();
        Path.GetFullPath(args.Count > 0 ? args[0] : "Playground/sdl_render.lua", scriptPath);

#if !BF_PLATFORM_WASM
        String script = scope .();
        if (File.ReadAllText(scriptPath, script) case .Err(let error))
        {
            Console.Error.WriteLine($"Cannot read {scriptPath}: {error}");
            return 1;
        }
#endif

        String scriptDirectory = scope .();
        if (Path.GetDirectoryPath(scriptPath, scriptDirectory) case .Err)
        {
            Console.Error.WriteLine($"Cannot get directory for {scriptPath}");
            return 1;
        }
        if (Directory.SetCurrentDirectory(scriptDirectory) case .Err(let directoryError))
        {
            Console.Error.WriteLine($"Cannot set working directory to {scriptDirectory}: {directoryError}");
            return 1;
        }

        sLua = new Lua(true);
        sLua.Encoding = System.Text.Encoding.UTF8;
        sTinker = new LuaTinker(sLua);
        Register(sTinker, sLua);

        sLua.PushString(scriptPath);
        sLua.SetGlobal("PlaygroundScript");

#if BF_PLATFORM_WASM
        return RunBrowser();
#else
        defer { Dispose(); }
        if (sLua.DoString(script, scriptPath))
        {
            Console.Error.WriteLine(sLua.ToString(-1, .. scope .()));
            return 1;
        }

        return 0;
#endif
    }

    private static void Dispose()
    {
        delete sTinker;
        delete sLua;
        sTinker = null;
        sLua = null;
    }

    private static void Register(LuaTinker tinker, Lua lua)
    {
        SDLBindings.Register(tinker, lua);
        ImageBindings.Register(tinker, lua);
        AudioBindings.Register(tinker);
        OpenGLBindings.Register(tinker);

        tinker.AddClass<String>("StringBuilder");
        tinker.AddClassCtor<String>();
        tinker.AutoTinkClass<List<float>, const "FloatList">();
        tinker.AutoTinkClass<List<uint8>, const "UInt8List">();
        tinker.AddMethod<function IntPtr(float*)>("ToIntPtr", (pointer) => (void*)pointer); // sad...
    }
}
