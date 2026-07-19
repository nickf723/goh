shader_type spatial;
render_mode blend_mix, depth_draw_alpha_prepass, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.08, 0.62, 0.88, 0.70);
uniform vec4 deep_color : source_color = vec4(0.012, 0.10, 0.30, 0.88);
uniform vec4 foam_color : source_color = vec4(0.72, 0.96, 1.0, 0.92);
uniform vec4 electrical_color : source_color = vec4(0.45, 0.65, 1.0, 1.0);
uniform vec4 hot_color : source_color = vec4(0.36, 0.78, 0.94, 1.0);

uniform float wave_amplitude = 0.09;
uniform float wave_speed = 1.0;
uniform float large_wave_scale = 0.75;
uniform float small_wave_scale = 2.4;
uniform float normal_strength = 0.52;
uniform vec2 flow_direction = vec2(1.0, 0.0);
uniform float flow_speed = 0.0;
uniform float flow_band_scale = 34.0;
uniform float flow_band_strength = 0.16;
uniform float surface_emission = 0.12;
uniform float surface_roughness = 0.08;
uniform float surface_specular = 0.92;
uniform float turbulence = 0.0;
uniform float electrical_intensity = 0.0;
uniform float heat_intensity = 0.0;
uniform float visibility = 1.0;

varying float crest_value;
varying float flow_value;

void vertex() {
	vec2 p = VERTEX.xz;
	vec2 flow_dir = normalize(flow_direction + vec2(0.0001));
	float time_value = TIME * wave_speed;
	float large_a = sin((p.x * 0.88 + p.y * 0.34) * large_wave_scale + time_value);
	float large_b = cos((p.y * 0.76 - p.x * 0.28) * large_wave_scale * 1.18 - time_value * 0.74);
	float small_a = sin((p.x + p.y * 0.52) * small_wave_scale - time_value * 1.62);
	float flow_phase = dot(p, flow_dir) * (1.35 + flow_speed * 0.18) - TIME * (0.55 + flow_speed);
	float flow_wave = sin(flow_phase);
	float combined = large_a * 0.46 + large_b * 0.34 + small_a * 0.14 + flow_wave * 0.20;
	combined += sin((p.x - p.y) * 3.4 + TIME * 2.5) * turbulence * 0.12;
	VERTEX.y += combined * wave_amplitude * (1.0 + turbulence * 0.45);
	crest_value = combined;
	flow_value = flow_wave;

	float dx = cos((p.x * 0.88 + p.y * 0.34) * large_wave_scale + time_value) * 0.88 * large_wave_scale * 0.46;
	dx += sin((p.y * 0.76 - p.x * 0.28) * large_wave_scale * 1.18 - time_value * 0.74) * 0.28 * large_wave_scale * 1.18 * 0.34;
	dx += cos((p.x + p.y * 0.52) * small_wave_scale - time_value * 1.62) * small_wave_scale * 0.14;
	float dz = cos((p.x * 0.88 + p.y * 0.34) * large_wave_scale + time_value) * 0.34 * large_wave_scale * 0.46;
	dz -= sin((p.y * 0.76 - p.x * 0.28) * large_wave_scale * 1.18 - time_value * 0.74) * 0.76 * large_wave_scale * 1.18 * 0.34;
	dz += cos((p.x + p.y * 0.52) * small_wave_scale - time_value * 1.62) * 0.52 * small_wave_scale * 0.14;
	NORMAL = normalize(vec3(-dx * normal_strength, 1.0, -dz * normal_strength));
}

void fragment() {
	vec3 view_dir = normalize(VIEW);
	float facing = clamp(dot(normalize(NORMAL), view_dir), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 3.25);
	vec2 flow_dir = normalize(flow_direction + vec2(0.0001));
	float bands = 0.5 + 0.5 * sin(dot(UV - vec2(TIME * flow_speed * 0.012), flow_dir) * flow_band_scale);
	float crest = smoothstep(0.58, 1.1, crest_value);
	float foam = crest * (0.18 + bands * flow_band_strength) * (1.0 + turbulence * 0.65);
	float electrical_pulse = electrical_intensity * (0.55 + 0.45 * sin(TIME * 18.0 + UV.x * 41.0 + UV.y * 29.0));
	float heat_shimmer = heat_intensity * (0.5 + 0.5 * sin(TIME * 3.8 + UV.x * 17.0 - UV.y * 13.0));

	vec3 base_color = mix(deep_color.rgb, shallow_color.rgb, 0.38 + fresnel * 0.48 + crest * 0.08);
	base_color = mix(base_color, hot_color.rgb, heat_intensity * 0.24 + heat_shimmer * 0.08);
	base_color = mix(base_color, foam_color.rgb, clamp(foam, 0.0, 0.62));
	base_color = mix(base_color, electrical_color.rgb, clamp(electrical_pulse, 0.0, 0.78));

	ALBEDO = base_color;
	EMISSION = base_color * surface_emission;
	EMISSION += foam_color.rgb * foam * 0.28;
	EMISSION += electrical_color.rgb * electrical_pulse * 2.2;
	ROUGHNESS = clamp(surface_roughness + heat_intensity * 0.10 - electrical_intensity * 0.03, 0.02, 0.42);
	SPECULAR = clamp(surface_specular, 0.0, 1.0);
	ALPHA = clamp(mix(shallow_color.a, deep_color.a, fresnel * 0.58) + foam * 0.16, 0.0, 1.0) * visibility;
}
