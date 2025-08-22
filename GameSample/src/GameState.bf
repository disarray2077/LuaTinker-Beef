using System;
using System.Collections;

namespace LuaTinker.GameSample;

class GameState
{
    public float PaddleX = 320;
    public float PaddleWidth = 100.0f;

    public Ball Ball = .(x: 320, y: 430, velX: 250, velY: -250);

    public List<Brick> Bricks = new .() ~ delete _;
    public List<PowerUp> PowerUps = new .() ~ delete _;

    public bool GameOver = false;
    public bool GameWon = false;
    public int Score = 0;
    public int Lives = 3;

    public bool BallIsLaunched = false;

    public void Reset()
    {
        PaddleX = 320;
        PaddleWidth = 100.0f;
        Ball.X = 320;
        Ball.Y = 430;
        Ball.VelX = 250;
        Ball.VelY = -250;
        Bricks.Clear();
        PowerUps.Clear();
        GameOver = false;
        GameWon = false;
        Score = 0;
        Lives = 3;
        BallIsLaunched = false;
    }

    public void ResetBall(float ballX)
    {
        PaddleWidth = 100.0f;
        Ball.X = ballX;
        Ball.Y = 430;
        Ball.VelX = 250;
        Ball.VelY = -250;
        PowerUps.Clear();
        BallIsLaunched = false;
    }

    public void OnBrickBreak()
    {
        // Console.WriteLine("Beef: Brick broken! Score: {0}", Score);
    }

    public void OnBallLost()
    {
        Console.WriteLine("Beef: Ball lost! Lives left: {0}", Lives);
    }

    public void OnGameWin()
    {
        Console.WriteLine("Beef: You win! Final Score: {0}", Score);
    }

    public void OnGameOver()
    {
        Console.WriteLine("Beef: You lost! Final Score: {0}", Score);
    }

    public void PlaySound(String name)
    {
		switch (name)
		{
		case "powerup":
			Sounds.PlaySound(Sounds.sPowerUp);
		case "wall_hit", "paddle_hit", "brick_hit", "unbreakable_hit":
			Sounds.PlaySound(Sounds.sBallTap);
		case "brick_break":
			Sounds.PlaySound(Sounds.sBrickBreak);
		}
        Console.WriteLine("SOUND: Playing '{0}'", name);
    }
}