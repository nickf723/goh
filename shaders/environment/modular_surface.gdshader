shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.35, 0.36, 0.34, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.2, 0.22, 0.21, 1.0);
uniform float variation_scale : hint_range(0.05, 4.0, 0.05) = 0.65;
uniform float variation_strength : hint_range(0.0, 1.0, 0.01) = 0.18;
uniform float band_scale : hint_range(0.0, 4.0, 0.05) = 0.35;
uniform float roughness_value : hint_range(0.0, 1.0, 0.01) = 0.86;
uniform float metallic_value : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec4 emission_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float emission_strength : hint_range(0.0, 4.0, 0.05) = 0.0;
uniform float side_darkening : hint_range(0.0, 0.5, 0.01) = 0.08;

varying vec3 world_position;
varying vec3 world_normal;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float coarse = hash31(floor(world_position * variation_scale));
	float fine = hash31(floor(world_position * variation_scale * 3.7 + vec3(3.1, 7.3, 11.7)));
	float band = 0.5 + 0.5 * sin((world_position.x + world_position.z) * band_scale + coarse * 3.14159);
	float mix_weight = clamp(
		0.5
		+ (coarse - 0.5) * variation_strength * 2.0
		+ (fine - 0.5) * variation_strength
		+ (band - 0.5) * variation_strength * 0.35,
		0.0,
		1.0
	);
	vec3 surface_color = mix(base_color.rgb, secondary_color.rgb, mix_weight);
	float upward = clamp(dot(normalize(world_normal), vec3(0.0, 1.0, 0.0)), 0.0, 1.0);
	surface_color *= 1.0 - side_darkening * (1.0 - upward);
	ALBEDO = surface_color;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
	EMISSION = emission_tint.rgb * emission_strength;
}
