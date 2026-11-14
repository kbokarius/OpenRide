shader_type canvas_item;
render_mode unshaded;
// The pass that puts the 3D ride on screen. It is the only full-screen pass besides the ride
// itself, so the lens work happens here instead of in extra post passes: a vignette, a red
// edge pulse when the rider is hit, and (on the high tier only) a little colour fringing that
// grows with speed.
uniform float vignette = 0.5;
uniform float danger = 0.0;      // 0..1, decays after a hit
uniform float speed = 0.0;       // 0..1 of the game's top speed
uniform float beat = 0.0;        // 0..1 music kick envelope
uniform float aberration = 0.0;  // 0 skips the two extra samples entirely
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = dot(p, p);
	vec3 color;
	if (aberration > 0.0) {
		vec2 shift = p * edge * aberration * (0.0014 + speed * 0.0020);
		color = vec3(texture(TEXTURE, UV + shift).r, texture(TEXTURE, UV).g, texture(TEXTURE, UV - shift).b);
	} else {
		color = texture(TEXTURE, UV).rgb;
	}
	color *= 1.0 - vignette * smoothstep(0.35, 1.9, edge) * (1.0 - beat * 0.3);
	color += vec3(1.0, 0.10, 0.18) * danger * smoothstep(0.45, 1.9, edge) * 0.8;
	COLOR = vec4(color, 1.0);
}
