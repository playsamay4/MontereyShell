shader_type canvas_item;


uniform samplerExternalOES android_video_texture : filter_linear, repeat_disable;
uniform sampler2D editor_fallback_texture : hint_default_black, filter_linear, repeat_disable;
uniform bool is_android = false;

void fragment() {
    if (is_android) {
        COLOR = vec4(texture(android_video_texture, UV).rgb, 1.0);
    } else {
        COLOR = vec4(texture(editor_fallback_texture, UV).rgb, 1.0);
    }
}