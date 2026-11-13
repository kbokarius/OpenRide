shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec4 tint : source_color = vec4(0.43, 1.0, 0.82, 1.0);
uniform float power_zone = 0.0;
uniform float charge = 0.0;
uniform float intensity = 0.0;
uniform float flow = 0.0;
uniform float visible_alpha = 1.0;
uniform float road_end = 100000.0;
varying float road_s;
void vertex() { road_s = UV2.x; }
void fragment() {
    float across = abs(UV.x - 0.5) * 2.0;
    float edges = smoothstep(0.78, 0.94, across) * (1.0 - smoothstep(0.94, 1.0, across));
    float soft = pow(max(0.0, 1.0 - across), 0.7);
    float caps = smoothstep(0.0, 0.025, UV.y) * (1.0 - smoothstep(0.975, 1.0, UV.y));
    float grain = 0.9 + 0.1 * cos(UV.y * 100.0);
    vec3 color = tint.rgb;
    float alpha = (0.12 + soft * 0.18 + edges * 0.42) * grain;
    if (power_zone > 0.5) {
        float filled = 1.0 - smoothstep(charge - 0.035, charge + 0.035, UV.y);
        float wave = pow(0.5 + 0.5 * sin(UV.y * 100.0 - flow * 8.0), 12.0);
        float filament = pow(max(0.0, 1.0 - abs(UV.x - 0.5 - sin(UV.y * 38.0 + flow * 2.0) * 0.16) * 25.0), 2.0);
        float energized = filled * (0.22 + intensity * 0.17 + wave * 0.25) + filament * intensity * 0.18;
        color = mix(tint.rgb, vec3(0.78, 0.95, 1.0), min(0.85, filled * intensity * 0.35 + wave * filled * 0.25));
        alpha = 0.12 + edges * (0.4 + intensity * 0.2) + soft * energized;
    }
    ALBEDO = color;
    EMISSION = color * (0.12 + intensity * power_zone * 0.4);
    ALPHA = clamp(alpha * caps * visible_alpha, 0.0, 0.92) * (1.0 - smoothstep(road_end - 18.0, road_end, road_s));
}
