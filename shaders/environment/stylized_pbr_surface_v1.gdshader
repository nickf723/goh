shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.34, 0.39, 0.38, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.16, 0.24, 0.26, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_albedo_texture = false;
uniform vec2 uv_scale = vec2(1.0, 1.0);

uniform float broad_variation_scale : hint_range(0.05, 4.0, 0.05) = 0.7;
uniform float broad_variation_strength : hint_range(0.0, 0.5, 0.01) = 0.12;
uniform float saturation : hint_range(0.0, 2.0, 0.01) = 1.15;

uniform sampler2D roughness_texture : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_roughness_texture = false;
uniform float roughness_value : hint_range(0.04, 1.0, 0.01) = 0.72;
uniform sampler2D metallic_texture : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_metallic_texture = false;
uniform float metallic_value : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float dielectric_specular : hint_range(0.02, 0.16, 0.005) = 0.04;

uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_normal_texture = false;
uniform float normal_strength : hint_range(0.0, 2.0, 0.01) = 1.0;

uniform float band_midpoint : hint_range(0.0, 1.0, 0.01) = 0.28;
uniform float band_highlight : hint_range(0.0, 1.0, 0.01) = 0.68;
uniform float band_softness : hint_range(0.01, 0.35, 0.01) = 0.1;
uniform float shadow_band_level : hint_range(0.0, 1.0, 0.01) = 0.3;
uniform float middle_band_level : hint_range(0.0, 1.0, 0.01) = 0.68;

uniform vec4 rim_color : source_color = vec4(0.24, 0.48, 0.78, 1.0);
uniform float rim_intensity : hint_range(0.0, 2.0, 0.01) = 0.24;
uniform float rim_power : hint_range(0.5, 8.0, 0.1) = 3.2;

varying vec3 world_position;

float broad_surface_wave(vec3 position_value) {
	float primary = sin(dot(position_value, vec3(0.81, 0.37, 0.63)) * broad_variation_scale);
	float secondary = sin(dot(position_value, vec3(-0.29, 0.91, 0.42)) * broad_variation_scale * 1.73 + 1.7);
	return clamp(0.5 + primary * 0.31 + secondary * 0.19, 0.0, 1.0);
}

vec3 apply_saturation(vec3 color_value, float amount) {
	float luminance = dot(color_value, vec3(0.2126, 0.7152, 0.0722));
	return mix(vec3(luminance), color_value, amount);
}

float distribution_ggx(vec3 normal_value, vec3 halfway_value, float roughness) {
	float alpha = max(roughness * roughness, 0.0025);
	float alpha_squared = alpha * alpha;
	float normal_halfway = max(dot(normal_value, halfway_value), 0.0);
	float normal_halfway_squared = normal_halfway * normal_halfway;
	float denominator = normal_halfway_squared * (alpha_squared - 1.0) + 1.0;
	return alpha_squared / max(PI * denominator * denominator, 0.0001);
}

float geometry_schlick_ggx(float normal_direction, float roughness) {
	float radius = roughness + 1.0;
	float k = (radius * radius) / 8.0;
	return normal_direction / max(normal_direction * (1.0 - k) + k, 0.0001);
}

float geometry_smith(vec3 normal_value, vec3 view_value, vec3 light_value, float roughness) {
	float normal_view = max(dot(normal_value, view_value), 0.0);
	float normal_light = max(dot(normal_value, light_value), 0.0);
	return geometry_schlick_ggx(normal_view, roughness) * geometry_schlick_ggx(normal_light, roughness);
}

vec3 fresnel_schlick(float cosine_value, vec3 reflectance_zero) {
	float fresnel_weight = pow(clamp(1.0 - cosine_value, 0.0, 1.0), 5.0);
	return reflectance_zero + (vec3(1.0) - reflectance_zero) * fresnel_weight;
}

float painterly_diffuse_band(float normal_light) {
	float soft_width = max(band_softness, 0.001);
	float middle_transition = smoothstep(
		band_midpoint - soft_width,
		band_midpoint + soft_width,
		normal_light
	);
	float highlight_transition = smoothstep(
		band_highlight - soft_width,
		band_highlight + soft_width,
		normal_light
	);
	float band_value = mix(shadow_band_level, middle_band_level, middle_transition);
	band_value = mix(band_value, 1.0, highlight_transition);
	return band_value * step(0.0001, normal_light);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 sampled_uv = UV * uv_scale;
	vec3 texture_color = vec3(1.0);
	if (use_albedo_texture) {
		texture_color = texture(albedo_texture, sampled_uv).rgb;
	}

	float variation = broad_surface_wave(world_position);
	vec3 primary_surface = base_color.rgb * texture_color;
	vec3 secondary_surface = secondary_color.rgb * texture_color;
	vec3 surface_color = mix(
		primary_surface,
		secondary_surface,
		variation * broad_variation_strength
	);
	ALBEDO = max(apply_saturation(surface_color, saturation), vec3(0.0));

	float sampled_roughness = 1.0;
	if (use_roughness_texture) {
		sampled_roughness = texture(roughness_texture, sampled_uv).r;
	}
	ROUGHNESS = clamp(roughness_value * sampled_roughness, 0.04, 1.0);

	float sampled_metallic = 1.0;
	if (use_metallic_texture) {
		sampled_metallic = texture(metallic_texture, sampled_uv).r;
	}
	METALLIC = clamp(metallic_value * sampled_metallic, 0.0, 1.0);

	if (use_normal_texture) {
		NORMAL_MAP = texture(normal_texture, sampled_uv).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}

	float rim_fresnel = pow(
		clamp(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 0.0, 1.0),
		rim_power
	);
	EMISSION = rim_color.rgb * rim_color.a * rim_intensity * rim_fresnel;
}

void light() {
	vec3 normal_value = normalize(NORMAL);
	vec3 view_value = normalize(VIEW);
	vec3 light_value = normalize(LIGHT);
	vec3 halfway_value = normalize(view_value + light_value);
	float normal_light = max(dot(normal_value, light_value), 0.0);
	float normal_view = max(dot(normal_value, view_value), 0.0);
	float view_halfway = max(dot(view_value, halfway_value), 0.0);

	vec3 reflectance_zero = mix(
		vec3(dielectric_specular),
		ALBEDO,
		METALLIC
	);
	vec3 fresnel = fresnel_schlick(view_halfway, reflectance_zero);
	float distribution = distribution_ggx(
		normal_value,
		halfway_value,
		ROUGHNESS
	);
	float geometry = geometry_smith(
		normal_value,
		view_value,
		light_value,
		ROUGHNESS
	);
	vec3 specular_numerator = distribution * geometry * fresnel;
	vec3 specular = specular_numerator / max(
		4.0 * normal_view * normal_light,
		0.0001
	);

	vec3 diffuse_weight = (vec3(1.0) - fresnel) * (1.0 - METALLIC);
	float diffuse_band = painterly_diffuse_band(normal_light);
	DIFFUSE_LIGHT += (
		diffuse_weight
		* ALBEDO
		* diffuse_band
		* ATTENUATION
		* LIGHT_COLOR
		/ PI
	);
	SPECULAR_LIGHT += (
		specular
		* normal_light
		* ATTENUATION
		* LIGHT_COLOR
		* SPECULAR_AMOUNT
	);
}
