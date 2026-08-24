shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 turf_color : source_color = vec4(0.18, 0.32, 0.08, 1.0);
uniform vec4 turf_shadow_color : source_color = vec4(0.055, 0.105, 0.045, 1.0);
uniform vec4 dry_turf_color : source_color = vec4(0.46, 0.40, 0.13, 1.0);
uniform vec4 soil_dark_color : source_color = vec4(0.12, 0.055, 0.022, 1.0);
uniform vec4 soil_light_color : source_color = vec4(0.36, 0.16, 0.055, 1.0);
uniform vec4 stone_color : source_color = vec4(0.30, 0.27, 0.21, 1.0);
uniform vec4 rim_color : source_color = vec4(0.20, 0.36, 0.48, 1.0);

uniform vec2 location_offset = vec2(0.0);
uniform float domain_warp_scale : hint_range(0.005, 0.20, 0.001) = 0.035;
uniform float domain_warp_strength : hint_range(0.0, 12.0, 0.1) = 4.5;
uniform float turf_scale : hint_range(0.01, 0.60, 0.005) = 0.14;
uniform float soil_patch_scale : hint_range(0.01, 0.40, 0.005) = 0.065;
uniform float micro_detail_scale : hint_range(0.20, 8.0, 0.05) = 1.35;
uniform float dryness : hint_range(0.0, 1.0, 0.01) = 0.28;
uniform float soil_amount : hint_range(0.0, 1.5, 0.01) = 0.82;
uniform float soil_threshold : hint_range(0.0, 1.0, 0.01) = 0.56;
uniform float soil_softness : hint_range(0.01, 0.35, 0.01) = 0.12;
uniform float slope_soil_bias : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform float micro_color_strength : hint_range(0.0, 0.30, 0.005) = 0.075;

uniform float pebble_scale : hint_range(0.25, 12.0, 0.05) = 2.5;
uniform float pebble_amount : hint_range(0.0, 1.0, 0.01) = 0.18;
uniform float pebble_edge_softness : hint_range(0.005, 0.20, 0.005) = 0.045;

uniform bool path_enabled = false;
uniform vec2 path_direction = vec2(1.0, 0.0);
uniform vec2 path_origin = vec2(0.0);
uniform float path_half_width : hint_range(0.25, 20.0, 0.05) = 2.2;
uniform float path_edge_softness : hint_range(0.05, 5.0, 0.05) = 0.75;
uniform float path_wobble_scale : hint_range(0.005, 0.30, 0.005) = 0.045;
uniform float path_wobble_strength : hint_range(0.0, 8.0, 0.05) = 2.0;
uniform float path_soil_amount : hint_range(0.0, 1.0, 0.01) = 0.92;

uniform float normal_sample_distance : hint_range(0.005, 0.30, 0.005) = 0.05;
uniform float normal_strength : hint_range(0.0, 2.0, 0.01) = 0.30;
uniform float roughness_turf : hint_range(0.0, 1.0, 0.01) = 0.83;
uniform float roughness_soil : hint_range(0.0, 1.0, 0.01) = 0.91;
uniform float roughness_stone : hint_range(0.0, 1.0, 0.01) = 0.72;
uniform float saturation_boost : hint_range(0.0, 2.0, 0.01) = 1.12;
uniform float rim_intensity : hint_range(0.0, 1.0, 0.01) = 0.07;
uniform float rim_power : hint_range(0.5, 8.0, 0.1) = 3.3;

varying vec3 location_world_position;
varying vec3 location_world_normal;

float hash_value(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453123);
}

vec2 hash_pair(vec2 point) {
	vec2 hashed = vec2(
		dot(point, vec2(127.1, 311.7)),
		dot(point, vec2(269.5, 183.3))
	);
	return fract(sin(hashed) * 43758.5453123);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	vec2 blend = local * local * (3.0 - 2.0 * local);
	float lower_left = hash_value(cell);
	float lower_right = hash_value(cell + vec2(1.0, 0.0));
	float upper_left = hash_value(cell + vec2(0.0, 1.0));
	float upper_right = hash_value(cell + vec2(1.0, 1.0));
	return mix(
		mix(lower_left, lower_right, blend.x),
		mix(upper_left, upper_right, blend.x),
		blend.y
	);
}

float location_fbm(vec2 point) {
	float total = 0.0;
	float amplitude = 0.54;
	mat2 turn = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
	for (int octave = 0; octave < 4; octave++) {
		total += value_noise(point) * amplitude;
		point = turn * point * 2.03 + vec2(7.1, 3.7);
		amplitude *= 0.50;
	}
	return total;
}

vec2 warp_location_coordinates(vec2 world_coordinates) {
	vec2 warp_coordinates = world_coordinates * domain_warp_scale;
	vec2 warp = vec2(
		value_noise(warp_coordinates + vec2(13.2, 2.8)),
		value_noise(warp_coordinates + vec2(-4.7, 19.1))
	) * 2.0 - 1.0;
	return world_coordinates + warp * domain_warp_strength;
}

