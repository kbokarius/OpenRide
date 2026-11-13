// Shared, metre-based tunnel field used by the sky and the track-card previews.
// Advancing travel makes fixed longitudinal features expand out past the viewer.
vec3 tunnel_field(vec3 ray, float travel, int style, vec3 primary, vec3 secondary, float detail) {
    float radial = max(length(ray.xy), 0.0001);
    float depth = 28.0 * (-ray.z) / radial;
    float z = (travel + depth) * 0.055;
    float angle = atan(ray.y, ray.x);
    float fold = angle * 5.0 + z * 0.7 + 0.65 * sin(z * 0.6);
    float ribbon = sin(fold + sin(z * 0.9));
    float phase = z * 4.0 + ribbon * 2.2;
    if (style == 1) {
        fold = cos(angle * 6.0) * 2.8 + z * 0.65;
        ribbon = sin(fold + sin(z * 1.1));
        phase = z * 4.5 + ribbon * 2.5;
    } else if (style == 2) {
        fold = sin(angle * 3.0 + z * 0.35) + cos(angle * 5.0 - z * 0.5);
        ribbon = sin(fold * 2.2 + z * 0.8);
        phase = z * 3.2 + ribbon * 3.0;
    } else if (style == 3) {
        fold = angle * 3.0 + z * 1.9;
        ribbon = sin(fold + sin(z * 0.7));
        phase = z * 4.2 + ribbon * 3.0;
    }
    // Filter compressed detail near the opening instead of letting it shimmer.
    // Differentiate the continuous direction, not atan's discontinuity at -PI/PI.
    float footprint = fwidth(z) * 7.0 + (fwidth(ray.x / radial) + fwidth(ray.y / radial)) * 6.0;
    float resolved = 1.0 - smoothstep(0.5, 2.4, footprint);
    float filament = pow(0.5 + 0.5 * sin(phase), mix(5.0, 12.0, detail)) * resolved;
    float silk = pow(0.5 + 0.5 * ribbon, 3.0) * (1.0 - smoothstep(0.7, 3.0, footprint * 0.45));
    vec3 hue = mix(primary, secondary, 0.5 + 0.5 * sin(fold + z * 0.3));
    float horizon = 1.0 - smoothstep(220.0, 700.0, abs(depth));
    return vec3(0.006, 0.01, 0.019) + hue * (0.14 * silk + filament * (0.5 + 0.25 * silk)) * horizon;
}
