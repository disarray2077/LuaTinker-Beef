layout(location = 0) in vec2 localPosition;
out vec2 uv;

void main() {
    uv = localPosition + 0.5;
    gl_Position = vec4(localPosition * 2.0, 0.0, 1.0);
}
