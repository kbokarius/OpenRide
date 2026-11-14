shader_type spatial;
render_mode world_vertex_coords, unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
// A low curtain of light rising from each rail. UV.x is course distance, UV.y is 0 at the
// rail and 1 at the top of the curtain.
uniform float road_end = 480.0;
uniform float fade_start = 300.0;
uniform vec3 accent : source_color = vec3(0.35, 0.8, 1.0);
uniform float flow = 0.0;
uniform float pulse = 0.0;
uniform float strength = 1.0;
uniform vec3 second : source_color = vec3(0.6, 0.4, 1.0);
uniform vec4 music = vec4(0.0);  // eased bass, mids, treble, kick
uniform vec4 seams = vec4(0.0);
uniform float wave_front[6];
uniform float wave_gain[6];
varying float course_s;

void vertex() {
	course_s = UV.x;
}

void fragment() {
	float fade = 1.0 - smoothstep(fade_start, road_end, course_s);
	float rise = pow(1.0 - UV.y, 2.6);
	float weave = 0.72 + 0.28 * sin(course_s * 0.55 - flow * 0.12);
	// The curtain rises with the bass and leans toward the second colour with the mids.
	ALBEDO = mix(accent, second, clamp(music.y * 0.8, 0.0, 0.75));
	ALPHA = fade * rise * weave * (0.15 + pulse * 0.2 + music.x * 0.12) * strength;
}
