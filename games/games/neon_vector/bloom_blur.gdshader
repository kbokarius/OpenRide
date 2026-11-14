shader_type canvas_item;
render_mode unshaded, blend_disabled;
// The bloom's blur, in one pass: nine reads in a ring around each pixel, each of them the
// texture filter's average of four, weighted like a Gaussian. One pass rather than the usual
// two (across, then down) because on the bike every extra off-screen view costs CPU time.
uniform sampler2D source : filter_linear, repeat_disable;
uniform vec2 step_uv = vec2(0.001, 0.001);  // how far apart the reads are, in UV

void fragment() {
	vec3 sum = texture(source, UV).rgb * 0.20;
	sum += (texture(source, UV + vec2(step_uv.x, 0.0)).rgb + texture(source, UV - vec2(step_uv.x, 0.0)).rgb
		+ texture(source, UV + vec2(0.0, step_uv.y)).rgb + texture(source, UV - vec2(0.0, step_uv.y)).rgb) * 0.125;
	sum += (texture(source, UV + step_uv).rgb + texture(source, UV - step_uv).rgb
		+ texture(source, UV + vec2(step_uv.x, -step_uv.y)).rgb + texture(source, UV + vec2(-step_uv.x, step_uv.y)).rgb) * 0.075;
	COLOR = vec4(sum, 1.0);
}
