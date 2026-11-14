shader_type spatial;
render_mode world_vertex_coords, unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;
// Section floors, anchored to the road: a mint bed under cadence arrows and a violet power
// zone that fills with the rider's output. UV.x runs across the lane, UV.y along the section;
// UV2.x is the course distance in metres. Values above one feed the bloom.
uniform vec4 tint : source_color = vec4(0.43, 1.0, 0.82, 1.0);
uniform float power_zone = 0.0;
uniform float charge = 0.0;
uniform float intensity = 0.0;
uniform float flow = 0.0;
uniform float visible_alpha = 1.0;
uniform float road_end = 480.0;
uniform float fade_start = 300.0;
varying float road_s;
void vertex() { road_s = UV2.x; }
void fragment() {
    float across = abs(UV.x - 0.5) * 2.0;
    float edges = smoothstep(0.80, 0.92, across) * (1.0 - smoothstep(0.95, 1.0, across));
    float soft = pow(max(0.0, 1.0 - across), 0.7);
    float caps = smoothstep(0.0, 0.025, UV.y) * (1.0 - smoothstep(0.975, 1.0, UV.y));
    // Fine cross-hatching fixed to the road, so the bed visibly passes under the wheels.
    float hatch = 0.86 + 0.14 * cos(road_s * 4.2);
    vec3 color = tint.rgb;
    float alpha = (0.10 + soft * 0.17 + edges * 0.55) * hatch;
    float energy = 1.0 + edges * 1.3;
    if (power_zone > 0.5) {
        float filled = 1.0 - smoothstep(charge - 0.035, charge + 0.035, UV.y);
        float wave = pow(0.5 + 0.5 * sin(road_s * 2.4 - flow * 8.0), 10.0);
        // Two strands of current wander up the charged part of the zone.
        float strand = pow(max(0.0, 1.0 - abs(UV.x - 0.5 - sin(road_s * 0.9 + flow * 2.0) * 0.18) * 22.0), 2.0)
            + pow(max(0.0, 1.0 - abs(UV.x - 0.5 + sin(road_s * 1.3 - flow * 2.6) * 0.14) * 26.0), 2.0);
        // The leading edge of the stored energy is the brightest line in the zone.
        float front = exp(-pow((UV.y - charge) * 42.0, 2.0)) * step(0.012, charge);
        float energized = filled * (0.20 + intensity * 0.14 + wave * 0.26) + strand * filled * (0.14 + intensity * 0.26) + front * 0.8;
        // Stay violet: only the charge front and the passing waves approach white.
        color = mix(tint.rgb, vec3(0.86, 0.95, 1.0), min(0.6, filled * intensity * 0.12 + wave * filled * 0.22 + front * 0.55));
        alpha = 0.10 + edges * (0.45 + intensity * 0.2) + soft * energized;
        energy = 1.0 + filled * (0.15 + intensity * 0.18) + front * 0.9 + edges * 0.6;
    }
    ALBEDO = color * energy;
    ALPHA = clamp(alpha * caps * visible_alpha, 0.0, 0.92) * (1.0 - smoothstep(fade_start, road_end, road_s));
}
