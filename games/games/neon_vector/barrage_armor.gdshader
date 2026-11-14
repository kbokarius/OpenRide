shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, fog_disabled;
uniform float visibility = 1.0;
uniform float phase = 0.0;
uniform float luminous = 0.0;
uniform vec3 energy_color : source_color = vec3(0.31, 0.94, 0.86);
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
	float rim = pow(1.0 - max(0.0, dot(normalize(NORMAL), normalize(VIEW))), 3.0);
	float scan = 0.5 + 0.5 * sin(local_position.y * 56.0 - phase * 7.0);
	float arrival = 1.0 - visibility;
	ALBEDO = COLOR.rgb * 0.7;
	METALLIC = 0.35;
	ROUGHNESS = mix(0.34, 0.17, luminous);
	EMISSION = COLOR.rgb * luminous * 1.0 + energy_color * (rim * 0.12 + arrival * scan * 0.8);
	ALPHA = visibility * mix(1.0, 0.5 + 0.5 * scan, arrival);
}
