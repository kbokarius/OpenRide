shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec4 tint : source_color = vec4(0.35, 1.0, 0.82, 1.0);
uniform float phase = 0.0;
void fragment() {
	float facing = max(0.0, dot(normalize(NORMAL), normalize(VIEW)));
	float core = pow(facing, 3.0);
	float rim = pow(1.0 - facing, 2.0);
	float bands = 0.5 + 0.5 * sin(UV.y * 48.0 + phase * 8.0 + sin(UV.x * 30.0));
	ALBEDO = mix(tint.rgb, vec3(0.87, 1.0, 0.98), core);
	ALPHA = tint.a * (core * 0.9 + rim * 0.25 + bands * 0.12) * COLOR.a;
}
