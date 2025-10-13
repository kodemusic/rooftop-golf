shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 0.0, 0.5);
uniform float glow_strength : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    vec4 texture_color = texture(TEXTURE, UV);
    vec3 final_color = texture_color.rgb + glow_color.rgb * glow_strength;
    COLOR = vec4(final_color, texture_color.a);
}