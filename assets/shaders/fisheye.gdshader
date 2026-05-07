shader_type canvas_item;

uniform float distortion : hint_range(-1.0, 1.0) = 0.3;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 center = vec2(0.5, 0.5);
    vec2 delta = uv - center;
    float distance = length(delta);
    
    // Simulasikan efek mencebung (convex/fish-eye)
    if (distortion != 0.0) {
        // Semakin jauh dari tengah, semakin ditarik ke dalam
        float factor = 1.0 + distortion * distance * distance;
        uv = center + delta * factor;
    }
    
    // Pastikan UV tetap dalam rentang 0-1
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        COLOR = vec4(0.0, 0.0, 0.0, 1.0); // Border hitam jika di luar jangkauan
    } else {
        COLOR = texture(screen_texture, uv);
    }
}
