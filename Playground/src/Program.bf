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
#if BF_PLATFORM_WASM
        // The browser starts individual Lua sessions through PlaygroundStart.
        return 0;
#else
        const String defaultScript = "Playground/dist/sdl_render.lua";
        String scriptPath = scope .();
        Path.GetFullPath(args.Count > 0 ? args[0] : defaultScript, scriptPath);

        String script = scope .();
        if (File.ReadAllText(scriptPath, script) case .Err(let error))
        {
            Console.Error.WriteLine($"Cannot read {scriptPath}: {error}");
            return 1;
        }

        if (!Initialize(scriptPath))
            return 1;
        defer { Dispose(); }

		// TODO: Periodic GC steps work around observed memory growth; the cause is unresolved.
		// Investigate Lua's accounting of Beef-owned wrapper memory before removing this workaround.
		if (sLua.DoString("""
		    local counter = 0
		    local originalSwap = SDL.GL_SwapWindow

		    SDL.GL_SwapWindow = function(...)
		        counter = counter + 1

		        if counter % 100 == 0 then
		            collectgarbage("step", 0)
		        end

		        return originalSwap(...)
		    end
		    """))
		{
		    Console.Error.WriteLine(sLua.ToString(-1, .. scope .()));
		    return 1;
		}

        if (sLua.DoString(script, scriptPath))
        {
            Console.Error.WriteLine(sLua.ToString(-1, .. scope .()));
            return 1;
        }
        return 0;
#endif
    }

    private static bool Initialize(StringView scriptPath)
    {
        String scriptDirectory = scope .();
        if (Path.GetDirectoryPath(scriptPath, scriptDirectory) case .Err)
        {
            Console.Error.WriteLine($"Cannot get directory for {scriptPath}");
            return false;
        }
        if (Directory.SetCurrentDirectory(scriptDirectory) case .Err(let directoryError))
        {
            Console.Error.WriteLine($"Cannot set working directory to {scriptDirectory}: {directoryError}");
            return false;
        }

        sLua = new Lua(true);
        sLua.Encoding = System.Text.Encoding.UTF8;
        sTinker = new LuaTinker(sLua);
        Register(sTinker, sLua);

        sLua.PushString(scriptPath);
        sLua.SetGlobal("PlaygroundScript");

        return true;
    }

    private static void Register(LuaTinker tinker, Lua lua)
    {
        SDLBindings.Register(tinker);
        ImageBindings.Register(tinker);
        AudioBindings.Register(tinker);
        FontBindings.Register(tinker);
        OpenGLBindings.Register(tinker);
        FormsBindings.Register(tinker, lua.TinkerState);

        tinker.AddClass<String>("StringBuilder");
        tinker.AddClassCtor<String>();
        tinker.AutoTinkClass<List<float>>(.Shallow, name: "FloatList");
        tinker.AutoTinkClass<List<uint8>>(.Shallow, name: "UInt8List");
        tinker.AddMethod<function IntPtr(float*)>("ToIntPtr", (pointer) => (void*)pointer); // sad...
    }

    private static void Dispose()
    {
        delete sTinker;
        delete sLua;
        sTinker = null;
        sLua = null;
    }
}
