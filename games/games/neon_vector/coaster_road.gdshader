shader_type spatial;
render_mode world_vertex_coords, cull_disabled, specular_disabled, blend_mix, depth_draw_always;
// The deck. Immutable world geometry: UV.x is course distance in metres, UV.y lateral metres.
// Every feature is computed from those two coordinates, so nothing slides on the surface
// except the pulses of light, which run ahead along the seams on purpose: one leaves the
// bike on every kick of the music, as a chevron with the centre seam leading. Each seam's
// steady glow and colour follow one part of the spectrum (bass on the centre seam, treble on
// the edges), and the deck takes a faint wash of the same colour. All of it is eased.
uniform float opacity : hint_range(0.0, 1.0) = 0.74;
uniform float glow = 1.0;
uniform float lane_width = 4.2;
uniform float target_weights[6];  // crossfaded by the HUD; no moving overlay geometry
uniform float edge_weights[5];   // inner lane-line proximity, no outer-edge warning
uniform float rider_s = 0.0;
uniform float road_end = 480.0;
uniform float fade_start = 300.0;
uniform vec3 accent : source_color = vec3(0.35, 0.8, 1.0);
uniform vec3 second : source_color = vec3(0.6, 0.4, 1.0);
uniform float flow = 0.0;   // unused by the deck now; kept so the three road shaders share inputs
uniform float pulse = 0.0;  // 0..1 music beat envelope
uniform vec4 music = vec4(0.0);  // eased bass, mids, treble, kick
uniform vec4 seams = vec4(0.0);  // eased level per seam from the centre out: bass, low mids, high mids, treble
uniform float wave_front[4];     // world metres along the route of each pulse's head
uniform float wave_gain[4];      // 0..1 brightness of each pulse
varying float course_s;
varying float lateral;

void vertex() {
	course_s = UV.x;
	lateral = UV.y;
}

void fragment() {
	float fade = 1.0 - smoothstep(fade_start, road_end, course_s);
	if (fade < 0.001) { discard; }
	float lane = lateral / lane_width;
	float seam_m = abs(fract(lane + 0.5) - 0.5) * lane_width;
	float px = fwidth(lateral);
	float px_s = fwidth(course_s);
	// Seams keep at least a pixel of width, dimming instead of shimmering when far away.
	float half_width = max(0.035, px * 0.7);
	float seam = (1.0 - smoothstep(half_width - px, half_width + px, seam_m)) * min(1.0, 0.035 / half_width + 0.35);
	float halo = exp(-seam_m * 3.6);
	// Ruler ticks across each seam every six metres give the near road its sense of speed.
	// Six, not three: at the top speed the bike covers 1.6 m a frame at 30 fps, and a pattern
	// must repeat over more than twice that or it appears to stand still or run backwards.
	float tick_s = abs(fract(course_s / 6.0 + 0.5) - 0.5) * 6.0;
	float tick = (1.0 - smoothstep(0.03, 0.03 + px_s * 1.5, tick_s)) * (1.0 - smoothstep(0.26, 0.34, seam_m)) * (1.0 - smoothstep(0.1, 0.45, px_s));
	// Pulses run ahead along every seam; the centre seam leads, so each one reads as a chevron.
	float seam_id = abs(floor(lane + 0.5));
	float level = seam_id < 0.5 ? seams.x : (seam_id < 1.5 ? seams.y : (seam_id < 2.5 ? seams.z : seams.w));
	float packet = 0.0;
	float ripple = 0.0;
	for (int i = 0; i < 4; i++) {
		float behind = wave_front[i] - seam_id * 7.0 - course_s;
		packet += wave_gain[i] * smoothstep(0.0, 1.4, behind) * exp(-max(behind, 0.0) * 0.12);
		float across = wave_front[i] - abs(lateral) * (7.0 / lane_width) - course_s;
		ripple += wave_gain[i] * smoothstep(0.0, 1.0, across) * exp(-max(across, 0.0) * 0.45);
	}
	packet *= halo;
	float edge_m = 3.0 * lane_width - abs(lateral);
	float border = 1.0 - smoothstep(0.0, 0.5, edge_m);
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float sheen = pow(1.0 - facing, 3.0);
	float stripe = mod(floor(lane + 3.0), 2.0);
	vec3 deck = vec3(0.007, 0.010, 0.022) + accent * (0.016 + stripe * 0.012);
	int target_index = int(clamp(floor(lane + 3.0), 0.0, 5.0));
	float guide = target_weights[target_index] * smoothstep(0.015, 0.14, seam_m);
	float guide_edge = exp(-pow((seam_m - 0.18) * 9.0, 2.0));
	vec3 guide_color = vec3(0.58, 0.79, 1.0);
	ALBEDO = deck;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	float beat = 1.0 + pulse * 0.9;
	// The seam's colour slides from the accent to the second colour as its band fills.
	vec3 line = mix(accent, second, clamp(level * 0.85, 0.0, 0.8));
	float nearest_seam = floor(lane + 0.5);
	float edge_warning = abs(nearest_seam) <= 2.0 ? edge_weights[int(clamp(nearest_seam + 2.0, 0.0, 4.0))] : 0.0;
	// A quiet rose tint beside and just ahead of the rider; fixed to the actual lane line.
	edge_warning *= smoothstep(rider_s - 18.0, rider_s - 4.0, course_s) * (1.0 - smoothstep(rider_s + 18.0, rider_s + 65.0, course_s));
	line = mix(line, vec3(0.66, 0.25, 0.29), edge_warning * 0.92);
	vec3 wash = mix(accent, second, clamp(music.y + music.z * 0.5, 0.0, 1.0));
	EMISSION = (line * (seam * (1.5 + level * 1.5) * beat + halo * (0.09 + level * 0.14) * beat)
		+ accent * (tick * 0.5 + border * (0.25 + music.z * 0.35))
		+ mix(line, vec3(1.0), 0.5) * packet * 2.6
		+ wash * (ripple * 0.10 + music.x * 0.022 * (0.6 + stripe))
		+ second * sheen * 0.16) * glow
		+ guide_color * guide * (0.13 + guide_edge * 0.72);
	ALPHA = clamp(mix(opacity, 0.96, max(max(seam, sheen * 0.55), guide * 0.55)) * fade, 0.0, 1.0);
}
