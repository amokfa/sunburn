shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform sampler2D noise_texture : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_texture_b : repeat_enable, filter_linear_mipmap;
uniform vec4 yellow_color : source_color = vec4(1.0, 0.28, 0.015, 1.0);
uniform vec4 red_color : source_color = vec4(1.0, 0.035, 0.005, 1.0);
uniform float color_progress : hint_range(0.0, 1.0) = 0.0;
uniform float explosion_strength = 0.0;
uniform vec4 spot_color : source_color = vec4(0.65, 0.19, 0.025, 1.0);
uniform float spot_strength : hint_range(0.0, 1.0) = 0.65;
uniform float wave_amplitude : hint_range(0.0, 0.05, 0.001) = 0.012;
uniform float wave_frequency : hint_range(1.0, 60.0) = 18.0;
uniform float wave_speed : hint_range(0.0, 4.0) = 0.65;
uniform float spot_scale : hint_range(0.1, 8.0) = 1.8;
uniform vec2 spot_velocity_a = vec2(0.006, -0.0036);
uniform vec2 spot_velocity_b = vec2(-0.003, 0.0075);
uniform float spot_blend_period : hint_range(10.0, 300.0) = 120.0;
uniform float spot_phase_variation : hint_range(0.0, 2.0) = 0.7;
uniform float spot_threshold : hint_range(0.0, 1.0) = 0.6;
uniform float spot_softness : hint_range(0.001, 0.4) = 0.25;

varying vec3 surface_direction;

// Sample a seamless noise texture in three planes, avoiding sphere UV seams/poles.
float surface_noise(sampler2D source, vec3 p, float scale, vec2 drift) {
	vec3 weights = pow(abs(p), vec3(4.0));
	weights /= max(weights.x + weights.y + weights.z, 0.0001);
	float x = textureLod(source, p.yz * scale + drift, 0.0).r;
	float y = textureLod(source, p.zx * scale + drift, 0.0).r;
	float z = textureLod(source, p.xy * scale + drift, 0.0).r;
	return dot(vec3(x, y, z), weights);
}

void vertex() {
	vec3 p = normalize(VERTEX);
	surface_direction = p;
	float t = TIME * wave_speed;
	float wave = sin(dot(p, vec3(1.0, 0.7, 0.3)) * wave_frequency + t);
	wave += 0.5 * sin(dot(p, vec3(-0.4, 0.8, 1.0)) * wave_frequency * 1.7 - t * 1.3);
	wave += 0.25 * sin(dot(p, vec3(0.6, -1.0, 0.5)) * wave_frequency * 2.5 + t * 0.8);
	// Amplitude is a fraction of the radius, so expansion also scales the waves.
	VERTEX = p * (1.0 + wave_amplitude * wave / 1.75);
}

void fragment() {
	vec3 p = normalize(surface_direction);
	float field_a = surface_noise(noise_texture, p, spot_scale, TIME * spot_velocity_a);
	float field_b = surface_noise(noise_texture_b, p, spot_scale, TIME * spot_velocity_b);
	// The unit spherical direction supplies a continuous phase offset, including
	// across the longitude seam and at the poles. Repeated texture regions no
	// longer switch between A and B in lockstep.
	float phase_offset = TAU * spot_phase_variation * (
		dot(p, vec3(1.3, 1.7, -1.1))
		+ 0.3 * sin(dot(p, vec3(3.7, -2.9, 4.1)))
	);
	// A -> B -> A over one period, with different timing around the sphere.
	float blend = 0.5 + 0.5 * sin(TAU * TIME / max(spot_blend_period, 0.001) - PI * 0.5 + phase_offset);
	float spots = mix(field_a, field_b, blend);
	float darkness = smoothstep(spot_threshold - spot_softness * 0.5, spot_threshold + spot_softness * 0.5, spots);
	vec3 surface_color = mix(yellow_color.rgb, red_color.rgb, color_progress);
	ALBEDO = mix(surface_color, spot_color.rgb, darkness * spot_strength) * max(1.0, explosion_strength);
}
