shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 inner_color : source_color = vec4(1.0, 0.96, 0.58, 1.0);
uniform vec4 body_color : source_color = vec4(1.0, 0.32, 0.03, 0.9);
uniform vec4 fringe_color : source_color = vec4(0.65, 0.03, 0.01, 0.4);
uniform float intensity = 1.0;
uniform float seed = 0.0;
uniform float sway_strength = 0.25;
uniform vec3 wind_velocity = vec3(0.0);
uniform float time_scale = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	float height = clamp(UV.y, 0.0, 1.0);
	float t = TIME * time_scale + seed * 11.7;
	float curl = sin(t * 2.2 + height * 8.0 + seed) * 0.55;
	curl += sin(t * 3.7 + height * 13.0 + seed * 2.1) * 0.24;
	vec2 wind = wind_velocity.xz;
	VERTEX.x += (curl * sway_strength + wind.x * height * 0.055) * height;
	VERTEX.z += (cos(t * 1.9 + height * 9.0 + seed) * sway_strength * 0.35 + wind.y * height * 0.055) * height;
	VERTEX.xz *= mix(1.0, 0.12, pow(height, 1.4));
}

void fragment() {
	float height = clamp(UV.y, 0.0, 1.0);
	float centered = abs(UV.x - 0.5) * 2.0;
	float t = TIME * time_scale + seed * 7.3;
	float n = value_noise(vec2(UV.x * 6.0 + seed, UV.y * 9.0 - t * 2.4));
	float edge = 1.0 - smoothstep(0.22 + n * 0.24, 0.92, centered);
	float base_fade = smoothstep(0.0, 0.08, height);
	float tip_fade = 1.0 - smoothstep(0.62 + n * 0.24, 1.0, height);
	float shape = edge * base_fade * tip_fade;
	float heat = clamp((1.0 - height) * 1.25 + n * 0.35, 0.0, 1.0);
	vec3 color = mix(fringe_color.rgb, body_color.rgb, smoothstep(0.08, 0.55, heat));
	color = mix(color, inner_color.rgb, smoothstep(0.52, 0.92, heat));
	float alpha = shape * mix(0.45, 1.0, n) * clamp(intensity, 0.0, 3.0);
	ALBEDO = color;
	EMISSION = color * (3.0 + intensity * 4.0);
	ALPHA = clamp(alpha, 0.0, 1.0);
}
