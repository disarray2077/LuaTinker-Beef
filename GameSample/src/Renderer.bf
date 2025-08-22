using System;
using BeefGL;
using BeefGL.Graphics;

namespace LuaTinker.GameSample;

class Renderer
{
    private uint32 mVBO;
    private uint32 mVAO;
    private int32 mShaderProgram;
    private int32 mCircleShaderProgram;

    private String vertexShaderSource = """
        #version 330 core
        layout (location = 0) in vec2 aPos;

        uniform mat4 projection;
        uniform vec2 position;
        uniform vec2 size;

        void main()
        {
            vec4 worldPos = vec4(aPos.x * size.x + position.x, aPos.y * size.y + position.y, 0.0, 1.0);
            gl_Position = projection * worldPos;
        }
    """;

    private String fragmentShaderSource = """
        #version 330 core
        out vec4 FragColor;
        uniform vec3 color;
        
        void main()
        {
            FragColor = vec4(color, 1.0);
        }
    """;

    private String vertexShaderCircleSource = """
        #version 330 core
        layout (location = 0) in vec2 aPos;

        out vec2 v_uv;

        uniform mat4 projection;
        uniform vec2 position;
        uniform vec2 size;

        void main()
        {
            v_uv = aPos; // Pass local coords [-0.5, 0.5] to fragment shader
            vec4 worldPos = vec4(aPos.x * size.x + position.x, aPos.y * size.y + position.y, 0.0, 1.0);
            gl_Position = projection * worldPos;
        }
    """;

    private String fragmentShaderCircleSource = """
        #version 330 core
        in vec2 v_uv;
        out vec4 FragColor;
        uniform vec3 color;
        
        void main()
        {
            // v_uv is in range [-0.5, 0.5]. We scale it to [-1.0, 1.0]
            float dist = length(v_uv * 2.0);
            
            // If the pixel is outside our circle, discard it.
            if (dist > 1.0) {
                discard;
            }

            FragColor = vec4(color, 1.0);
        }
    """;

    public this()
    {
        InitGL();
    }

    public ~this()
    {
        GL.DeleteProgram(mShaderProgram);
        GL.DeleteProgram(mCircleShaderProgram);
        GL.DeleteBuffers(1, &mVBO);
        GL.glDeleteVertexArrays(1, &mVAO);
    }

    private void InitGL()
    {
        GL.Viewport(0, 0, 640, 480);

        int32 CompileShader(ShaderType type, String source)
        {
            int32 shader = GL.CreateShader(type);
#unwarn
            GL.ShaderSource(shader, 1, .(&source, 1), (int32*)null);
            GL.CompileShader(shader);
            int32 success = 0;
            GL.GetShader(shader, .CompileStatus, &success);
            if (success == 0)
            {
                String infoLog = scope .();
                GL.GetShaderInfoLog(shader, 512, null, infoLog);
                Console.WriteLine("ERROR: {0}", infoLog);
            }
            return shader;
        }

        int32 LinkProgram(int32 vertex, int32 fragment)
        {
            int32 program = GL.CreateProgram();
            GL.AttachShader(program, vertex);
            GL.AttachShader(program, fragment);
            GL.LinkProgram(program);
            int32 success = 0;
            GL.GetProgram(program, .LinkStatus, &success);
            if (success == 0)
            {
                String infoLog = scope .();
                GL.GetProgramInfoLog(program, 512, null, infoLog);
                Console.WriteLine("ERROR: {0}", infoLog);
            }
            return program;
        }

        // Create standard shader program
        int32 vertexShader = CompileShader(.VertexShader, vertexShaderSource);
        int32 fragmentShader = CompileShader(.FragmentShader, fragmentShaderSource);
        mShaderProgram = LinkProgram(vertexShader, fragmentShader);
        GL.DeleteShader(vertexShader);
        GL.DeleteShader(fragmentShader);

        // Create circle shader program
        int32 circleVertexShader = CompileShader(.VertexShader, vertexShaderCircleSource);
        int32 circleFragmentShader = CompileShader(.FragmentShader, fragmentShaderCircleSource);
        mCircleShaderProgram = LinkProgram(circleVertexShader, circleFragmentShader);
        GL.DeleteShader(circleVertexShader);
        GL.DeleteShader(circleFragmentShader);

        // Create VAO and VBO for unit square
        GL.glGenVertexArrays(1, &mVAO);
        GL.GenBuffers(1, &mVBO);

        float[?] vertices = .(-0.5f, -0.5f, 0.5f, -0.5f, 0.5f, 0.5f, -0.5f, 0.5f);

        GL.glBindVertexArray(mVAO);
        GL.BindBuffer(.ArrayBuffer, mVBO);
        GL.BufferData(.ArrayBuffer, vertices.Count * sizeof(float), &vertices[0], .StaticDraw);
        GL.VertexAttribPointer(0, 2, .Float, false, 2 * sizeof(float), null);
        GL.EnableVertexAttribArray(0);
        GL.BindBuffer(.ArrayBuffer, 0);
        GL.glBindVertexArray(0);
    }

