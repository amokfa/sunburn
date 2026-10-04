shader_type spatial;

uniform float sway_amplitude = 0.001;
uniform float sway_speed = 1.5;

void vertex() {
    vec3 origin = MODEL_MATRIX[3].xyz;
    float seed = fract(sin(dot(origin, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
    float phase = seed * 6.283185;
    float height_weight = pow(clamp(VERTEX.y / 0.02, 0.0, 1.0), 2.0);
    float time = TIME * sway_speed * mix(0.8, 1.2, seed);
    VERTEX.x += sin(time + phase) * sway_amplitude * height_weight;
    VERTEX.z += sin(time * 0.73 + phase + 1.7) * sway_amplitude * height_weight * 0.6;
}

void fragment() {
    ALBEDO = COLOR.rgb;
    ROUGHNESS = 1.0;
}
