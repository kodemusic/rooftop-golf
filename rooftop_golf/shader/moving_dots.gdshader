shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	vec2 moving_uv = vec2(UV.x-(TIME), UV.y);
	vec4 in_tex = texture(TEXTURE, moving_uv);

	// Apply COLOR (which includes modulate, self_modulate, and gradient)
	COLOR = in_tex * COLOR;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
