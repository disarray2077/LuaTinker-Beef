namespace LuaTinker.GameSample;

public struct Ball
{
    public float X;
    public float Y;
	public float VelX;
	public float VelY;

    public this(float x, float y, float velX, float velY)
    {
        X = x;
        Y = y;
		VelX = velX;
		VelY = velY;
    }
}