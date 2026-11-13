shader_type spatial;
render_mode world_vertex_coords, cull_disabled, specular_disabled, blend_mix, depth_draw_always;
uniform float opacity : hint_range(0.0, 1.0) = 0.74;
uniform float glow = 0.06;
uniform float road_end = 480.0;
uniform float fade_start = 300.0;
varying float course_s;
void vertex() {
    // Immutable world geometry. The camera travels along the route.
    course_s = UV.x;
}
void fragment() {
    float fade = 1.0 - smoothstep(fade_start, road_end, course_s);
    if (fade < 0.001) { discard; }
    ALBEDO = COLOR.rgb;
    ROUGHNESS = 1.0;
    METALLIC = 0.0;
    EMISSION = COLOR.rgb * glow;
    ALPHA = opacity * fade;
}
