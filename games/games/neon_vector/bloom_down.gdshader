shader_type canvas_item;
render_mode unshaded, blend_disabled;
// First step of the ride's light bloom on the bike's tier: the 3D view shrunk to a quarter
// of its width and height, keeping only what is bright. Four reads cover every pixel of the
// view, so a thin bright line cannot fall between them and flicker.
uniform sampler2D source : filter_linear, repeat_disable;
uniform vec2 source_pixel = vec2(0.001, 0.001);  // one pixel of the 3D view, in UV
// Brightness is judged on luminance, not the strongest channel: the lit seams, lamps and
// markers are near white by the time they reach the screen, while the sky's ribbons are
// saturated colour of middling luminance and must not bloom.
uniform float threshold = 0.58;
uniform float knee = 0.3;

vec3 bright(vec3 c) {
	return c * smoothstep(threshold, threshold + knee, dot(c, vec3(0.299, 0.587, 0.114)));
}

void fragment() {
	vec3 sum = bright(texture(source, UV + vec2(-1.0, -1.0) * source_pixel).rgb)
		+ bright(texture(source, UV + vec2(1.0, -1.0) * source_pixel).rgb)
		+ bright(texture(source, UV + vec2(-1.0, 1.0) * source_pixel).rgb)
		+ bright(texture(source, UV + vec2(1.0, 1.0) * source_pixel).rgb);
	COLOR = vec4(sum * 0.25, 1.0);
}
