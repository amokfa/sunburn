shader_type spatial;
global uniform float game_time;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 blue_color : source_color = vec4(0.05, 0.3, 1.0, 1.0);
uniform vec4 green_color : source_color = vec4(0.05, 1.0, 0.25, 1.0);
uniform float pulse_speed = 4.0;
uniform float pulse_phase = 0.0;
uniform float brightness = 3.0;
uniform float core_radius = 0.5;
uniform float outer_radius = 1.5;

void vertex() {
	// Use the camera axes while retaining the missile's world position.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]
	);
}

void fragment() {
	float radius = length(UV * 2.0 - 1.0) * outer_radius;
	float opacity = 1.0 - smoothstep(core_radius, outer_radius, radius);
	float pulse = 0.5 + 0.5 * sin(game_time * pulse_speed + pulse_phase);
	vec3 color = mix(blue_color.rgb, green_color.rgb, pulse);
	ALBEDO = color * brightness * mix(0.6, 1.0, pulse) * mix(0.35, 1.0, opacity);
	ALPHA = opacity;
}
