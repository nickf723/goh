shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, unshaded;

uniform vec4 water_color : source_color = vec4(0.24, 0.72, 1.0, 0.72);
uniform vec4 foam_color : source_color = vec4(0.78, 0.97, 1.0, 0.94);
uniform float flow_speed = 1.0;
uniform float turbulence = 0.35;
uniform float emission_strength = 0.55;

void vertex() {
	float phase = UV.y * 18.0 - TIME * flow_speed * 4.2;
	VERTEX.x += sin(phase + UV.x * 7.0) * 0.025;
	VERTEX.z += sin(phase * 0.73 + UV.x * 9.0) * turbulence * 0.025;
}

void fragment() {
	float a = 0.5 + 0.5 * sin(UV.x * 31.0 + UV.y * 13.0 - TIME * flow_speed * 3.6);
	float b = 0.5 + 0.5 * sin(UV.x * 47.0 - UV.y * 8.0 + TIME * flow_speed * 2.4);
	float streak = smoothstep(0.2, 0.9, a * 0.65 + b * 0.35);
	float edge = smoothstep(0.0, 0.12, UV.x) * smoothstep(0.0, 0.12, 1.0 - UV.x);
	float foam = smoothstep(0.78, 1.0, UV.y) + smoothstep(0.24, 0.0, UV.y) * 0.35;
	vec3 color = mix(water_color.rgb, foam_color.rgb, clamp(streak * 0.42 + foam * 0.3, 0.0, 0.82));
	ALBEDO = color;
	EMISSION = color * emission_strength;
	ALPHA = water_color.a * edge * (0.55 + streak * 0.45);
}
