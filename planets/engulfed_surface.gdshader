shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec4 surface_color : source_color = vec4(1.0, 0.28, 0.015, 1.0);
uniform float reveal : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	ALBEDO = surface_color.rgb;
	ALPHA = reveal;
}
