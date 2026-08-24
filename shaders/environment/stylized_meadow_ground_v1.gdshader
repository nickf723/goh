shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 meadow_green : source_color = vec4(0.115, 0.265, 0.075, 1.0);
uniform vec4 deep_green : source_color = vec4(0.035, 0.105, 0.045, 1.0);
uniform vec4 dry_grass : source_color = vec4(0.39, 0.31, 0.105, 1.0);
uniform vec4 meadow_soil : source_color = vec4(0.20, 0.105, 0.055, 1.0);
uniform vec4 fine_tint : source_color = vec4(0.52, 0.57, 0.20, 1.0);

uniform float broad_scale : hint_range(0.005, 0.12, 0.001) = 0.034;
uniform float mid_scale : hint_range(0.04, 0.5, 0.01) = 0.16;
uniform float fine_scale : hint_range(0.2, 2.0, 0.02) = 0.72;
uniform float dryness : hint_range(0.0, 1.0, 0.01) = 0.34;
uniform float soil_exposure : hint_range(0.0, 1.0, 0.01) = 0.2;
uniform float fine_detail_strength : hint_range(0.0, 0.25, 0.005) = 0.085;
uniform float saturation : hint_range(0.0, 2.0, 0.01) = 1.13;
uniform float roughness_min : hint_range(0.04, 1.0, 0.01) = 0.82;
uniform float roughness_max : hint_range(0.04, 1.0, 0.01) = 0.96;

uniform vec4 rim_color : source_color = vec4(0.22, 0.43, 0.68, 1.0);
uniform float rim_intensity : hint_range(0.0, 0.5, 0.005) = 0.055;
uniform float rim_power : hint_range(0.5, 8.0, 0.1) = 4.6;

varying vec3 meadow_world_position;
varying vec3 meadow_world_normal;

float hash_value(vec2 point_value) {
	return fract(
		sin(dot(point_value, vec2(127.1, 311.7))) * 43758.5453123
	);
}

float value_noise(vec2 point_value) {
	vec2 cell = floor(point_value);
	vec2 local = fract(point_value);
	vec2 blend = local * local * (3.0 - 2.0 * local);
	float a = hash_value(cell);
	float b = hash_value(cell + vec2(1.0, 0.0));
	float c = hash_value(cell + vec2(0.0, 1.0));
	float d = hash_value(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, blend.x), mix(c, d, blend.x), blend.y);
}

float meadow_fbm(vec2 point_value) {
	float total = value_noise(point_value) * 0.54;
	total += value_noise(point_value * 2.03 + vec2(7.3, 1.9)) * 0.27;
	total += value_noise(point_value * 4.11 + vec2(2.7, 9.2)) * 0.13;
	total += value_noise(point_value * 8.23 + vec2(5.1, 3.6)) * 0.06;
	return total;
}

vec3 apply_saturation(vec3 color_value, float amount) {
	float luminance = dot(color_value, vec3(0.2126, 0.7152, 0.0722));
	return mix(vec3(luminance), color_value, amount);
}

void vertex() {
	meadow_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	meadow_world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec2 world_coordinates = meadow_world_position.xz;
	float broad_pattern = meadow_fbm(
		world_coordinates * broad_scale + vec2(11.4, -6.7)
	);
	float medium_pattern = meadow_fbm(
		world_coordinates * mid_scale + vec2(-3.1, 8.6)
	);
	float fine_pattern = value_noise(
		world_coordinates * fine_scale + vec2(4.9, 13.2)
	);
	float slope = 1.0 - clamp(meadow_world_normal.y, 0.0, 1.0);

	vec3 green_surface = mix(
		deep_green.rgb,
		meadow_green.rgb,
		smoothstep(0.16, 0.82, medium_pattern)
	);
	float dry_mask = smoothstep(
		0.57,
		0.9,
		broad_pattern + medium_pattern * 0.24 + slope * 0.35
	) * dryness;
	float soil_mask = smoothstep(
		0.68,
		0.96,
		(1.0 - medium_pattern) * 0.62 + slope * 0.72
	) * soil_exposure;
	vec3 surface_color = mix(green_surface, dry_grass.rgb, dry_mask);
	surface_color = mix(surface_color, meadow_soil.rgb, soil_mask);
	float fine_signed = fine_pattern * 2.0 - 1.0;
	surface_color += (
		fine_tint.rgb - surface_color
	) * fine_signed * fine_detail_strength;
	ALBEDO = max(
		apply_saturation(surface_color, saturation),
		vec3(0.0)
	);
	ROUGHNESS = mix(
		roughness_min,
		roughness_max,
		clamp(0.32 + medium_pattern * 0.52 + soil_mask, 0.0, 1.0)
	);
	METALLIC = 0.0;
	SPECULAR = 0.2;

	float rim_fresnel = pow(
		clamp(
			1.0 - max(
				dot(normalize(NORMAL), normalize(VIEW)),
				0.0
			),
			0.0,
			1.0
		),
		rim_power
	);
	EMISSION = rim_color.rgb * rim_intensity * rim_fresnel;
}
