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
varying float course_s;

void vertex() {
	course_s = UV.x;
}

void fragment() {
	float fade = 1.0 - smoothstep(fade_start, road_end, course_s);
	float rise = pow(1.0 - UV.y, 2.6);
	float weave = 0.72 + 0.28 * sin(course_s * 0.55 - flow * 0.12);
	ALBEDO = accent;
	ALPHA = fade * rise * weave * (0.16 + pulse * 0.2) * strength;
}
