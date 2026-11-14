shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float progress = 0.0;
uniform float visibility = 1.0;
uniform float detonation = 0.0;
void fragment() {
	vec2 edge = min(UV, vec2(1.0) - UV);
	float border = 1.0 - smoothstep(0.018, 0.038, min(edge.x, edge.y));
	float stripes = smoothstep(0.68, 0.78, fract(UV.x * 13.0 + UV.y * 9.0 - progress * 2.0));
	float cross = (1.0 - smoothstep(0.005, 0.011, abs(UV.x - 0.5))) + (1.0 - smoothstep(0.012, 0.025, abs(UV.y - 0.5)));
	float countdown = 1.0 - smoothstep(0.015, 0.05, abs(abs(UV.y - 0.5) * 2.0 - (1.0 - progress)));
	float pulse = 0.85 + 0.15 * sin(progress * 35.0);
	vec3 tint = mix(vec3(1.0, 0.49, 0.23), vec3(1.0, 0.13, 0.24), progress);
	ALBEDO = mix(tint, vec3(0.72, 1.0, 0.95), detonation);
	ALPHA = visibility * clamp(0.11 + stripes * 0.10 + border * 0.68 + cross * 0.32 + countdown * 0.30 + detonation * 0.55, 0.0, 0.9) * pulse;
}
