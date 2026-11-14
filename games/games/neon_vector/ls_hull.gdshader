shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;
// Opaque, hand-lit hull for the rider's bike, mines and track gantries.
#include "res://games/neon_vector/ls_light.gdshaderinc"
uniform vec3 accent : source_color = vec3(0.35, 0.8, 1.0);
uniform vec3 rim_color : source_color = vec3(0.6, 0.45, 1.0);
uniform float glow_energy = 2.4;
uniform float pulse = 0.0;  // extra self-lit energy (engine, beat)
void fragment() {
	vec3 paint = mix(COLOR.rgb, accent, UV.x);
	ALBEDO = ls_shade(paint, COLOR.a, UV.y, normalize(NORMAL), normalize(VIEW), rim_color, glow_energy * (1.0 + pulse));
}
