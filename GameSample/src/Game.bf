using System;
using SDL2;
using System.Threading;

namespace LuaTinker.GameSample;

class Game
{
    private WindowManager mWindowManager ~ delete _;
    private Renderer mRenderer ~ delete _;
    private GameState mGameState ~ delete _;
    private LuaScript mLuaScript ~ delete _;

    public this()
    {
        mWindowManager = new WindowManager("Breakout", 640, 480);
        mRenderer = new Renderer();
        mGameState = new GameState();

        mLuaScript = new LuaScript(mGameState);
        mLuaScript.CallInit();

		Sounds.Init();
    }

    public void Run()
    {
        float lastTime = (float)SDL.GetTicks() / 1000;

        while (true)
        {
            int keyDown = -1, keyUp = -1;
            bool shouldClose = false;

			mWindowManager.PollEvents((event) => {
				switch (event.type)
				{
				case .Quit:
				    shouldClose = true;
				case .KeyDown:
				    keyDown = (int)event.key.keysym.sym;
				    break;
				case .KeyUp:
				    keyUp = (int)event.key.keysym.sym;
				    break;
				default:
				}
			});
            
            if (shouldClose)
                break;

            if (keyDown != -1 || keyUp != -1)
            {
                if (keyDown != -1)
                    mLuaScript.CallOnInput(keyDown, true);
                if (keyUp != -1)
                    mLuaScript.CallOnInput(keyUp, false);
            }

            float currentTime = (float)SDL.GetTicks() / 1000;
            float deltaTime = currentTime - lastTime;
            lastTime = currentTime;

            mLuaScript.CallUpdate(deltaTime);

            Render(mRenderer);

            mWindowManager.SwapBuffers();
            Thread.Sleep(10);
        }
    }

	public void Render(Renderer renderer)
	{
	    renderer.BeginRender();

	    renderer.SetupRectangleShader();

	    for (var brick in mGameState.Bricks)
	    {
	        if (brick.Health > 0)
	        {
	            float r, g, b;
	            switch (brick.Health)
	            {
	            case 1: r = 0.8f; g = 0.3f; b = 0.3f; // Red
	            case 2: r = 0.3f; g = 0.3f; b = 0.8f; // Blue
	            case 3: r = 0.3f; g = 0.8f; b = 0.3f; // Green
	            default: r = 0.7f; g = 0.7f; b = 0.7f;
	            }
	            renderer.RenderRectangle(brick.X, brick.Y, 60.0f, 20.0f, r, g, b);
	        }
	        else if (brick.Health == -1)
	        {
	            renderer.RenderRectangle(brick.X, brick.Y, 60.0f, 20.0f, 0.4f, 0.4f, 0.4f); // Dark grey
	        }
	    }

	    renderer.RenderRectangle(mGameState.PaddleX, 450.0f, mGameState.PaddleWidth, 20.0f, 0.4f, 0.8f, 0.4f);
		
		renderer.SetupCircleShader();

	    for (var p in mGameState.PowerUps)
	    {
	        float r, g, b;
	        switch (p.Type)
	        {
	        case .WiderPaddle: r = 0.2f; g = 0.9f; b = 0.9f; // Cyan
	        case .MultiBall: r = 0.9f; g = 0.9f; b = 0.2f; // Yellow
	        default: r = 1.0f; g = 1.0f; b = 1.0f;
	        }
	        renderer.RenderCircle(p.X, p.Y, 20.0f, r, g, b);
	    }

	    renderer.RenderCircle(mGameState.Ball.X, mGameState.Ball.Y, 15.0f, 0.9f, 0.9f, 0.9f);

	    renderer.EndRender();
	}
}

static class Program
{
    public static int Main(String[] args)
    {
        Game game = scope Game();
        game.Run();
        return 0;
    }
}