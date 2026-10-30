in vec2 uv;
out vec4 fragmentColor;

uniform vec4 clockState; // time, lives, score, state (0 playing, 1 lost, 2 won)
uniform vec4 comboState; // multiplier, timer fraction, hit pulse, hit count
uniform vec4 levelState; // level, transition fraction, reserved, reserved
uniform vec4 paddle;     // x, y, width, height
uniform vec4 ball;       // x, y, radius, launched
uniform vec4 bricks[36]; // x, y, health, flash
uniform vec4 drops[16];  // x, y, active, reserved
uniform vec4 trail[16];  // x, y, intensity, reserved
uniform vec4 impacts[8]; // x, y, age, strength (zero is inactive)

float boxSDF(vec2 p, vec2 halfSize, float radius) {
    vec2 q = abs(p) - halfSize + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

float cover(float d) {
    return 1.0 - smoothstep(-0.7, 0.7, d);
}

vec3 tint(float h) {
    if (h < 0.0)
        return vec3(0.30, 0.45, 0.58);
    if (h < 1.5)
        return vec3(1.0, 0.16, 0.32);
    if (h < 2.5)
        return vec3(0.26, 0.30, 1.0);
    return vec3(0.08, 0.88, 0.56);
}

void material(inout vec3 col, vec2 p, vec2 center, vec2 halfSize, vec3 base, float flash, float metal) {
    vec2 q = p - center;

    // Uniform/object-space branches avoid expensive shading far from a shape.
    if (any(greaterThan(abs(q), halfSize + 26.0)))
        return;

    float d = boxSDF(q, halfSize, 4.0);
    float shadow = boxSDF(q - vec2(0.0, 4.0), halfSize, 4.0);
    col *= 1.0 - 0.45 * (1.0 - smoothstep(-1.0, 8.0, shadow));
    col += base * exp(-max(d, 0.0) * 0.20) * 0.20;

    // Finite differences of the SDF provide a rounded bevel normal.
    vec2 grad = vec2(boxSDF(q + vec2(0.5, 0), halfSize, 4.0) - boxSDF(q - vec2(0.5, 0), halfSize, 4.0),
                     boxSDF(q + vec2(0, 0.5), halfSize, 4.0) - boxSDF(q - vec2(0, 0.5), halfSize, 4.0));
    float bevel = smoothstep(-4.0, 0.0, d);
    vec3 n = normalize(vec3(grad * bevel, 0.7));

    vec3 light = normalize(vec3(ball.xy - p, 95.0));
    float attenuation = 1.0 / (1.0 + dot(ball.xy - p, ball.xy - p) / 16000.0);
    float diffuse = max(dot(n, normalize(vec3(-0.4, -0.6, 1))), 0.0);
    float spec = pow(max(dot(n, normalize(light + vec3(0, 0, 1))), 0.0), 32.0);
    vec3 surface = base * (0.32 + diffuse * 0.7 + attenuation * 0.45);
    surface += vec3(0.55, 0.85, 1.0) * spec * attenuation * 0.9;

    surface += base * exp(-abs(d + 1.4) * 2.0) * 0.55;
    surface *= 1.0 - metal * 0.12 * (0.5 + 0.5 * sin(q.x * 2.4));
    surface += flash * vec3(1.3, 1.0, 0.8);

    col = mix(col, surface, cover(d));
}

float digit(vec2 p, int n) {
    int masks[10] = int[10](63, 6, 91, 79, 102, 109, 125, 7, 127, 111);
    vec2 centers[7] = vec2[7](vec2(0, -6), vec2(3, -3), vec2(3, 3), vec2(0, 6), vec2(-3, 3), vec2(-3, -3), vec2(0, 0));
    float d = 100.0;

    for (int i = 0; i < 7; ++i) {
        if ((masks[n] & (1 << i)) != 0) {
            vec2 h = (i == 0 || i == 3 || i == 6) ? vec2(2.3, 0.6) : vec2(0.6, 2.3);
            d = min(d, boxSDF(p - centers[i], h, 0.3));
        }
    }

    return cover(d);
}

void main() {
    vec2 p = vec2(uv.x, 1.0 - uv.y) * vec2(640, 480);
    float t = clockState.x;
    float heat = clamp((comboState.x - 1.0) / 7.0, 0.0, 1.0);
    vec3 comboColor = mix(vec3(0.08, 0.55, 1.0), vec3(1.0, 0.23, 0.06), heat);
    vec2 v = (p - vec2(320, 240)) / vec2(320, 240);
    vec3 col = mix(vec3(0.006, 0.012, 0.03), vec3(0.018, 0.042, 0.075), uv.y);
    float grid = min(abs(mod(p.x, 32.0) - 16.0), abs(mod(p.y + t * 4.0, 32.0) - 16.0));
    col += vec3(0.02, 0.08, 0.12) * exp(-grid * 2.0) * 0.22;
    col += vec3(0.018, 0.009, 0.045) * (0.5 + 0.5 * sin(p.x * 0.014 + p.y * 0.009 + t * 0.4));
    float wall = min(p.x, 640.0 - p.x);
    col += vec3(0.04, 0.35, 0.55) * exp(-wall * 0.32) * 0.65;

    for (int i = 0; i < 16; ++i) {
        if (trail[i].z > 0.0) {
            vec2 q = p - trail[i].xy;
            col += comboColor * exp(-dot(q, q) / (110.0 + heat * 100.0)) * trail[i].z * (0.22 + heat * 0.35);
        }
    }

    for (int i = 0; i < 36; ++i) {
        if (bricks[i].z != 0.0)
            material(col, p, bricks[i].xy, vec2(30, 10), tint(bricks[i].z), bricks[i].w, bricks[i].z < 0.0 ? 1.0 : 0.0);
    }
    material(col, p, paddle.xy, paddle.zw * 0.5, vec3(0.04, 0.8, 0.65), 0.0, 0.0);

    for (int i = 0; i < 16; ++i) {
        if (drops[i].z > 0.0) {
            vec2 q = p - drops[i].xy;
            float a = t * 2.0;
            q = mat2(cos(a), -sin(a), sin(a), cos(a)) * q;
            float d = boxSDF(q, vec2(7), 2.0);
            vec3 c = vec3(0.1, 1.0, 0.75);
            col += c * exp(-max(d, 0.0) * 0.18) * 0.32;
            col = mix(col, c * (0.35 + 0.55 * exp(-abs(d + 1.0) * 2.0)), cover(d));
            float plus = min(boxSDF(q, vec2(4, 0.8), 0.2), boxSDF(q, vec2(0.8, 4), 0.2));
            col = mix(col, vec3(1), cover(plus));
        }
    }

    for (int i = 0; i < 8; ++i) {
        if (impacts[i].w > 0.0) {
            float age = impacts[i].z;
            vec2 q = p - impacts[i].xy;
            float strength = impacts[i].w;
            float d = abs(length(q) - (3.0 + age * 90.0 * sqrt(strength)));
            float fade = max(0.0, 1.0 - age / 0.55);
            col += vec3(0.18, 0.65, 1.0) * exp(-d * 1.1) * fade * 0.7 * strength;
            float rays = pow(abs(cos(atan(q.y, q.x) * 6.0 + age * 3.0)), 14.0);
            col += vec3(1.0, 0.4, 0.16) * rays * exp(-abs(length(q) - age * 65.0) * 0.3) * fade * 0.6 * strength;
        }
    }

    vec2 b = (p - ball.xy) / ball.z;
    float bd = (length(b) - 1.0) * ball.z;
    col += comboColor * exp(-max(bd, 0.0) * 0.16) * (0.48 + heat * 0.4);
    vec3 normal = normalize(vec3(b, sqrt(max(0.001, 1.0 - dot(b, b)))));
    float lighting = max(dot(normal, normalize(vec3(-0.4, -0.6, 1))), 0.0);
    col = mix(col, vec3(0.38, 0.65, 0.9) + lighting * 0.8, cover(bd));
    if (ball.w < 0.5 && clockState.w < 0.5) {
        float ring = abs(length(p - ball.xy) - (15.0 + 3.0 * sin(t * 3.0)));
        col += vec3(0.07, 0.55, 0.8) * exp(-ring * 1.5) * 0.5;
    }

    for (int i = 0; i < 3; ++i) {
        float d = length(p - vec2(590.0 + float(i) * 16.0, 22)) - 3.0;
        col = mix(col, i < int(clockState.y) ? vec3(0.12, 0.9, 0.7) : vec3(0.06, 0.10, 0.14), cover(d));
    }

    int score = int(min(clockState.z, 99999.0));

    for (int i = 0; i < 5; ++i) {
        int n = score % 10;
        score /= 10;
        col = mix(col, vec3(0.35, 0.8, 1.0), digit(p - vec2(76.0 - float(i) * 12.0, 22), n));
    }

    // Center HUD: level on the left, multiplier on the right, timer below.
    int level = int(mod(levelState.x, 100.0));
    col = mix(col, vec3(0.3, 0.85, 0.7), digit(p - vec2(295, 22), level / 10));
    col = mix(col, vec3(0.3, 0.85, 0.7), digit(p - vec2(307, 22), level % 10));
    vec2 xp = p - vec2(332, 22);
    float cross = max(abs(xp.x) - 3.5, abs(abs(xp.y) - abs(xp.x)) - 0.7);
    col = mix(col, comboColor, cover(cross));
    col = mix(col, comboColor * (1.0 + comboState.z * 0.6), digit(p - vec2(345, 22), int(comboState.x)));
    float timerBox = boxSDF(p - vec2(320, 35), vec2(31, 1), 0.7);
    float timerFill = step(p.x, 289.0 + 62.0 * comboState.y);
    col = mix(col, mix(vec3(0.035), comboColor, timerFill), cover(timerBox));

    // Combo pulse lights the arena edges; HUD and collision positions stay stable.
    col += comboColor * exp(-wall * 0.045) * comboState.z * heat * 0.45;
    if (levelState.y > 0.0) {
        float sweep = abs(p.y - (1.0 - levelState.y) * 480.0);
        col += vec3(0.08, 0.6, 0.35) * exp(-sweep * 0.04) * sin(levelState.y * 3.14159265);
    }
    if (clockState.w > 0.5) {
        vec3 c = clockState.w > 1.5 ? vec3(0.1, 0.95, 0.5) : vec3(1.0, 0.08, 0.2);
        col += c * exp(-abs(p.y - 260.0) * 0.06) * (0.25 + 0.08 * sin(t * 3.0));
    }

    col *= max(0.5, 1.0 - dot(v, v) * 0.19);
    col *= 0.97 + 0.03 * cos(p.y * 3.14159265);
    col = vec3(1.0) - exp(-col * 1.25); // exposure and tone mapping
    fragmentColor = vec4(pow(max(col, vec3(0)), vec3(1.0 / 2.2)), 1.0);
}
