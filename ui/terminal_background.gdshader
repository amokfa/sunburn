shader_type canvas_item;
global uniform float game_time;
uniform sampler2D noise_texture_a : repeat_enable, filter_linear;
uniform sampler2D noise_texture_b : repeat_enable, filter_linear;
uniform vec4 background_color : source_color = vec4(0.32, 0.62, 0.38, 1.0);
uniform float minimum_opacity : hint_range(0.0, 1.0) = 0.12;
uniform float maximum_opacity : hint_range(0.0, 1.0) = 0.48;
uniform vec2 velocity_a = vec2(0.022, -0.012);
uniform vec2 velocity_b = vec2(-0.009, 0.032);
uniform float blend_period = 12.0;

void fragment() {
	float a = texture(noise_texture_a, UV * vec2(1.5, 1.0) + game_time * velocity_a).r;
	float b = texture(noise_texture_b, UV * vec2(1.5, 1.0) + game_time * velocity_b).r;
	// Fully transition A -> B -> A, while both texture coordinates keep moving.
	float blend = 0.5 + 0.5 * sin(TAU * game_time / max(blend_period, 0.001) - PI * 0.5);
	float field = smoothstep(0.12, 0.9, mix(a, b, blend));
	COLOR = vec4(background_color.rgb, background_color.a * mix(minimum_opacity, maximum_opacity, field));
}
