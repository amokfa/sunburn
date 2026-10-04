shader_type sky;
global uniform float game_time;

uniform sampler2D starfield : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D milkyway : source_color, repeat_enable, filter_linear_mipmap;
uniform float milkyway_brightness : hint_range(0.0, 1.0) = 0.05;
uniform sampler2D noise_texture : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_texture_b : repeat_enable, filter_linear_mipmap;
uniform float sky_brightness : hint_range(0.0, 4.0) = 0.5;
uniform float flash_intensity = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float shimmer_scale : hint_range(0.1, 32.0) = 8.0;
uniform vec2 velocity_a = vec2(0.012, -0.008);
uniform vec2 velocity_b = vec2(-0.008, 0.015);
uniform float blend_period : hint_range(1.0, 300.0) = 12.0;
uniform float phase_variation : hint_range(0.0, 2.0) = 0.7;
uniform float minimum_brightness : hint_range(0.0, 2.0) = 0.45;
uniform float maximum_brightness : hint_range(0.0, 4.0) = 1.35;

// Same seamless spherical sampling and drifting A/B blend as the sun spots.
float spherical_noise(sampler2D source, vec3 p, vec2 drift) {
	vec3 weights = pow(abs(p), vec3(4.0));
	weights /= max(weights.x + weights.y + weights.z, 0.0001);
	float x = textureLod(source, p.yz * shimmer_scale + drift, 0.0).r;
	float y = textureLod(source, p.zx * shimmer_scale + drift, 0.0).r;
	float z = textureLod(source, p.xy * shimmer_scale + drift, 0.0).r;
	return dot(vec3(x, y, z), weights);
}

void sky() {
	vec3 p = normalize(EYEDIR);
	float field_a = spherical_noise(noise_texture, p, game_time * velocity_a);
	float field_b = spherical_noise(noise_texture_b, p, game_time * velocity_b);
	float phase_offset = TAU * phase_variation * (
		dot(p, vec3(1.3, 1.7, -1.1))
		+ 0.3 * sin(dot(p, vec3(3.7, -2.9, 4.1)))
	);
	float blend = 0.5 + 0.5 * sin(TAU * game_time / max(blend_period, 0.001) - PI * 0.5 + phase_offset);
	float field = mix(field_a, field_b, blend);
	float brightness = mix(minimum_brightness, maximum_brightness, smoothstep(0.2, 0.8, field));
	// Match Wanderer's starfield orientation and preserve the tiny stars.
	vec2 star_uv = vec2((atan(p.y, p.x) + PI) / TAU, -acos(clamp(p.z, -1.0, 1.0)) / PI);
	vec3 background = textureLod(milkyway, star_uv, 0.0).rgb * milkyway_brightness;
	COLOR = background + textureLod(starfield, star_uv, 0.0).rgb * sky_brightness * brightness + vec3(0.5) * flash_color.rgb * flash_intensity;
}
