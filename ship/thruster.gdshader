shader_type spatial;
global uniform float game_time;
render_mode unshaded, blend_add, cull_back, depth_draw_never, fog_disabled, shadows_disabled;

uniform float power : hint_range(0.0, 1.0) = 0.0;
uniform vec4 exhaust_color : source_color = vec4(1.0, 0.8, 0.05, 1.0);
uniform float brightness = 12.0;
varying float axial_position;

void vertex() {
	axial_position = VERTEX.y + 0.5;
}

void fragment() {
	float axial = clamp(axial_position, 0.0, 1.0);
	float edge = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.7);
	float plume = smoothstep(0.0, 0.06, axial) * pow(1.0 - axial, 0.8) * edge;
	float flicker = 0.92 + 0.05 * sin(game_time * 17.0 + axial * 11.0) + 0.03 * sin(game_time * 29.3 - axial * 7.0);
	vec3 color = mix(vec3(1.0, 0.95, 0.5), exhaust_color.rgb, smoothstep(0.0, 0.6, axial));
	ALBEDO = color;
	EMISSION = color * brightness;
	ALPHA = clamp(plume * power * flicker * exhaust_color.a, 0.0, 1.0);
}
