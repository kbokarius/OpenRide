// Hand lighting shared by every solid Lane Smash model. The tablet's GPU is fill-rate bound
// and engine lights cost about a third of a frame (docs/GAMES.md), so models are unshaded and
// lit here: a key and a fill fixed to the view (the look holds through loops and rolls), a
// tight highlight, and a coloured rim that separates dark hulls from the dark sky.
// Vertex data (MeshKit3D with `flags`): COLOR.rgb paint, COLOR.a gloss, UV.x accent share,
// UV.y self-lit share.
const vec3 LS_KEY = vec3(-0.38, 0.74, 0.55);
const vec3 LS_FILL = vec3(0.72, 0.18, 0.40);

vec3 ls_shade(vec3 paint, float gloss, float self_lit, vec3 n, vec3 v, vec3 rim_color, float glow_energy) {
	float key = max(dot(n, LS_KEY), 0.0);
	float fill = max(dot(n, LS_FILL), 0.0);
	float facing = max(dot(n, v), 0.0);
	float rim = pow(1.0 - facing, 3.0);
	vec3 half_vector = normalize(LS_KEY + v);
	float spec = pow(max(dot(n, half_vector), 0.0), 42.0) * gloss;
	vec3 lit = paint * (0.20 + key * 1.05 + fill * 0.34) + rim_color * rim * (0.35 + gloss * 0.5) + vec3(spec * 0.9);
	return mix(lit, paint * glow_energy, clamp(self_lit, 0.0, 1.0));
}
