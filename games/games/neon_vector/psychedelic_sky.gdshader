shader_type sky;
render_mode disable_fog;
// Puts the off-screen sky image (psychedelic_sky_pass.gdshader) behind the scene: one texture
// read a pixel, plus a sparse field of stars drawn here at full sharpness. Nothing in this
// material changes from frame to frame, so the engine never has to re-filter the sky.
uniform sampler2D sky_pass : filter_linear, repeat_disable;
uniform sampler2D star_noise : filter_linear, repeat_enable;
uniform float stars = 1.0;
uniform vec2 inv_view = vec2(0.001, 0.001);  // one over the 3D view's size in pixels
uniform vec3 star_tint : source_color = vec3(0.8, 0.9, 1.0);
void sky() {
	if (AT_CUBEMAP_PASS) { COLOR = vec3(0.006, 0.01, 0.02); }
	else {
		// The pixel's own place on screen picks the same place in the sky image. (SCREEN_UV is
		// not a usable screen coordinate in sky shaders on this renderer.)
		vec3 field = texture(sky_pass, FRAGCOORD.xy * inv_view).rgb;
		field *= field;
		// Soft stars fixed in space behind the ribbons give the void its depth.
		float speck = texture(star_noise, EYEDIR.xy * 5.0 + EYEDIR.z * 2.0).r;
		COLOR = field + star_tint * pow(speck, 26.0) * stars * 1.4;
	}
}
