shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never, fog_disabled;

uniform vec4 glow_color : source_color = vec4(1.0, 0.35, 0.04, 1.0);
uniform float glow_intensity : hint_range(0.0, 4.0) = 1.2;
// Core radius divided by shell radius (1 / 1.12 for the default shell).
uniform float surface_radius_ratio : hint_range(0.1, 0.999) = 0.892857;
uniform float fade_power : hint_range(0.2, 4.0) = 1.0;

void fragment() {
	// Distance from the camera ray to the sun's center gives a radial halo
	// profile that remains correct in perspective, even close to the sun.
	vec3 ray = normalize(VERTEX);
	float ray_distance = length(NODE_POSITION_VIEW - ray * dot(NODE_POSITION_VIEW, ray));
	float shell_radius = max(length(MODEL_MATRIX[0].xyz), 0.0001);
	float radial_position = ray_distance / shell_radius;
	float glow = 1.0 - smoothstep(surface_radius_ratio, 1.0, radial_position);
	ALBEDO = glow_color.rgb * glow_intensity;
	ALPHA = clamp(pow(glow, fade_power) * glow_color.a, 0.0, 1.0);
}
