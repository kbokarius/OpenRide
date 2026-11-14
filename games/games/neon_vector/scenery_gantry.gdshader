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
uniform float rider_s = 0.0;
uniform vec2 appear = vec2(120.0, 160.0);  // road metres ahead over which a new arch fades in
uniform float pulse = 0.0;
uniform vec4 music = vec4(0.0);  // eased bass, mids, treble, kick
varying float course_s;
varying float band;  // which part of the spectrum this arch follows: 0 bass, 1 mids, 2 treble
void vertex() {
	course_s = INSTANCE_CUSTOM.x;
	band = INSTANCE_CUSTOM.y;
}
void fragment() {
	float fade = (1.0 - smoothstep(fade_start, road_end - 5.0, course_s)) * presence
		* (1.0 - smoothstep(appear.x, appear.y, course_s - rider_s));
	if (fade < 0.004) { discard; }
	// Each arch's light strip swells and changes colour with its own band of the music.
	float level = band < 0.5 ? music.x : (band < 1.5 ? music.y : music.z);
	vec3 strip = mix(accent, rim_color, clamp(level * 0.9, 0.0, 0.8));
	vec3 paint = mix(COLOR.rgb, strip, UV.x);
	ALBEDO = ls_shade(paint, 0.7, UV.y, normalize(NORMAL), normalize(VIEW), rim_color, 2.0 + pulse * 1.4 + level * 1.6);
	ALPHA = fade;
}