float cellular_spots(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	float nearest = 1.0;
	for (int y_index = -1; y_index <= 1; y_index++) {
		for (int x_index = -1; x_index <= 1; x_index++) {
			vec2 neighbor = vec2(float(x_index), float(y_index));
			vec2 feature = neighbor + hash_pair(cell + neighbor);
			nearest = min(nearest, length(feature - local));
		}
	}
	return 1.0 - smoothstep(0.10, 0.10 + pebble_edge_softness, nearest);
}

float path_mask(vec2 world_coordinates) {
	if (!path_enabled) {
		return 0.0;
	}
	vec2 direction = normalize(path_direction + vec2(0.0001, 0.0));
	vec2 perpendicular = vec2(-direction.y, direction.x);
	vec2 relative = world_coordinates - path_origin;
	float forward_distance = dot(relative, direction);
	float side_distance = dot(relative, perpendicular);
	float wobble = (location_fbm(vec2(forward_distance * path_wobble_scale, 31.7)) * 2.0 - 1.0) * path_wobble_strength;
	return 1.0 - smoothstep(path_half_width, path_half_width + path_edge_softness, abs(side_distance - wobble));
}

float terrain_relief(vec2 world_coordinates) {
	float soil_relief = value_noise(
		world_coordinates * soil_patch_scale * 2.2 + vec2(9.1, -2.4)
	) - 0.5;
	float detail = value_noise(
		world_coordinates * micro_detail_scale + vec2(-17.0, 8.0)
	) - 0.5;
	float grain = value_noise(
		world_coordinates * micro_detail_scale * 3.7 + vec2(3.8, 14.1)
	) - 0.5;
	return detail * 0.28 + grain * 0.09 - soil_relief * 0.08;
}

vec3 apply_saturation(vec3 color, float amount) {
	float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
	return mix(vec3(luminance), color, amount);
}

void vertex() {
	location_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	location_world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec2 world_coordinates = location_world_position.xz + location_offset;
	vec2 warped_coordinates = warp_location_coordinates(world_coordinates);
	float broad_turf = location_fbm(warped_coordinates * turf_scale);
	float soil_field = location_fbm(warped_coordinates * soil_patch_scale + vec2(9.1, -2.4));
	soil_field = mix(soil_field, value_noise(warped_coordinates * soil_patch_scale * 2.65 - vec2(4.0, 7.0)), 0.30);
	float micro_detail = location_fbm(warped_coordinates * micro_detail_scale + vec2(-17.0, 8.0));
	float upwardness = clamp(dot(normalize(location_world_normal), vec3(0.0, 1.0, 0.0)), 0.0, 1.0);
	float slope = 1.0 - upwardness;

	float patch_mask = smoothstep(
		soil_threshold - soil_softness,
		soil_threshold + soil_softness,
		soil_field + slope * slope_soil_bias
	) * soil_amount;
	float worn_path = path_mask(world_coordinates);
	float soil_mask = clamp(max(patch_mask, worn_path * path_soil_amount), 0.0, 1.0);
	float dry_mask = smoothstep(0.47, 0.82, broad_turf + (micro_detail - 0.5) * 0.24) * dryness;
	float pebble_mask = cellular_spots(warped_coordinates * pebble_scale) * pebble_amount * smoothstep(0.16, 0.66, soil_mask);

	vec3 turf = mix(turf_shadow_color.rgb, turf_color.rgb, smoothstep(0.20, 0.84, broad_turf));
	turf = mix(turf, dry_turf_color.rgb, dry_mask);
	vec3 soil = mix(soil_dark_color.rgb, soil_light_color.rgb, smoothstep(0.20, 0.80, micro_detail));
	vec3 surface_color = mix(turf, soil, soil_mask);
	surface_color = mix(surface_color, stone_color.rgb, pebble_mask);
	surface_color *= 1.0 + (micro_detail - 0.5) * micro_color_strength;
	ALBEDO = apply_saturation(surface_color, saturation_boost);

	float sample_distance = max(normal_sample_distance, 0.001);
	float center_height = terrain_relief(world_coordinates);
	float x_height = terrain_relief(world_coordinates + vec2(sample_distance, 0.0));
	float y_height = terrain_relief(world_coordinates + vec2(0.0, sample_distance));
	vec2 gradient = vec2(x_height - center_height, y_height - center_height) / sample_distance;
	vec3 tangent_normal = normalize(vec3(-gradient.x * normal_strength, -gradient.y * normal_strength, 1.0));
	NORMAL_MAP = tangent_normal * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;

	ROUGHNESS = mix(roughness_turf, roughness_soil, soil_mask);
	ROUGHNESS = mix(ROUGHNESS, roughness_stone, pebble_mask);
	METALLIC = 0.0;
	SPECULAR = 0.19;

	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), rim_power);
	EMISSION = rim_color.rgb * rim * rim_intensity;
}
