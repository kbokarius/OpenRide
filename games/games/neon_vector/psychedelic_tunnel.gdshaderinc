// Shared, metre-based tunnel field used by the sky, the menu backdrop and the track cards.
// Advancing `travel` makes fixed longitudinal features expand out past the viewer; only the
// rider's real distance does that. Music never moves the field forward. It reshapes it:
//   music.x bass   -> the walls breathe in a little and the filaments thicken
//   music.y mids   -> the cross-section bends and the ribbons widen
//   music.z treble -> fine sparkle rides the filaments
//   music.w pulse  -> soft rings of light run down the tunnel and the field lifts slightly
//   swirl          -> a phase only the music advances: the field turns and its colours cycle
// The inputs are already eased over half a second or more, and every gain below is
// modest on purpose: large, fast changes across the whole screen are tiring to ride into.
// With music at zero and swirl at zero this is exactly the calm, silent field.
vec3 tunnel_field(vec3 ray, float travel, int style, vec3 primary, vec3 secondary, float detail, vec4 music, float swirl) {
    float radial = max(length(ray.xy), 0.0001);
    float depth = 28.0 * (1.0 - 0.035 * music.x) * (-ray.z) / radial;
    float z = (travel + depth) * 0.055;
    float angle = atan(ray.y, ray.x) + swirl * 0.22;
    float bend = music.y * 0.5 * sin(angle * 3.0 - swirl * 0.7);
    float fold = angle * 5.0 + z * 0.7 + 0.65 * sin(z * 0.6) + bend;
    float ribbon = sin(fold + sin(z * 0.9));
    float phase = z * 4.0 + ribbon * 2.2;
    if (style == 1) {
        fold = cos(angle * 6.0) * (2.8 + music.y * 0.5) + z * 0.65 + bend * 0.5;
        ribbon = sin(fold + sin(z * 1.1));
        phase = z * 4.5 + ribbon * 2.5;
    } else if (style == 2) {
        fold = sin(angle * 3.0 + z * 0.35) + cos(angle * 5.0 - z * 0.5) + bend * 0.6;
        ribbon = sin(fold * 2.2 + z * 0.8);
        phase = z * 3.2 + ribbon * 3.0;
    } else if (style == 3) {
        fold = angle * 3.0 + z * 1.9 + bend;
        ribbon = sin(fold + sin(z * 0.7));
        phase = z * 4.2 + ribbon * 3.0;
    }
    phase += music.w * 0.9 * sin(depth * 0.09 - swirl * 3.0);
    // Filter compressed detail near the opening instead of letting it shimmer.
    // Differentiate the continuous direction, not atan's discontinuity at -PI/PI.
    float footprint = fwidth(z) * 7.0 + (fwidth(ray.x / radial) + fwidth(ray.y / radial)) * 6.0;
    float resolved = 1.0 - smoothstep(0.5, 2.4, footprint);
    float wave = 0.5 + 0.5 * sin(phase);
    float filament = pow(wave, mix(mix(5.0, 12.0, detail), 4.2, music.x * 0.6)) * resolved;
    float silk = pow(0.5 + 0.5 * ribbon, mix(3.0, 2.2, music.y)) * (1.0 - smoothstep(0.7, 3.0, footprint * 0.45));
    float sparkle = pow(0.5 + 0.5 * sin(phase * 3.0 + swirl * 4.0), 18.0) * music.z * resolved;
    vec3 hue = mix(primary, secondary, 0.5 + 0.5 * sin(fold + z * 0.3 + swirl * 0.5));
    float horizon = 1.0 - smoothstep(220.0, 700.0, abs(depth));
    float lift = 1.0 + music.w * 0.35 + music.x * 0.2;
    return vec3(0.006, 0.01, 0.019) + (hue * (0.14 * silk + filament * (0.5 + 0.25 * silk)) * lift
        + mix(hue, vec3(1.0), 0.6) * sparkle * 0.55) * horizon;
}
