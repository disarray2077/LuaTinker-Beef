using System;
using SDL2;
using BeefGL;

namespace LuaTinker.GameSample;

class WindowManager
{
    private SDL.Window* mWindow;
    private SDL.SDL_GLContext mContext;

    public this(String title, int32 width, int32 height)
    {
        SDL.Init(.Video);
        SDL.GL_SetAttribute(.GL_CONTEXT_MAJOR_VERSION, 3);
        SDL.GL_SetAttribute(.GL_CONTEXT_MINOR_VERSION, 3);
        SDL.GL_SetAttribute(.GL_CONTEXT_PROFILE_MASK, .GL_CONTEXT_PROFILE_CORE);

        mWindow = SDL.CreateWindow(title, .Undefined, .Undefined, width, height, .OpenGL | .Shown);
        mContext = SDL.GL_CreateContext(mWindow);
        SDL.GL_MakeCurrent(mWindow, (.)mContext);
        GL.Init(scope (proc) => SDL.GL_GetProcAddress(proc));
    }

    public ~this()
    {
        SDL.GL_DeleteContext(mContext);
        SDL.DestroyWindow(mWindow);
        SDL.Quit();
    }

    public void SwapBuffers()
    {
        SDL.GL_SwapWindow(mWindow);
    }

    public void PollEvents<F>(F handler)
		where F : delegate void(in SDL.Event)
    {
        while (SDL.PollEvent(let event) != 0)
			handler(event);
    }
}