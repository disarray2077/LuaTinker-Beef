using System;
using System.Collections;
using KeraLua;
using SDL2;

namespace LuaTinker.Playground;

#if BF_PLATFORM_WASM
extension Program
{
    private static Lua sThread;
    private static List<SDL.SDL_GLContext> sGLContexts = new .() ~ delete _;

    private function void FrameCallback();

    [CLink, CallingConvention(.Stdcall)]
    private static extern void emscripten_set_main_loop(FrameCallback callback, int32 fps, int32 simulateInfiniteLoop);

    [CLink, CallingConvention(.Stdcall)]
    private static extern void emscripten_cancel_main_loop();

    [CLink, CallingConvention(.Stdcall)]
    private static extern void emscripten_run_script(char8* script);

    [Export, CLink]
    public static int32 PlaygroundStart(char8* path)
    {
        PlaygroundStop();
        if (!Initialize(StringView(path)))
            return 1;

        // Track contexts so an interrupted script does not leave them behind between runs.
        sTinker.AddNamespaceMethod<function SDL.SDL_GLContext(SDL.Window*)>("SDL2.SDL", "GL_CreateContext", => CreateGLContext);
        sTinker.AddNamespaceMethod<function void(SDL.SDL_GLContext)>("SDL2.SDL", "GL_DeleteContext", => DeleteGLContext);

        sLua.PushBoolean(true);
        sLua.SetGlobal("WASM");

        if (sLua.DoString("SDL.Delay = function() coroutine.yield() end"))
        {
            Console.Error.WriteLine(sLua.ToString(-1, .. scope .()));
            PlaygroundStop();
            return 1;
        }

        sThread = sLua.NewThread();
        if (sThread.LoadString("dofile(PlaygroundScript)") != .OK)
        {
            Console.Error.WriteLine(sThread.ToString(-1, .. scope .()));
            PlaygroundStop();
            return 1;
        }

        emscripten_set_main_loop(=> BrowserFrame, 0, 0);
        return 0;
    }

    private static SDL.SDL_GLContext CreateGLContext(SDL.Window* window)
    {
        let context = SDL.GL_CreateContext(window);
        if (context != default)
            sGLContexts.Add(context);
        return context;
    }

    private static void DeleteGLContext(SDL.SDL_GLContext context)
    {
        sGLContexts.Remove(context);
        SDL.GL_DeleteContext(context);
    }

    private static void BrowserFrame()
    {
        let status = sThread.Resume(sLua, 0, let results);
        if (status == .Yield)
        {
            sThread.Pop(results);
            return;
        }
        if (status != .OK)
            Console.Error.WriteLine(sThread.ToString(-1, .. scope .()));
        else
            sThread.Pop(results);
        PlaygroundStop();
        emscripten_run_script("Module.onPlaygroundStopped();");
    }

    [Export, CLink]
    public static void PlaygroundStop()
    {
        emscripten_cancel_main_loop();

        if (sThread != null)
        {
            delete sThread;
            sThread = null;
            sLua.Pop(1);
        }

        Dispose();

        for (let context in sGLContexts)
            SDL.GL_DeleteContext(context);
        sGLContexts.Clear();

        // Stop cannot resume the script's normal cleanup after its last yield.
        while (SDLMixer.QuerySpec(let frequency, let format, let channels) > 0)
            SDLMixer.CloseAudio();

        SDLMixer.Quit();
        SDLImage.Quit();
        SDL.Quit();
    }
}
#endif
