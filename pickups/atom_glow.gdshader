shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 glow_color : source_color = vec4(0.1, 0.8, 1.0, 1.0);
uniform float brightness = 2.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	float radius = length(UV * 2.0 - 1.0);
	float glow = exp(-5.0 * radius * radius) * (1.0 - smoothstep(0.75, 1.0, radius));
	ALBEDO = glow_color.rgb * brightness;
	ALPHA = glow;
}
