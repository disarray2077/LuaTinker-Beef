namespace LuaTinker.GameSample;

public struct Brick
{
    public float X;
    public float Y;
    public int Health; // 0 = broken, -1 = unbreakable, >0 = hits left

    public this(float x, float y, int health)
    {
        X = x;
        Y = y;
        Health = health;
    }
}