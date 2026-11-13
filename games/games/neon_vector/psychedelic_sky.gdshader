shader_type sky;
render_mode disable_fog;
uniform float flow_time = 0.0;
uniform float resistance = 0.0;
uniform float intensity = 1.0;
uniform int style = 0;
uniform vec2 portal_center = vec2(0.0, 0.04);
uniform mat3 camera_basis = mat3(1.0);
uniform vec3 primary : source_color = vec3(0.25, 0.6, 0.9);
uniform vec3 secondary : source_color = vec3(0.65, 0.25, 0.9);
void sky() {
    // Constant low-cost lighting cubemap; flowing detail only renders on screen.
    if (AT_CUBEMAP_PASS) { COLOR = primary * 0.025; }
    else {
        vec3 ray = transpose(camera_basis) * EYEDIR;
        vec2 p = vec2(ray.x, ray.y) / max(0.2, -ray.z) * 0.7 - portal_center;
        float radius = max(length(p), 0.008);
        float angle = atan(p.y, p.x);
        float depth = -log(radius);
        float t = flow_time;
        float fold = angle + depth * (0.8 + resistance * 1.8) + t * 0.12 + 0.18 * sin(depth * 3.0 - t * 0.7);
        float ribbons = sin(fold * 5.0 + sin(depth * 4.0 - t));
        float waves = sin(depth * 14.0 - t * 3.0 + ribbons * 2.1);
        if (style == 1) {
            fold = abs(sin(angle * 4.0 + t * 0.07)) * 2.0 + depth;
            ribbons = sin(fold * 6.0 + sin(depth * 5.0 - t));
            waves = sin(depth * 16.0 - t * 2.5 + ribbons * (1.0 + resistance));
        } else if (style == 2) {
            vec2 q = p * 3.0;
            for (int i = 0; i < 3; i++) { q += 0.25 * vec2(sin(q.y * 2.4 + t * 0.3), cos(q.x * 2.0 - t * 0.4)); }
            ribbons = sin(q.x * 4.0 + q.y * 3.0 + depth * 3.0 - t);
            waves = sin(depth * 10.0 - t * 2.0 + ribbons * 3.0);
        } else if (style == 3) {
            fold = angle * 3.0 + depth * (3.0 + resistance * 2.0) - t * 0.45;
            ribbons = sin(fold + sin(depth * 5.0 - t));
            waves = sin(depth * 17.0 - t * 3.0 + sin(fold) * 3.0);
        }
        float filament = pow(0.5 + 0.5 * waves, 14.0);
        float silk = pow(0.5 + 0.5 * ribbons, 3.0);
        vec3 hue = mix(primary, secondary, 0.5 + 0.5 * sin(fold + depth * 0.8 + resistance * 3.0));
        vec3 ink = mix(vec3(0.008, 0.012, 0.028), hue * 0.055, silk);
        float vignette = smoothstep(0.012, 0.12, radius) * (1.0 - smoothstep(0.5, 1.15, radius) * 0.4);
        COLOR = ink + hue * (0.13 * silk + filament * (0.48 + silk * 0.28)) * vignette * intensity;
    }
}
