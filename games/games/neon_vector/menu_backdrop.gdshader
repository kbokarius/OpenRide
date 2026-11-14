shader_type canvas_item;
render_mode unshaded;
// The selector's backdrop: the selected track's own sky, held far back and dark so the menu
// reads on top of it. It drifts slowly and moves with the music like the ride does.
#include "res://games/neon_vector/psychedelic_tunnel.gdshaderinc"
uniform vec3 primary : source_color = vec3(0.25, 0.6, 0.9);
uniform vec3 secondary : source_color = vec3(0.65, 0.25, 0.9);
uniform int style = 0;
uniform float travel = 0.0;
uniform float aspect = 1.78;
uniform float strength = 0.34;
uniform vec4 music = vec4(0.0);
uniform float swirl = 0.0;
void fragment() {
	vec2 p = (UV - vec2(0.5, 0.46)) * vec2(aspect, 1.0) * 1.5;
	vec3 scene = tunnel_field(normalize(vec3(p, -1.0)), travel, style, primary, secondary, 0.55, music, swirl);
	vec2 q = UV * 2.0 - 1.0;
	float edge = dot(q, q);
	vec3 base = mix(vec3(0.020, 0.034, 0.064), vec3(0.008, 0.012, 0.026), smoothstep(0.0, 1.7, edge));
	COLOR = vec4(base + scene * strength * (1.0 - 0.5 * smoothstep(0.2, 1.9, edge)), 1.0);
}
