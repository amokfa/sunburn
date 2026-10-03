shader_type spatial;

uniform sampler2D surface_noise : repeat_enable, filter_linear_mipmap;
uniform vec4 deck_color : source_color = vec4(0.28, 0.31, 0.34, 1.0);
uniform float panel_size = 2.0;
varying vec3 local_position;
varying vec3 local_normal;

void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
}

float grain(vec3 position, vec3 weights, float scale) {
	return dot(vec3(texture(surface_noise, position.yz * scale).r,
		texture(surface_noise, position.xz * scale).r,
		texture(surface_noise, position.xy * scale).r), weights);
}

void fragment() {
	vec3 weights = pow(abs(normalize(local_normal)), vec3(8.0));
	weights /= max(dot(weights, vec3(1.0)), 0.001);
	float stains = grain(local_position, weights, 0.22);
	float fine_grain = grain(local_position, weights, 3.0);
	vec3 color = deck_color.rgb * (0.65 + stains * 0.65 + fine_grain * 0.22);
	// Metre-sized panels on the deck; legs retain the same weathered finish.
	vec2 cell = mod(local_position.xz, vec2(panel_size));
	vec2 edge = min(cell, vec2(panel_size) - cell);
	float edge_distance = min(edge.x, edge.y);
	float antialias = max(fwidth(edge_distance), 0.001);
	float seam = 1.0 - smoothstep(0.012 - antialias, 0.012 + antialias, edge_distance);
	float bolt_distance = length(edge - vec2(0.12));
	float bolt = 1.0 - smoothstep(0.035 - antialias, 0.035 + antialias, bolt_distance);
	float top_face = weights.y;
	color = mix(color, vec3(0.055, 0.065, 0.075), seam * top_face);
	color = mix(color, vec3(0.4, 0.42, 0.44), bolt * top_face);
	ALBEDO = color;
	ROUGHNESS = clamp(0.88 + fine_grain * 0.12 - bolt * top_face * 0.15, 0.0, 1.0);
	METALLIC = 0.1;
}
