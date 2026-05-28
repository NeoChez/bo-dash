shader_type canvas_item;

uniform vec4 color1 : source_color = vec4(0.2, 0.65, 0.95, 1.0); // Bright cyan/blue
uniform vec4 color2 : source_color = vec4(0.1, 0.5, 0.85, 1.0);  // Deep azure
uniform float divisions : hint_range(1.0, 50.0) = 15.0;
uniform float speed : hint_range(-10.0, 10.0) = 0.4;
uniform float angle : hint_range(-360.0, 360.0) = 45.0;

void fragment() {
    float rad = radians(angle);
    vec2 uv = UV;
    
    // Rotate UV to achieve diagonal lines
    vec2 rotated_uv = vec2(
        uv.x * cos(rad) - uv.y * sin(rad),
        uv.x * sin(rad) + uv.y * cos(rad)
    );
    
    // Create stripe pattern
    float val = fract(rotated_uv.x * divisions - TIME * speed);
    float stripe = step(0.5, val);
    vec4 base = mix(color1, color2, stripe);
    
    // Smooth radial vignette (brighter in center, darker at edges)
    float dist = distance(uv, vec2(0.5, 0.5));
    float vignette = smoothstep(0.8, 0.15, dist);
    
    // Composite color
    COLOR = base * mix(0.7, 1.15, vignette);
}
