layout(location = 0) in vec2 aPosition;
layout(location = 1) in vec4 aColor;

uniform vec2 uWorldSize;
out vec4 vColor;

void main() {
    vec2 ndc = aPosition / uWorldSize * 2.0 - 1.0;
    gl_Position = vec4(ndc.x, -ndc.y, 0.0, 1.0);
    vColor = aColor;
}
