shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
// A shockwave drawn on a flat card: a bright leading band with a faint wake inside it.
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float band = exp(-pow((r - 0.84) / 0.075, 2.0));
	float wake = (1.0 - smoothstep(0.1, 0.84, r)) * 0.10;
	ALBEDO = COLOR.rgb * 2.2;
	ALPHA = COLOR.a * (band + wake) * step(r, 1.0);
}
