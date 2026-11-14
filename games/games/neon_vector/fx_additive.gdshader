shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
// Additive light for sparks, flashes and glows. UV-centred soft falloff: a quad reads as a
// round glow, a stretched quad as a streak. Meshes without useful UVs set `soft` to zero.
uniform float energy = 1.0;
uniform float soft = 1.0;
uniform vec3 tint : source_color = vec3(1.0);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float falloff = mix(1.0, pow(clamp(1.0 - dot(p, p), 0.0, 1.0), 1.6), soft);
	ALBEDO = COLOR.rgb * tint * energy;
	ALPHA = COLOR.a * falloff;
}
