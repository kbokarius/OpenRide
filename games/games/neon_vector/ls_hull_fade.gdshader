shader_type spatial;
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_back, fog_disabled;
// The hull with a materialise/dematerialise fade: scan lines sweep the model in while
// `visibility` rises, then it is solid. Used by the attackers and their gunship.
#include "res://games/neon_vector/ls_light.gdshaderinc"
uniform vec3 accent : source_color = vec3(1.0, 0.42, 0.17);
uniform vec3 rim_color : source_color = vec3(1.0, 0.35, 0.3);
uniform float glow_energy = 2.6;
uniform float pulse = 0.0;
uniform float visibility = 1.0;
uniform float phase = 0.0;
uniform float force_accent = 0.0;  // whole-mesh overrides for meshes built without UV flags
uniform float force_glow = 0.0;
varying vec3 local_position;
void vertex() {
	local_position = VERTEX;
}
void fragment() {
	vec3 paint = mix(COLOR.rgb, accent, max(UV.x, force_accent));
	vec3 shaded = ls_shade(paint, COLOR.a, max(UV.y, force_glow), normalize(NORMAL), normalize(VIEW), rim_color, glow_energy * (1.0 + pulse));
	float arrival = 1.0 - visibility;
	float scan = 0.5 + 0.5 * sin(local_position.y * 46.0 - phase * 9.0);
	// The scan light rides the fade without leading it: it is strongest mid-fade and absent
	// at both ends, so a model neither flashes in nor blinks out.
	ALBEDO = shaded + accent * arrival * visibility * scan * 2.6;
	ALPHA = visibility * mix(1.0, 0.45 + 0.55 * scan, arrival);
}