    public void BeginRender()
    {
        GL.ClearColor(0.1f, 0.1f, 0.15f, 1.0f);
        GL.Clear(.ColorBufferBit);
    }

    public void SetupRectangleShader()
    {
        GL.UseProgram(mShaderProgram);
        float[16] projection = .();
        OrthoMatrix(0, 640, 480, 0, -1, 1, &projection);
        int32 projLoc = GL.GetUniformLocation(mShaderProgram, "projection");
        GL.UniformMatrix4(projLoc, 1, false, &projection[0]);
        GL.glBindVertexArray(mVAO);
    }

    public void RenderRectangle(float x, float y, float width, float height, float r, float g, float b)
    {
        int32 posLoc = GL.GetUniformLocation(mShaderProgram, "position");
        int32 sizeLoc = GL.GetUniformLocation(mShaderProgram, "size");
        int32 colorLoc = GL.GetUniformLocation(mShaderProgram, "color");

        GL.Uniform2(posLoc, x, y);
        GL.Uniform2(sizeLoc, width, height);
        GL.Uniform3(colorLoc, r, g, b);
        GL.DrawArrays(.TriangleFan, 0, 4);
    }

    public void SetupCircleShader()
    {
        GL.UseProgram(mCircleShaderProgram);
        float[16] projection = .();
        OrthoMatrix(0, 640, 480, 0, -1, 1, &projection);
        int32 projLoc = GL.GetUniformLocation(mCircleShaderProgram, "projection");
        GL.UniformMatrix4(projLoc, 1, false, &projection[0]);
    }

    public void RenderCircle(float x, float y, float diameter, float r, float g, float b)
    {
        int32 posLoc = GL.GetUniformLocation(mCircleShaderProgram, "position");
        int32 sizeLoc = GL.GetUniformLocation(mCircleShaderProgram, "size");
        int32 colorLoc = GL.GetUniformLocation(mCircleShaderProgram, "color");

        GL.Uniform2(posLoc, x, y);
        GL.Uniform2(sizeLoc, diameter, diameter);
        GL.Uniform3(colorLoc, r, g, b);
        GL.DrawArrays(.TriangleFan, 0, 4);
    }

    public void EndRender()
    {
        GL.glBindVertexArray(0);
    }

    private void OrthoMatrix(float left, float right, float bottom, float top, float near, float far, float* result)
    {
        for (int i = 0; i < 16; i++) result[i] = 0.0f;
        result[0] = 2.0f / (right - left);
        result[5] = 2.0f / (top - bottom);
        result[10] = -2.0f / (far - near);
        result[12] = -(right + left) / (right - left);
        result[13] = -(top + bottom) / (top - bottom);
        result[14] = -(far + near) / (far - near);
        result[15] = 1.0f;
    }
}