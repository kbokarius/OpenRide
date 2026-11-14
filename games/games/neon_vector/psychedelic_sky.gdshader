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
uniform vec4 music = vec4(0.0);  // eased bass, mids, treble and kick pulse from the playing track
uniform float swirl = 0.0;       // a phase only the music advances
uniform sampler2D star_noise : filter_linear, repeat_enable;
uniform float stars = 1.0;
void sky() {
    if (AT_CUBEMAP_PASS) { COLOR = primary * 0.025; }
    else {
        vec3 ray = transpose(portal_basis) * EYEDIR;
        vec3 field = tunnel_field(ray, travel_m, style, primary, secondary, detail, music, swirl);
        // A sparse field of soft stars behind the ribbons gives the void its depth. They are
        // fixed to the tunnel's frame, so they wheel with the road rather than the screen.
        float speck = texture(star_noise, ray.xy * 5.0 + ray.z * 2.0).r;
        float star = pow(speck, 26.0) * stars * (0.8 + 0.3 * music.z);
        COLOR = (field + mix(primary, vec3(1.0), 0.7) * star * 1.4) * intensity;
    }
}
