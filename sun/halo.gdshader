shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never, fog_disabled;

uniform vec4 glow_color : source_color = vec4(1.0, 0.35, 0.04, 1.0);
uniform float glow_intensity : hint_range(0.0, 4.0) = 1.2;
// Core radius divided by shell radius (1 / 1.12 for the default shell).
uniform float surface_radius_ratio : hint_range(0.1, 0.999) = 0.892857;
uniform float fade_power : hint_range(0.2, 4.0) = 1.0;
uniform float glow_density : hint_range(0.1, 32.0) = 12.0;

void fragment() {
	// Integrate the emitting shell along the forward ray, including when the
	// camera is inside it. Tangential rays accumulate glow over a longer path.
	vec3 ray = normalize(VERTEX);
	float shell_radius = max(length(MODEL_MATRIX[0].xyz), 0.0001);
	vec3 center = NODE_POSITION_VIEW / shell_radius;
	float along_ray = dot(center, ray);
	float perpendicular_squared = max(dot(center, center) - along_ray * along_ray, 0.0);
	float half_chord = sqrt(max(1.0 - perpendicular_squared, 0.0));
	float entry = max(along_ray - half_chord, 0.0);
	float exit = max(along_ray + half_chord, entry);
	// Stop at the core if the forward ray reaches it before leaving the shell.
	float core_squared = surface_radius_ratio * surface_radius_ratio;
	if (perpendicular_squared < core_squared) {
		float core_entry = along_ray - sqrt(core_squared - perpendicular_squared);
		if (core_entry > entry) {
			exit = min(exit, core_entry);
		}
	}
	float step_length = (exit - entry) / 16.0;
	float integrated_density = 0.0;
	for (int i = 0; i < 16; i++) {
		float distance_along_ray = entry + (float(i) + 0.5) * step_length;
		float radius = length(ray * distance_along_ray - center);
		float density = 1.0 - smoothstep(surface_radius_ratio, 1.0, radius);
		integrated_density += density * step_length;
	}
	float glow = 1.0 - exp(-integrated_density * glow_density);
	ALBEDO = glow_color.rgb * glow_intensity;
	ALPHA = clamp(pow(glow, fade_power) * glow_color.a, 0.0, 1.0);
}
