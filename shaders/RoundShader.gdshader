shader_type canvas_item;

// Changed to a normalized ratio (0.0 = sharp, 0.5 = perfect circle if square)
uniform float corner_radius : hint_range(0.0, 0.5) = 0.1;

void fragment() {
    // Center-align the coordinate map from [-0.5, -0.5] to [0.5, 0.5]
    vec2 uv = UV - 0.5;
    
    // Account for aspect ratios to keep corners perfectly circular
    // (Crucial if your TextureRect happens to stretch or squash)
    vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
    float aspect = size.x / size.y;
    if (aspect > 1.0) {
        uv.x *= aspect;
    } else {
        uv.y /= aspect;
    }
    
    // Absolute bounds calculation using normalized limits
    vec2 max_bounds = vec2(0.5 * max(aspect, 1.0), 0.5 * max(1.0 / aspect, 1.0));
    vec2 q = abs(uv) - max_bounds + vec2(corner_radius);
    float dist = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner_radius;
    
    // Sample texture and clip alpha
    vec4 tex_color = texture(TEXTURE, UV);
    tex_color.a *= 1.0 - smoothstep(-0.01, 0.01, dist);
    
    COLOR = tex_color;
}