shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

uniform vec4 body_color : source_color = vec4(0.12, 0.44, 0.37, 0.64);
uniform vec4 highlight_color : source_color = vec4(0.58, 0.86, 0.72, 0.78);
uniform vec4 foam_color : source_color = vec4(0.72, 0.92, 0.78, 0.86);
uniform vec4 shadow_color : source_color = vec4(0.025, 0.12, 0.11, 0.58);
uniform vec4 reflection_tint : source_color = vec4(0.48, 0.72, 0.62, 1.0);

uniform float flow_speed = 1.25;
uniform float streak_scale = 26.0;
uniform float cross_streak_scale = 7.0;
uniform float turbulence = 0.34;
uniform float flutter_amplitude = 0.035;
uniform float flutter_scale = 10.0;
uniform float refraction_strength = 0.65;
uniform float refraction_mix = 0.42;
uniform float edge_foam_strength = 0.55;
uniform float terminal_foam_strength = 0.72;
uniform float fresnel_strength = 0.18;
uniform float surface_roughness = 0.14;
uniform float surface_specular = 0.78;
uniform float surface_emission = 0.035;
uniform float visibility = 1.0;

varying float flutter_wave;

void vertex() {
 float vertical_phase = UV.y * flutter_scale - TIME * flow_speed * 1.8;
 float broad = sin(vertical_phase + UV.x * 3.1);
 float fine = sin(vertical_phase * 1.93 + UV.x * 11.0 + 1.7);
 flutter_wave = broad * 0.72 + fine * 0.28;
 VERTEX.x += flutter_wave * flutter_amplitude;
 NORMAL = normalize(NORMAL + vec3(flutter_wave * turbulence * 0.18, 0.0, 0.0));
}

void fragment() {
 float t = TIME * flow_speed;
 float vertical_streak = 0.5 + 0.5 * sin(UV.y * streak_scale + t * 3.7 + sin(UV.x * cross_streak_scale) * 1.4);
 float fine_streak = 0.5 + 0.5 * sin(UV.y * streak_scale * 2.15 + t * 6.1 + UV.x * 17.0);
 float breakup = clamp(vertical_streak * 0.72 + fine_streak * 0.28, 0.0, 1.0);

 float left_edge = smoothstep(0.0, 0.13, UV.x);
 float right_edge = smoothstep(0.0, 0.13, 1.0 - UV.x);
 float edge_mask = 1.0 - min(left_edge, right_edge);
 float terminal_mask = smoothstep(0.72, 1.0, UV.y);
 float foam = clamp(
  edge_mask * edge_foam_strength * (0.70 + breakup * 0.30)
  + terminal_mask * terminal_foam_strength * (0.58 + fine_streak * 0.42),
  0.0,
  1.0
 );

 vec3 surface_normal = normalize(NORMAL + vec3(
  (breakup - 0.5) * turbulence * 0.20,
  (fine_streak - 0.5) * turbulence * 0.10,
  flutter_wave * turbulence * 0.12
 ));
 float fresnel = pow(1.0 - clamp(dot(surface_normal, normalize(VIEW)), 0.0, 1.0), 3.0);

 vec2 pixel_size = 1.0 / max(VIEWPORT_SIZE, vec2(1.0));
 vec2 distortion = vec2(
  (breakup - 0.5) + surface_normal.x,
  (fine_streak - 0.5) * 0.35
 ) * refraction_strength * 9.0 * pixel_size;
 vec2 refracted_uv = clamp(SCREEN_UV + distortion, vec2(0.001), vec2(0.999));
 vec3 refracted_scene = textureLod(screen_texture, refracted_uv, 0.0).rgb;

 vec3 water_color = mix(shadow_color.rgb, body_color.rgb, 0.40 + breakup * 0.48);
 water_color = mix(water_color, highlight_color.rgb, fine_streak * 0.18);
 vec3 col = mix(water_color, refracted_scene, clamp(refraction_mix, 0.0, 0.82));
 col = mix(col, reflection_tint.rgb, fresnel * fresnel_strength);
 col = mix(col, foam_color.rgb, foam);

 ALBEDO = col;
 EMISSION = col * surface_emission + foam_color.rgb * foam * 0.08;
 ROUGHNESS = surface_roughness;
 SPECULAR = surface_specular;
 ALPHA = clamp(mix(body_color.a, highlight_color.a, breakup * 0.34) + foam * 0.14, 0.0, 1.0) * visibility;
}
