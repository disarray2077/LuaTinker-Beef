using System;
using KeraLua;

namespace LuaTinker.Playground;

#if BF_PLATFORM_WASM
extension Program
{
    private static Lua sThread;
    private function void FrameCallback();

    [CLink, CallingConvention(.Stdcall)]
    private static extern void emscripten_set_main_loop(FrameCallback callback, int32 fps, int32 simulateInfiniteLoop);

    [CLink, CallingConvention(.Stdcall)]
    private static extern void emscripten_cancel_main_loop();

    private static int RunBrowser()
    {
        sLua.PushBoolean(true);
        sLua.SetGlobal("WASM");

        if (sLua.DoString("SDL.Delay = function() coroutine.yield() end"))
        {
            Console.Error.WriteLine(sLua.ToString(-1, .. scope .()));
            DisposeBrowser();
            return 1;
        }

        sThread = sLua.NewThread();
        if (sThread.LoadString("dofile(PlaygroundScript)") != .OK)
        {
            Console.Error.WriteLine(sThread.ToString(-1, .. scope .()));
            DisposeBrowser();
            return 1;
        }

        emscripten_set_main_loop(=> BrowserFrame, 0, 1);
        return 0;
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
        DisposeBrowser();
    }

    private static void DisposeBrowser()
    {
        emscripten_cancel_main_loop();
        if (sThread != null)
        {
            delete sThread;
            sThread = null;
            sLua.Pop(1);
        }
        Dispose();
    }
}
#endif
