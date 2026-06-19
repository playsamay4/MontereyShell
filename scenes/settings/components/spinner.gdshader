shader_type canvas_item;

void fragment() {
    // Adjust 5.0 to change the rotation speed
    float angle = -TIME * 5.0; 
    
    // Rotate the UV coordinates around the center (0.5, 0.5)
    vec2 uv = UV - 0.5;
    float s = sin(angle);
    float c = cos(angle);
    vec2 rotated_uv = vec2(uv.x * c - uv.y * s, uv.x * s + uv.y * c) + 0.5;
    
    COLOR = texture(TEXTURE, rotated_uv);
}