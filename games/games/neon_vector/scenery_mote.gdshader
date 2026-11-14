shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
// Streaks of light fixed in space around the route. They stream past at the rider's real
// speed, which is what sells the motion; INSTANCE_CUSTOM.x is each streak's course distance.
uniform float road_end = 480.0;
uniform float fade_start = 300.0;
uniform float rider_s = 0.0;
uniform float presence = 1.0;
uniform float pulse = 0.0;
varying float course_s;
void vertex() {
	course_s = INSTANCE_CUSTOM.x;
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float core = pow(clamp(1.0 - p.x * p.x, 0.0, 1.0), 2.0) * pow(clamp(1.0 - p.y * p.y, 0.0, 1.0), 1.5);
	// Streaks stay lit until they are behind the chase camera (12.5 m behind the rider).
	float fade = (1.0 - smoothstep(fade_start, road_end, course_s)) * smoothstep(-30.0, -18.0, course_s - rider_s);
	ALBEDO = COLOR.rgb * (1.0 + pulse * 0.8);
	ALPHA = COLOR.a * core * fade * presence;
}
