shader_type canvas_item; uniform sampler2D t: hint_screen_texture, filter_linear_mipmap;
void fragment(){COLOR = vec4(textureLod(t, SCREEN_UV, 4.0).rgb, .33);}
//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
