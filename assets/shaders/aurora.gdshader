shader_type spatial;
render_mode blend_add, cull_disabled, depth_draw_never, unshaded;

uniform float speed    : hint_range(0.0, 1.0) = 0.12;
uniform float intensity: hint_range(0.0, 1.0) = 0.55;

void fragment() {
    vec2 uv = UV;
    float t  = TIME * speed;

    // Band 1 — hijau/teal
    float c1   = 0.55 + sin(t * 0.40) * 0.12;
    float w1   = sin(uv.x * 5.0 + t * 1.2) * 0.08 + sin(uv.x * 2.5 - t * 0.7) * 0.06;
    float b1   = smoothstep(0.18, 0.0, abs(uv.y - c1 - w1));

    // Band 2 — ungu/violet
    float c2   = 0.38 + sin(t * 0.30 + 2.0) * 0.10;
    float w2   = sin(uv.x * 4.0 - t * 0.9) * 0.07 + sin(uv.x * 7.0 + t * 0.5) * 0.04;
    float b2   = smoothstep(0.14, 0.0, abs(uv.y - c2 - w2));

    // Band 3 — cyan
    float c3   = 0.65 + sin(t * 0.50 + 1.0) * 0.08;
    float w3   = sin(uv.x * 6.0 + t * 0.8 + 1.5) * 0.06;
    float b3   = smoothstep(0.10, 0.0, abs(uv.y - c3 - w3));

    float aurora = clamp(b1 + b2 * 0.7 + b3 * 0.5, 0.0, 1.0);

    // Warna aurora
    vec3 green_teal = vec3(0.0,  0.95, 0.55);
    vec3 purple     = vec3(0.45, 0.15, 0.95);
    vec3 cyan       = vec3(0.0,  0.85, 0.95);

    float mx1 = sin(uv.x * 3.14 + t * 0.3) * 0.5 + 0.5;
    float mx2 = sin(uv.x * 6.28 - t * 0.2 + 1.0) * 0.5 + 0.5;

    vec3 col = mix(green_teal, purple, mx1);
    col = mix(col, cyan, mx2 * b3);
    col = mix(col, purple * 1.2, b2 * 0.6);

    // Fade di tepi supaya tidak kelihatan batas mesh
    float fy = smoothstep(0.0, 0.15, uv.y) * smoothstep(1.0, 0.85, uv.y);
    float fx = smoothstep(0.0, 0.06, uv.x) * smoothstep(1.0, 0.94, uv.x);

    ALBEDO = col;
    ALPHA  = aurora * fy * fx * intensity;
}
