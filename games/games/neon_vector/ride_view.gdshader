shader_type canvas_item;
render_mode unshaded;
// The pass that puts the 3D ride on screen. It is the only full-screen pass besides the ride
// itself, so everything that has to touch every pixel happens here, once:
//   - the 3D view is scaled up to the window with its edges smoothed (the renderer the bike
//     uses has no usable built-in anti-aliasing: FXAA does nothing in it and MSAA costs too
//     much there), so diagonal edges and thin lights stop looking stepped;
//   - an optional soft bloom, read from a small blurred copy of the picture;
//   - the grade (contrast and saturation), a vignette, a red edge pulse when the rider is
//     hit, and on the high tier a little colour fringing that grows with speed.
uniform float vignette = 0.5;
uniform float danger = 0.0;      // 0..1, decays after a hit
uniform float speed = 0.0;       // 0..1 of the game's top speed
uniform float beat = 0.0;        // 0..1 music kick envelope
uniform float aberration = 0.0;  // 0 skips the two extra samples entirely
uniform float smoothing = 1.0;   // 0 reads the view once, as it is
uniform sampler2D bloom_tex : filter_linear, repeat_disable;
uniform float bloom = 0.0;       // 0 skips the bloom read
uniform vec2 grade = vec2(1.0, 1.0);  // contrast, saturation; (1, 1) leaves the picture alone

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = dot(p, p);
	vec3 color = texture(TEXTURE, UV).rgb;
	if (smoothing > 0.5) {
		// Edge smoothing in the style of FXAA: where the four diagonal neighbours differ enough
		// to be an edge, the pixel is blended along that edge; everywhere else it stays sharp.
		// (Written out here: the view's texture cannot be handed to a function.)
		vec2 px = TEXTURE_PIXEL_SIZE;
		float nw = luma(texture(TEXTURE, UV + vec2(-0.5, -0.5) * px).rgb);
		float ne = luma(texture(TEXTURE, UV + vec2(0.5, -0.5) * px).rgb);
		float sw = luma(texture(TEXTURE, UV + vec2(-0.5, 0.5) * px).rgb);
		float se = luma(texture(TEXTURE, UV + vec2(0.5, 0.5) * px).rgb);
		float m = luma(color);
		float low = min(m, min(min(nw, ne), min(sw, se)));
		float high = max(m, max(max(nw, ne), max(sw, se)));
		if (high - low >= max(0.035, high * 0.11)) {
			vec2 dir = vec2(-((nw + ne) - (sw + se)), (nw + sw) - (ne + se));
			float reduce = max((nw + ne + sw + se) * 0.03125, 0.0078125);
			dir = clamp(dir / (min(abs(dir.x), abs(dir.y)) + reduce), vec2(-6.0), vec2(6.0)) * px;
			vec3 along = 0.5 * (texture(TEXTURE, UV + dir * (1.0 / 3.0 - 0.5)).rgb + texture(TEXTURE, UV + dir * (2.0 / 3.0 - 0.5)).rgb);
			float blended = luma(along);
			if (blended >= low && blended <= high) {
				color = along;
			}
		}
	}
	if (aberration > 0.0) {
		vec2 shift = p * edge * aberration * (0.0014 + speed * 0.0020);
		color = vec3(texture(TEXTURE, UV + shift).r, color.g, texture(TEXTURE, UV - shift).b);
	}
	if (bloom > 0.0) {
		color += texture(bloom_tex, UV).rgb * bloom;
	}
	if (grade != vec2(1.0, 1.0)) {
		color = mix(vec3(luma(color)), color, grade.y);
		color = (color - 0.5) * grade.x + 0.5;
	}
	color *= 1.0 - vignette * smoothstep(0.35, 1.9, edge) * (1.0 - beat * 0.3);
	color += vec3(1.0, 0.10, 0.18) * danger * smoothstep(0.45, 1.9, edge) * 0.8;
	COLOR = vec4(clamp(color, 0.0, 1.0), 1.0);
}
