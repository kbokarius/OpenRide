shader_type spatial;
render_mode world_vertex_coords, cull_disabled, specular_disabled;
uniform float road_end = 200.0;
uniform vec3 portal_point = vec3(0.0, 0.0, -200.0);
uniform float glow = 0.06;
void vertex() {
    // UV.x is absolute course distance; UV.y is lane offset. The mesh stays
    // anchored while the horizon and taper move continuously at render rate.
    float t = clamp((UV.x - (road_end - 28.0)) / 28.0, 0.0, 1.0);
    float taper = 1.0 - t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
    VERTEX -= TANGENT * UV.y * (1.0 - taper);
    if (UV.x >= road_end) { VERTEX = portal_point; }
}
void fragment() {
    ALBEDO = COLOR.rgb;
    ROUGHNESS = 1.0;
    METALLIC = 0.0;
    EMISSION = COLOR.rgb * glow;
}
