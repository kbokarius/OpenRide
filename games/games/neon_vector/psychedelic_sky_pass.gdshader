shader_type canvas_item;
render_mode unshaded, blend_disabled;
// The ride's sky, drawn once a frame into a small off-screen image (a quarter of the 3D
// view's pixels on the bike) and then stretched behind the scene by psychedelic_sky.gdshader.
// The field is smooth flowing light, so it loses very little at this size, and the heaviest
// shader in the picture runs on a quarter of the pixels.
#include "res://games/neon_vector/psychedelic_tunnel.gdshaderinc"
uniform float travel_m = 0.0;
uniform float intensity = 1.0;
uniform float detail = 1.0;
uniform int style = 0;
uniform vec3 primary : source_color = vec3(0.25, 0.6, 0.9);
uniform vec3 secondary : source_color = vec3(0.65, 0.25, 0.9);
uniform vec4 music = vec4(0.0);  // eased bass, mids, treble and kick pulse from the playing track
uniform float swirl = 0.0;       // a phase only the music advances
// The camera's view of the tunnel: turns a view-space ray into the tunnel's own frame.
uniform mat3 view_to_tunnel = mat3(1.0);
// tan(half the field of view), horizontally and vertically.
uniform vec2 half_extent = vec2(1.0, 0.5625);
void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	vec3 ray = view_to_tunnel * normalize(vec3(p * half_extent, -1.0));
	vec3 field = tunnel_field(ray, travel_m, style, primary, secondary, detail, music, swirl) * intensity;
	// Stored as a square root: eight bits then keep their precision in the dark end.
	COLOR = vec4(sqrt(clamp(field, 0.0, 1.0)), 1.0);
}
