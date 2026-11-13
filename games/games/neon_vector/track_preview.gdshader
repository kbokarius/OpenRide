shader_type canvas_item;
render_mode unshaded;
#include "res://games/neon_vector/psychedelic_tunnel.gdshaderinc"
uniform vec3 primary : source_color;
uniform vec3 secondary : source_color;
uniform vec3 accent : source_color;
uniform int style = 0;
uniform float preview_m = 0.0;
uniform float aspect = 5.4;
uniform float selected = 0.0;
void fragment() {
    vec2 p = (UV - vec2(0.8, 0.48)) * vec2(aspect, 1.0) * 1.9;
    vec3 scene = tunnel_field(normalize(vec3(p, -1.0)), preview_m, style, primary, secondary, 0.65);
    vec3 tinted = mix(vec3(0.025, 0.04, 0.065), accent * 0.19, 0.6);
    // A continuous ink scrim keeps the entire text column readable over every frame.
    float scrim = mix(0.93, 0.15, smoothstep(0.45, 0.83, UV.x));
    vec3 color = mix(scene * 1.45, tinted, scrim);
    color += accent * (0.015 + selected * 0.025);
    COLOR = vec4(color, 1.0);
}
