shader_type spatial;
render_mode shadows_disabled;

uniform sampler2D grass_texture : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D sand_texture : repeat_enable, filter_linear_mipmap_anisotropic;
uniform float grass_tile_size = 40.0;
uniform float sand_tile_size = 12.0;
uniform float grass_strength : hint_range(0.0, 1.0) = 0.8;
uniform float sand_strength : hint_range(0.0, 1.0) = 0.65;

varying vec3 local_position;
varying vec3 local_normal;

void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
}

float triplanar_noise(sampler2D map, vec3 position, vec3 weights) {
	return texture(map, position.yz).r * weights.x
		+ texture(map, position.xz).r * weights.y
		+ texture(map, position.xy).r * weights.z;
}

void fragment() {
	// Coordinates follow the planet, with texture tiles measured in metres.
	vec3 position = local_position * length(MODEL_MATRIX[0].xyz);
	vec3 weights = pow(abs(normalize(local_normal)), vec3(4.0));
	weights /= dot(weights, vec3(1.0));
	float height = length(local_position) - 1.0;
	float grass_mask = smoothstep(0.003, 0.011, height);
	float rock_mask = smoothstep(0.029, 0.05, height);
	float grass_patch = triplanar_noise(grass_texture, position / grass_tile_size, weights);
	float grass_detail = triplanar_noise(grass_texture, position / (grass_tile_size * 0.23) + vec3(0.37), weights);
	float sand_detail = triplanar_noise(sand_texture, position / sand_tile_size, weights);
	// Mottled coverage and colour variation, rather than individual grass blades.
	vec3 grass_tint = mix(vec3(0.65, 0.73, 0.58), vec3(1.3, 1.2, 0.95), grass_patch);
	grass_tint *= mix(0.88, 1.12, grass_detail);
	vec3 sand_tint = vec3(mix(0.78, 1.22, sand_detail));
	vec3 detail = mix(mix(vec3(1.0), sand_tint, sand_strength), mix(vec3(1.0), grass_tint, grass_strength), grass_mask);
	ALBEDO = COLOR.rgb * mix(detail, vec3(1.0), rock_mask);
	ROUGHNESS = 0.95;
}
