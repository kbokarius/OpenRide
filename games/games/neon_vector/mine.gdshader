shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_always, cull_back, fog_disabled;
// Road mines: hand-lit hull, pulsing lamps. The instance alpha fades a mine in at the horizon
// and out during attacks; `blink` is the shared warning pulse.
#include "res://games/neon_vector/ls_light.gdshaderinc"
uniform vec3 accent : source_color = vec3(1.0, 0.2, 0.33);
uniform float blink = 0.0;
void fragment() {
	vec3 paint = mix(COLOR.rgb, accent, UV.x);
	ALBEDO = ls_shade(paint, 0.8, UV.y, normalize(NORMAL), normalize(VIEW), accent, 1.6 + blink * 2.6);
	ALPHA = COLOR.a;
}
