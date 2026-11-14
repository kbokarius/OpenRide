shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_always, cull_disabled, fog_disabled;
// Track gantries: hand-lit alloy arches with inset light strips. Each instance carries its
// course distance in INSTANCE_CUSTOM.x so it dissolves with the road instead of popping.
#include "res://games/neon_vector/ls_light.gdshaderinc"
uniform vec3 accent : source_color = vec3(0.35, 0.8, 1.0);
uniform vec3 rim_color : source_color = vec3(0.6, 0.45, 1.0);
uniform float road_end = 480.0;
uniform float fade_start = 300.0;
uniform float presence = 1.0;  // dims the scenery while attackers hold the stage
uniform float pulse = 0.0;
varying float course_s;
void vertex() {
	course_s = INSTANCE_CUSTOM.x;
}
void fragment() {
	float fade = (1.0 - smoothstep(fade_start, road_end - 14.0, course_s)) * presence;
	if (fade < 0.004) { discard; }
	vec3 paint = mix(COLOR.rgb, accent, UV.x);
	ALBEDO = ls_shade(paint, 0.7, UV.y, normalize(NORMAL), normalize(VIEW), rim_color, 2.2 + pulse * 1.6);
	ALPHA = fade;
}
