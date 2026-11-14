shader_type spatial;
render_mode world_vertex_coords, cull_disabled, specular_disabled, blend_mix, depth_draw_always;
// The deck. Immutable world geometry: UV.x is course distance in metres, UV.y lateral metres.
// Every feature is computed from those two coordinates, so nothing slides on the surface
// except the energy packets, which travel along the seams on purpose.
uniform float opacity : hint_range(0.0, 1.0) = 0.74;
uniform float glow = 1.0;
uniform float road_end = 480.0;
uniform float fade_start = 300.0;
uniform vec3 accent : source_color = vec3(0.35, 0.8, 1.0);
uniform vec3 second : source_color = vec3(0.6, 0.4, 1.0);
uniform float flow = 0.0;   // metres travelled by the seam packets
uniform float pulse = 0.0;  // 0..1 music beat envelope
varying float course_s;
varying float lateral;

void vertex() {
	course_s = UV.x;
	lateral = UV.y;
}

void fragment() {
	float fade = 1.0 - smoothstep(fade_start, road_end, course_s);
	if (fade < 0.001) { discard; }
	float lane = lateral / 3.0;
	float seam_m = abs(fract(lane + 0.5) - 0.5) * 3.0;
	float px = fwidth(lateral);
	float px_s = fwidth(course_s);
	// Seams keep at least a pixel of width, dimming instead of shimmering when far away.
	float half_width = max(0.035, px * 0.7);
	float seam = (1.0 - smoothstep(half_width - px, half_width + px, seam_m)) * min(1.0, 0.035 / half_width + 0.35);
	float halo = exp(-seam_m * 3.6);
	// Ruler ticks across each seam every three metres give the near road its sense of speed.
	float tick_s = abs(fract(course_s / 3.0 + 0.5) - 0.5) * 3.0;
	float tick = (1.0 - smoothstep(0.03, 0.03 + px_s * 1.5, tick_s)) * (1.0 - smoothstep(0.26, 0.34, seam_m)) * (1.0 - smoothstep(0.1, 0.45, px_s));
	// Packets of light run ahead along every seam; each seam carries its own phase.
	float seam_id = floor(lane + 0.5);
	float run = fract((course_s - flow) / 72.0 + seam_id * 0.31);
	float packet = smoothstep(0.0, 0.012, run) * exp(-run * 26.0) * halo;
	float edge_m = 9.0 - abs(lateral);
	float border = 1.0 - smoothstep(0.0, 0.5, edge_m);
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float sheen = pow(1.0 - facing, 3.0);
	float stripe = mod(floor(lane + 3.0), 2.0);
	vec3 deck = vec3(0.007, 0.010, 0.022) + accent * (0.016 + stripe * 0.012);
	ALBEDO = deck;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	float beat = 1.0 + pulse * 0.9;
	EMISSION = (accent * (seam * 1.9 * beat + halo * 0.11 * beat + tick * 0.5 + border * 0.25)
		+ mix(accent, vec3(1.0), 0.55) * packet * (2.2 + pulse * 2.0)
		+ second * sheen * 0.16) * glow;
	ALPHA = clamp(mix(opacity, 0.96, max(seam, sheen * 0.55)) * fade, 0.0, 1.0);
}
