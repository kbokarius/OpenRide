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
uniform vec4 music = vec4(0.0);
uniform float swirl = 0.0;
uniform vec2 size_px = vec2(1040.0, 188.0);
uniform float cut_px = 14.0;
void fragment() {
    vec2 p = (UV - vec2(0.8, 0.48)) * vec2(aspect, 1.0) * 1.9;
    vec3 scene = tunnel_field(normalize(vec3(p, -1.0)), preview_m, style, primary, secondary, 0.65, music, swirl);
    vec3 tinted = mix(vec3(0.025, 0.04, 0.065), accent * 0.19, 0.6);
    // A continuous ink scrim keeps the entire text column readable over every frame.
    float scrim = mix(0.94, 0.12, smoothstep(0.42, 0.84, UV.x));
    vec3 color = mix(scene * 1.45, tinted, scrim);
    color += accent * (0.015 + selected * 0.03);
    // Match the card's cut corners, so the picture never pokes past its frame.
    vec2 px = UV * size_px;
    float corner = min(px.x, size_px.x - px.x) + min(px.y, size_px.y - px.y);
    COLOR = vec4(color, smoothstep(cut_px - 1.0, cut_px + 1.0, corner));
}
