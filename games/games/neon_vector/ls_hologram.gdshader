shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, fog_disabled;
// The best-ride ghost: a projected light figure. Edges glow, the body stays see-through, and
// fine scan lines drift up it. Additive, so it never hides the road or a target.
uniform vec3 tint : source_color = vec3(0.55, 0.75, 1.0);
uniform float visibility = 1.0;
uniform float phase = 0.0;
varying vec3 local_position;
void vertex() {
	local_position = VERTEX;
}
void fragment() {
	float facing = max(dot(normalize(NORMAL), normalize(VIEW)), 0.0);
	float rim = pow(1.0 - facing, 2.2);
	float scan = 0.72 + 0.28 * sin(local_position.y * 38.0 - phase * 5.0);
	ALBEDO = tint * (0.16 + rim * 1.5 + UV.y * 0.9) * scan;
	ALPHA = visibility;
}
