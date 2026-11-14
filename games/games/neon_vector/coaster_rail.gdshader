shader_type spatial;
render_mode world_vertex_coords, cull_disabled, blend_mix, depth_draw_always;
// Edge rails: a dark alloy section with inset running lights. UV.x is course distance,
// UV.y runs across each ribbon; COLOR.r marks the inner face, COLOR.g the top face.
uniform float road_end = 480.0;
uniform float fade_start = 300.0;
uniform vec3 accent : source_color = vec3(0.35, 0.8, 1.0);
uniform vec3 second : source_color = vec3(0.6, 0.4, 1.0);
uniform float flow = 0.0;
uniform float pulse = 0.0;
uniform vec4 music = vec4(0.0);  // eased bass, mids, treble, kick
uniform vec4 seams = vec4(0.0);
uniform float wave_front[6];     // the road's music pulses: the rails carry the tail of each chevron
uniform float wave_gain[6];
varying float course_s;

void vertex() {
	course_s = UV.x;
}

void fragment() {
	float fade = 1.0 - smoothstep(fade_start, road_end, course_s);
	if (fade < 0.001) { discard; }
	float v = UV.y;
	float inner = COLOR.r * smoothstep(0.42, 0.52, v) * (1.0 - smoothstep(0.84, 0.94, v));
	float top = COLOR.g * (1.0 - smoothstep(0.26, 0.38, v));
	float px_s = fwidth(course_s);
	// Segmented light bars, resolved into a continuous line once they are under a pixel.
	// Eight-metre bars: long enough not to strobe at the top speed at 30 fps (see the deck).
	float gap = smoothstep(0.46, 0.48, abs(fract(course_s / 8.0) - 0.5));
	float segments = mix(1.0 - gap * 0.85, 0.62, smoothstep(0.3, 1.2, px_s));
	float packet = 0.0;
	for (int i = 0; i < 6; i++) {
		float behind = wave_front[i] - 24.5 - course_s;
		packet += wave_gain[i] * smoothstep(0.0, 1.4, behind) * exp(-max(behind, 0.0) * 0.10);
	}
	// The running lights take the treble's colour; the cap takes the mids'.
	vec3 lights = mix(accent, second, clamp(music.z * 0.9, 0.0, 0.8));
	vec3 cap = mix(accent, second, clamp(music.y * 0.7, 0.0, 0.7));
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = vec3(0.020, 0.026, 0.045) + accent * 0.03;
	METALLIC = 0.85;
	ROUGHNESS = 0.32;
	EMISSION = lights * inner * segments * (1.4 + pulse * 1.3 + music.z * 0.8) + cap * top * (0.85 + pulse * 0.6 + music.y * 0.5)
		+ mix(lights, vec3(1.0), 0.6) * packet * (inner + top) * 2.6
		+ second * pow(1.0 - facing, 3.0) * 0.22;
	ALPHA = fade;
}
