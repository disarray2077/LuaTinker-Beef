namespace LuaTinker.GameSample;

public enum PowerUpType
{
    None,
    WiderPaddle,
    MultiBall,
}

public struct PowerUp
{
    public float X;
    public float Y;
    public PowerUpType Type;

    public this(float x, float y, PowerUpType type)
    {
        X = x;
        Y = y;
        Type = type;
    }
}