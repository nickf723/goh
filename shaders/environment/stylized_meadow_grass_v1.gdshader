shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.095, 0.245, 0.065, 1.0);
uniform vec4 tip_color : source_color = vec4(0.40, 0.57, 0.14, 1.0);
uniform vec4 rim_color : source_color = vec4(0.38, 0.58, 0.82, 1.0);
uniform vec4 sun_kiss_color : source_color = vec4(1.0, 0.62, 0.2, 1.0);

uniform vec2 wind_direction = vec2(0.84, 0.34);
uniform float wind_strength : hint_range(0.0, 0.8, 0.01) = 0.14;
uniform float wind_speed : hint_range(0.0, 4.0, 0.05) = 1.15;
uniform float wind_scale : hint_range(0.01, 1.0, 0.01) = 0.13;
uniform float gust_scale : hint_range(0.01, 1.0, 0.01) = 0.045;
uniform float gust_strength : hint_range(0.0, 1.0, 0.01) = 0.28;

uniform float saturation : hint_range(0.0, 2.0, 0.01) = 1.08;
uniform float roughness_value : hint_range(0.04, 1.0, 0.01) = 0.86;
uniform float rim_intensity : hint_range(0.0, 1.0, 0.01) = 0.085;
uniform float sun_kiss_intensity : hint_range(0.0, 0.5, 0.01) = 0.05;

varying float blade_height;
varying float color_variation;
varying float tip_flutter;

vec3 apply_saturation(vec3 color_value, float amount) {
	float luminance = dot(color_value, vec3(0.2126, 0.7152, 0.0722));
	return mix(vec3(luminance), color_value, amount);
}

void vertex() {
	blade_height = clamp(1.0 - UV.y, 0.0, 1.0);
	color_variation = INSTANCE_CUSTOM.r;
	float bend_variation = mix(0.72, 1.28, INSTANCE_CUSTOM.g);
	float phase = INSTANCE_CUSTOM.b * TAU;
	vec3 instance_origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec2 direction = normalize(wind_direction);

	float local_wave = sin(
		TIME * wind_speed
		+ dot(instance_origin.xz, vec2(0.73, 0.41)) * wind_scale
		+ phase
	);
	float cross_wave = sin(
		TIME * wind_speed * 1.37
		+ dot(instance_origin.xz, vec2(-0.31, 0.86)) * wind_scale * 0.73
		+ phase * 0.61
	);
	float broad_gust = sin(
		TIME * wind_speed * 0.34
		+ dot(instance_origin.xz, direction) * gust_scale
	);
	float bend = (
		local_wave * 0.62
		+ cross_wave * 0.24
		+ broad_gust * gust_strength
	);
	float height_weight = pow(blade_height, 1.65);
	VERTEX.xz += (
		direction
		* bend
		* wind_strength
		* bend_variation
		* height_weight
	);
	VERTEX.y -= abs(bend) * wind_strength * 0.08 * height_weight;
	tip_flutter = max(broad_gust, 0.0) * blade_height;
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	float gradient = smoothstep(0.0, 1.0, blade_height);
	vec3 surface_color = mix(base_color.rgb, tip_color.rgb, gradient);
	surface_color *= mix(0.88, 1.12, color_variation);
	ALBEDO = max(apply_saturation(surface_color, saturation), vec3(0.0));
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
	SPECULAR = 0.24;
	BACKLIGHT = sun_kiss_color.rgb * mix(0.055, 0.13, gradient);

	float rim_fresnel = pow(
		clamp(
			1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))),
			0.0,
			1.0
		),
		3.0
	);
	EMISSION = (
		rim_color.rgb * rim_intensity * rim_fresnel
		+ sun_kiss_color.rgb
		* sun_kiss_intensity
		* gradient
		* tip_flutter
	);
}
