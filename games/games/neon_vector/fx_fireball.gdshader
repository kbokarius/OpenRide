shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;
// An energy blast: a boiling sphere that starts white-hot, cools to its tint and breaks up.
// INSTANCE_CUSTOM.x is the blast's age (0..1); a small noise texture replaces per-pixel hashing.
uniform sampler2D noise : filter_linear, repeat_enable;
varying float age;
void vertex() {
	age = INSTANCE_CUSTOM.x;
	// An explicit level: vertex shaders have no derivatives to choose one from (GLES3).
	float swell = textureLod(noise, UV * 2.0 + vec2(age * 0.5, 0.0), 0.0).r;
	VERTEX += NORMAL * (swell - 0.5) * 0.4;
}
void fragment() {
	float facing = max(dot(normalize(NORMAL), normalize(VIEW)), 0.0);
	float grain = texture(noise, UV * 3.0 - vec2(0.0, age * 1.3)).r;
	float heat = clamp(pow(facing, 1.4) * 1.2 + grain * 0.75 - age * 1.35 - 0.12, 0.0, 1.0);
	// White-hot only at the first instant; after that the blast shows its colour and its grain.
	vec3 hot = mix(COLOR.rgb, vec3(1.0, 0.93, 0.8), smoothstep(0.62, 1.0, heat) * (1.0 - age));
	ALBEDO = hot * (0.7 + 1.0 * (1.0 - age));
	// Fade the part of the blast that is right in front of the camera, so a hit never fills
	// the screen with a flat flash.
	float near = smoothstep(4.0, 18.0, -VERTEX.z);
	ALPHA = COLOR.a * smoothstep(0.0, 0.35, heat) * (1.0 - smoothstep(0.7, 1.0, age)) * near * 0.8;
}
