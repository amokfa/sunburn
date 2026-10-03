shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;
uniform vec4 shell_color : source_color = vec4(0.15, 0.6, 0.8, 1.0);
void fragment() {
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 3.0);
	ALBEDO = shell_color.rgb * mix(0.65, 1.5, rim);
	ALPHA = 0.035 + rim * 0.22;
}
