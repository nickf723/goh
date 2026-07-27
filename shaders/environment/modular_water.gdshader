shader_type spatial;
render_mode blend_mix, depth_draw_alpha_prepass, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 deep_color : source_color = vec4(0.02, 0.10, 0.15, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.05, 0.30, 0.40, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.28, 0.78, 0.95, 1.0);
uniform float wave_scale : hint_range(0.1, 8.0, 0.1) = 1.2;
uniform float wave_speed : hint_range(0.0, 4.0, 0.05) = 0.65;
uniform float alpha_value : hint_range(0.0, 1.0, 0.01) = 0.72;
uniform float emission_strength : hint_range(0.0, 2.0, 0.05) = 0.22;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += (
		sin(VERTEX.x * wave_scale + TIME * wave_speed)
		+ cos(VERTEX.z * wave_scale * 0.78 - TIME * wave_speed * 0.83)
	) * 0.018;
}

void fragment() {
	float wave_a = 0.5 + 0.5 * sin((world_position.x + world_position.z) * wave_scale + TIME * wave_speed);
	float wave_b = 0.5 + 0.5 * cos((world_position.x - world_position.z) * wave_scale * 0.72 - TIME * wave_speed * 0.8);
	float blend_weight = clamp(wave_a * 0.62 + wave_b * 0.38, 0.0, 1.0);
	ALBEDO = mix(deep_color.rgb, shallow_color.rgb, blend_weight);
	EMISSION = highlight_color.rgb * emission_strength * smoothstep(0.72, 1.0, blend_weight);
	ROUGHNESS = 0.16;
	METALLIC = 0.06;
	ALPHA = alpha_value;
}
