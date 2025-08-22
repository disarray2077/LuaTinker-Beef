using System;
using System.Collections;
using KeraLua;
using SDL2;
using System.IO;

namespace LuaTinker.GameSample;

class LuaScript
{
    private Lua mLua ~ delete _;
    private LuaTinker mTinker ~ delete _;
    private GameState mGameState;

    public this(GameState gameState)
    {
        mGameState = gameState;
        
        mLua = new Lua(true);
        mLua.Encoding = System.Text.Encoding.UTF8;
        mTinker = new LuaTinker(mLua);

        mTinker.AutoTinkClass<Ball>();

        mTinker.AutoTinkClass<Brick>();
        mTinker.AutoTinkClass<List<Brick>>();

        mTinker.AddEnum<PowerUpType>();
        mTinker.AutoTinkClass<PowerUp>();
        mTinker.AutoTinkClass<List<PowerUp>>();

        mTinker.AutoTinkClass<GameState>();
        mTinker.SetValue("game", mGameState);

		mTinker.AddEnum<SDL.Keycode>();

        LoadGameScript();
    }

	private void LoadGameScript()
	{
	    String luaScript = scope .();
	    if(File.ReadAllText("game.lua", luaScript) case .Err(let err))
	        Runtime.FatalError(err.ToString(.. scope .()));

	    if (mLua.DoString(luaScript, "game.lua"))
	        Runtime.FatalError(mLua.ToString(-1, .. scope .()));
	}

	public void CallInit()
	{
	    mTinker.Call("init");
	}

	public void CallUpdate(float deltaTime)
	{
	    mTinker.Call<void, float>("update", deltaTime);
	}

	public void CallOnInput(int keycode, bool pressed)
	{
	    mTinker.Call<void, (int, bool)>("on_input", (keycode, pressed));
	}
}