shader_type sky;
render_mode disable_fog;
#include "res://games/neon_vector/psychedelic_tunnel.gdshaderinc"
uniform float travel_m = 0.0;
uniform float intensity = 1.0;
uniform float detail = 1.0;
uniform int style = 0;
uniform mat3 portal_basis = mat3(1.0);
uniform vec3 primary : source_color = vec3(0.25, 0.6, 0.9);
uniform vec3 secondary : source_color = vec3(0.65, 0.25, 0.9);
void sky() {
    if (AT_CUBEMAP_PASS) { COLOR = primary * 0.025; }
    else {
        vec3 ray = transpose(portal_basis) * EYEDIR;
        COLOR = tunnel_field(ray, travel_m, style, primary, secondary, detail) * intensity;
    }
}
