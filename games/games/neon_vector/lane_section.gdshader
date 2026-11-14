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
uniform float zone_start = 0.0;
uniform float zone_finish = 100.0;
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
        // A saturated, opaque violet bed is readable before it has any charge, even without
        // bloom. Fixed-width white caps mark its exact bounds, rather than fading those away.
        float pixel_s = max(0.035, fwidth(road_s));
        float end_distance = min(road_s - zone_start, zone_finish - road_s);
        float end_line = 1.0 - smoothstep(0.36, 0.36 + pixel_s, end_distance);
        float rim = max(edges, end_line);
        // World-anchored diagonal etching: no stripes that stick to the front wheel.
        float etch_s = abs(fract((road_s + across * 2.1) / 9.0 + 0.5) - 0.5) * 9.0;
        float etch = (1.0 - smoothstep(0.16, 0.16 + pixel_s, etch_s)) * (1.0 - smoothstep(0.6, 2.2, pixel_s));
        color = mix(vec3(0.48, 0.055, 1.0), vec3(0.82, 0.44, 1.0), 0.35 + soft * 0.28 + filled * 0.24);
        color = mix(color, vec3(0.96, 0.90, 1.0), clamp(rim * 0.9 + front * 0.85 + filled * strand * 0.18, 0.0, 1.0));
        alpha = 0.76 + rim * 0.2 + filled * 0.08;
        energy = 1.05 + rim * 1.0 + soft * energized * 0.65 + etch * 0.24;
        // Leave a dark hairline at the sides to separate this zone from the target-lane wash.
        color *= 1.0 - smoothstep(0.96, 1.0, across) * (1.0 - end_line) * 0.8;
        caps = 1.0;
    }
    ALBEDO = color * energy;
    ALPHA = clamp(alpha * caps * visible_alpha, 0.0, 0.92) * (1.0 - smoothstep(fade_start, road_end, road_s));
}
