shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 point = UV - vec2(0.5);
	float radius = length(point);
	float ring = smoothstep(0.30, 0.32, radius) * (1.0 - smoothstep(0.37, 0.39, radius));
	float angle = atan(point.y, point.x);
	float trail = fract((angle - TIME * 3.0) / 6.2831853);
	float brightness = 0.12 + 0.88 * pow(trail, 3.0);
	COLOR = vec4(vec3(0.65, 0.9, 0.75) * brightness, ring);
}
