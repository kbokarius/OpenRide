shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;
// Self-lit pooled geometry (shards, markers, rings). The instance colour carries tint and fade;
// a view-facing rim keeps solid shapes readable as 3D without any scene light.
uniform float energy = 1.0;
uniform float rim = 0.55;
void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = pow(1.0 - facing, 2.0);
	ALBEDO = COLOR.rgb * energy * (0.62 + 0.38 * facing) + mix(COLOR.rgb, vec3(1.0), 0.6) * edge * rim * energy;
	ALPHA = COLOR.a;
}
