using System;
using KeraLua;

namespace LuaTinker.Playground;

#if BF_PLATFORM_WASM
extension Program
{
    private static Lua sThread;
    private static int sCancellationKey;

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

        sLua.PushBoolean(true);
        sLua.SetGlobal("WASM");

        if (sLua.LoadString("""
            local cancellation = ...
            local yield = coroutine.yield

            local function resumeYield(...)
                if select(1, ...) == cancellation then
                    error(cancellation, 0)
                end
                return ...
            end

            coroutine.yield = function(...)
                return resumeYield(yield(...))
            end
            SDL.Delay = function() coroutine.yield() end
            """) != .OK)
        {
            Console.Error.WriteLine(sLua.ToString(-1, .. scope .()));
            PlaygroundStop();
            return 1;
        }

        sLua.PushLightUserData(&sCancellationKey);
        if (sLua.PCall(1, 0, 0) != .OK)
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

        // SDL disconnects its playback node without clearing the callback; queued events can see a later run's audio.
        emscripten_run_script("""
            var audioNode = Module['SDL2']?.audio?.scriptProcessorNode;
            if (audioNode) audioNode.onaudioprocess = null;
            """);

        if (sThread != null)
        {
            if (sThread.Status == .Yield)
            {
                // Resume at the yield point so the script's protected call reaches its cleanup.
                sThread.PushLightUserData(&sCancellationKey);
                let status = sThread.Resume(sLua, 1, let results);
                if (status == .OK || status == .Yield)
                    sThread.Pop(results);
                else if (sThread.Type(-1) != .LightUserData || sThread.ToUserData(-1) != &sCancellationKey)
                    Console.Error.WriteLine(sThread.ToString(-1, .. scope .()));
            }
            delete sThread;
            sThread = null;
            sLua.Pop(1);
        }

        Dispose();
    }
}
#endif
