shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

uniform vec4 shallow_color : source_color;
uniform vec4 deep_color : source_color;
uniform vec4 foam_color : source_color;
uniform vec4 electrical_color : source_color;
uniform vec4 hot_color : source_color;
uniform vec4 reflection_tint : source_color = vec4(0.66, 0.86, 0.82, 1.0);

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

// Fidelity controls intentionally default to zero so existing FluidForceVolume
// scenes preserve their authored v1 presentation until they opt in.
uniform float refraction_strength = 0.0;
uniform float refraction_mix = 0.0;
uniform float depth_tint_distance = 0.0;
uniform float shoreline_depth = 0.0;
uniform float shoreline_foam_strength = 0.0;
uniform float fresnel_power = 3.0;
uniform float reflection_strength = 0.0;
uniform float micro_wave_strength = 0.0;
uniform float micro_wave_scale = 18.0;
uniform float micro_wave_speed = 0.8;
uniform float depth_alpha_strength = 0.0;
uniform float world_space_flow = 0.0;

varying float crest;
varying vec2 world_planar;

float linear_depth(float raw_depth, vec2 screen_uv) {
 vec3 ndc = vec3(screen_uv * 2.0 - 1.0, raw_depth);
 vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
 view.xyz /= max(abs(view.w), 0.00001);
 return max(-view.z, 0.0);
}

void vertex(){
 vec2 p = VERTEX.xz;
 float t = TIME * wave_speed;
 float a = sin(p.x * large_wave_scale + t);
 float b = cos(p.y * large_wave_scale - t * 0.7);
 float c = sin((p.x + p.y) * small_wave_scale - t * 1.5);
 crest = a * 0.45 + b * 0.35 + c * 0.2;
 VERTEX.y += crest * wave_amplitude * (1.0 + turbulence * 0.4);
 NORMAL = normalize(vec3(
  -cos(p.x * large_wave_scale + t) * normal_strength,
  1.0,
  -sin(p.y * large_wave_scale - t) * normal_strength
 ));
 world_planar = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment(){
 vec2 coordinate = mix(UV, world_planar, clamp(world_space_flow, 0.0, 1.0));
 vec2 d = normalize(flow_direction + vec2(0.0001));
 float flow_phase = dot(coordinate, d) * flow_band_scale - TIME * flow_speed;
 float band = 0.5 + 0.5 * sin(flow_phase);

 float micro_a = sin((coordinate.x * micro_wave_scale) + TIME * micro_wave_speed + coordinate.y * 3.7);
 float micro_b = cos((coordinate.y * micro_wave_scale * 0.83) - TIME * micro_wave_speed * 1.17 + coordinate.x * 4.9);
 vec3 surface_normal = normalize(NORMAL + vec3(
  micro_a * micro_wave_strength,
  0.0,
  micro_b * micro_wave_strength
 ));
 float fresnel = pow(
  1.0 - clamp(dot(surface_normal, normalize(VIEW)), 0.0, 1.0),
  max(fresnel_power, 0.05)
 );

 float scene_raw_depth = texture(depth_texture, SCREEN_UV).r;
 float scene_depth = linear_depth(scene_raw_depth, SCREEN_UV);
 float surface_depth = linear_depth(FRAGCOORD.z, SCREEN_UV);
 float thickness = max(scene_depth - surface_depth, 0.0);
 float depth_factor = 0.0;
 if (depth_tint_distance > 0.0001) {
  depth_factor = 1.0 - exp(-thickness / depth_tint_distance);
 }

 vec2 pixel_size = 1.0 / max(VIEWPORT_SIZE, vec2(1.0));
 vec2 distortion = surface_normal.xy * refraction_strength * (8.0 + band * 4.0) * pixel_size;
 vec2 refracted_uv = clamp(SCREEN_UV + distortion, vec2(0.001), vec2(0.999));
 vec3 refracted_scene = textureLod(screen_texture, refracted_uv, 0.0).rgb;

 float crest_foam = smoothstep(0.55, 1.0, crest) * (0.15 + band * flow_band_strength);
 float shoreline_foam = 0.0;
 if (shoreline_depth > 0.0001 && shoreline_foam_strength > 0.0001) {
  float shallow_contact = 1.0 - smoothstep(0.0, shoreline_depth, thickness);
  shoreline_foam = shallow_contact * shoreline_foam_strength * (0.72 + band * 0.28);
 }
 float foam = clamp(crest_foam + shoreline_foam, 0.0, 1.0);

 float pulse = electrical_intensity * (0.55 + 0.45 * sin(TIME * 18.0 + coordinate.x * 40.0));
 float legacy_mix = 0.4 + fresnel * 0.5;
 vec3 water_color = mix(deep_color.rgb, shallow_color.rgb, legacy_mix);
 if (depth_tint_distance > 0.0001) {
  water_color = mix(shallow_color.rgb, deep_color.rgb, depth_factor);
 }
 vec3 refracted_water = mix(refracted_scene, water_color, clamp(depth_factor * 0.72 + 0.18, 0.0, 1.0));
 vec3 col = mix(water_color, refracted_water, clamp(refraction_mix, 0.0, 1.0));
 col = mix(col, reflection_tint.rgb, fresnel * clamp(reflection_strength, 0.0, 1.0));
 col = mix(col, hot_color.rgb, heat_intensity * 0.25);
 col = mix(col, foam_color.rgb, foam);
 col = mix(col, electrical_color.rgb, pulse * 0.7);

 ALBEDO = col;
 EMISSION = (
  col * surface_emission
  + foam_color.rgb * foam * 0.25
  + electrical_color.rgb * pulse * 2.0
 );
 ROUGHNESS = clamp(surface_roughness + (1.0 - depth_factor) * micro_wave_strength * 0.12, 0.0, 1.0);
 SPECULAR = surface_specular;
 float base_alpha = mix(shallow_color.a, deep_color.a, fresnel * 0.55) + foam * 0.12;
 base_alpha += depth_factor * depth_alpha_strength;
 ALPHA = clamp(base_alpha, 0.0, 1.0) * visibility;
}
