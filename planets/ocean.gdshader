shader_type spatial;
global uniform float game_time;
render_mode shadows_disabled;

// Adapted from wanderer's lake: four drifting noise normals and Fresnel color.
uniform vec4 deep_color : source_color = vec4(0.012, 0.07, 0.16, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.035, 0.19, 0.23, 1.0);
uniform vec4 fresnel_color : source_color = vec4(0.19, 0.28, 0.34, 1.0);
uniform float fresnel_power : hint_range(1.0, 8.0) = 4.0;
uniform sampler2D noise1 : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D noise2 : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float wave_tile_size : hint_range(10.0, 200.0) = 96.0;
uniform float wave_speed : hint_range(0.0, 0.03) = 0.004;
uniform float wave_strength : hint_range(0.0, 2.0) = 0.45;
uniform float detail_fade_start = 60.0;
uniform float detail_fade_end = 400.0;
uniform float shallow_depth : hint_range(0.1, 10.0) = 2.5;
uniform vec3 sun_position = vec3(0.0);
uniform float sun_radius = 500.0;
uniform float sun_halo_radius = 600.0;
uniform vec4 sun_reflection_color : source_color = vec4(1.0, 0.58, 0.22, 1.0);
uniform vec4 sun_halo_color : source_color = vec4(1.0, 0.35, 0.04, 1.0);
uniform float sun_reflection_strength : hint_range(0.0, 1.0) = 0.9;
uniform float halo_reflection_strength : hint_range(0.0, 1.0) = 0.45;
// R stores generated seabed depth / 0.04, in units of the planet radius.
uniform sampler2D seabed_depth : repeat_enable, filter_linear_mipmap;

varying vec3 sphere_position;
varying vec3 world_position;

void vertex() {
	sphere_position = VERTEX;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 wave_slopes(vec2 uv) {
	float t = game_time * wave_speed;
	vec2 n1 = texture(noise1, uv + vec2(0.0, -t)).rg;
	vec2 n2 = texture(noise2, uv * 0.73 + vec2(0.0, t * 0.9)).rg;
	vec2 n3 = texture(noise1, uv + vec2(-t * 1.1, 0.0) + vec2(0.37, 0.19)).rg;
	vec2 n4 = texture(noise2, uv * 0.73 + vec2(t * 1.2, 0.0) + vec2(0.13, 0.61)).rg;
	return (n1 + n2 + n3 + n4) * 0.5 - vec2(1.0);
}

void fragment() {
	vec3 radial = normalize(sphere_position);
	// Meter-based coordinates follow the planet, including during frame rebasing.
	float radius = length(MODEL_MATRIX[0].xyz);
	vec3 p = radial * radius / wave_tile_size;
	vec3 weights = pow(abs(radial), vec3(4.0));
	weights /= dot(weights, vec3(1.0));
	vec2 sx = wave_slopes(p.yz);
	vec2 sy = wave_slopes(p.xz);
	vec2 sz = wave_slopes(p.xy);
	vec3 slope = vec3(0.0, sx.x, sx.y) * weights.x
		+ vec3(sy.x, 0.0, sy.y) * weights.y
		+ vec3(sz.x, sz.y, 0.0) * weights.z;
	slope -= radial * dot(slope, radial);
	float detail = 1.0 - smoothstep(detail_fade_start, detail_fade_end, length(VERTEX));
	vec3 local_normal = normalize(radial + slope * wave_strength * detail);
	NORMAL = normalize(mat3(VIEW_MATRIX) * mat3(MODEL_MATRIX) * local_normal);
	vec3 world_normal = normalize(mat3(MODEL_MATRIX) * local_normal);

	// Shore tint follows the same elevation field as the terrain and sand.
	vec2 shore_uv = vec2(atan(radial.z, radial.x) / (2.0 * PI) + 0.5,
		asin(clamp(radial.y, -1.0, 1.0)) / PI + 0.5);
	float half_texel = 0.5 / float(textureSize(seabed_depth, 0).y);
	shore_uv.y = clamp(shore_uv.y, half_texel, 1.0 - half_texel);
	float thickness = texture(seabed_depth, shore_uv).r * 0.04 * radius;
	float shallowness = 1.0 - smoothstep(0.0, shallow_depth, thickness);
	vec3 water = mix(deep_color.rgb, shallow_color.rgb, shallowness);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, normalize(VIEW)), 0.0, 1.0), fresnel_power);
	vec3 view_direction = normalize(CAMERA_POSITION_WORLD - world_position);
	vec3 reflected_direction = reflect(-view_direction, world_normal);
	vec3 to_sun = world_position - sun_position;
	float half_b = dot(to_sun, reflected_direction);
	float discriminant = half_b * half_b - (dot(to_sun, to_sun) - sun_radius * sun_radius);
	float sun_hit = 0.0;
	float halo_hit = 0.0;
	if (dot(reflected_direction, radial) > 0.0) {
		if (discriminant >= 0.0) {
			float hit_distance = -half_b - sqrt(discriminant);
			if (hit_distance < 0.0) {
				hit_distance = -half_b + sqrt(discriminant);
			}
			sun_hit = step(0.0, hit_distance);
		}
		float halo_discriminant = half_b * half_b - (dot(to_sun, to_sun) - sun_halo_radius * sun_halo_radius);
		if (halo_discriminant >= 0.0) {
			float halo_exit = -half_b + sqrt(halo_discriminant);
			halo_hit = step(0.0, halo_exit) * (1.0 - sun_hit);
		}
	}
	float reflection = sun_hit * sun_reflection_strength;
	// The halo shader's density fades radially from the solar surface to its
	// outer radius. Apply the same smooth radial fade to its water reflection.
	float closest_ray_distance = length(to_sun + reflected_direction * max(-half_b, 0.0));
	float halo_fade = 1.0 - smoothstep(sun_radius, max(sun_halo_radius, sun_radius + 0.001), closest_ray_distance);
	float halo_reflection = halo_hit * halo_reflection_strength * halo_fade;
	vec3 reflected_color = mix(sun_halo_color.rgb, sun_reflection_color.rgb, sun_hit);
	float reflected_strength = max(reflection, halo_reflection);
	ALBEDO = mix(mix(water, fresnel_color.rgb, fresnel * 0.65), reflected_color, reflected_strength);
	EMISSION = sun_reflection_color.rgb * reflection * 0.5 + sun_halo_color.rgb * halo_reflection * 0.15;
	METALLIC = 0.0;
	SPECULAR = 0.5;
	ROUGHNESS = mix(0.22, 0.13, detail);
}
