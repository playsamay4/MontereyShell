shader_type canvas_item;

uniform float corner_radius : hint_range(0.0, 100.0) = 20.0;

void fragment() {
    // Get the exact pixel dimensions of the texture
    vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
    vec2 pixel_pos = UV * size;
    vec2 half_size = size * 0.5;
    
    // Calculate distance from the corners
    vec2 q = abs(pixel_pos - half_size) - half_size + vec2(corner_radius);
    float dist = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner_radius;
    
    // Draw the texture, but smoothly erase the alpha outside the radius
    vec4 tex_color = texture(TEXTURE, UV);
    tex_color.a *= 1.0 - smoothstep(-0.5, 0.5, dist);
    COLOR = tex_color;
}