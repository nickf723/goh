shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;
uniform vec4 shallow_color : source_color;
uniform vec4 deep_color : source_color;
uniform vec4 foam_color : source_color;
uniform vec4 electrical_color : source_color;
uniform vec4 hot_color : source_color;
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
varying float crest;
void vertex(){
 vec2 p=VERTEX.xz; float t=TIME*wave_speed;
 float a=sin(p.x*large_wave_scale+t); float b=cos(p.y*large_wave_scale-t*0.7);
 float c=sin((p.x+p.y)*small_wave_scale-t*1.5);
 crest=a*0.45+b*0.35+c*0.2;
 VERTEX.y+=crest*wave_amplitude*(1.0+turbulence*0.4);
 NORMAL=normalize(vec3(-cos(p.x*large_wave_scale+t)*normal_strength,1.0,-sin(p.y*large_wave_scale-t)*normal_strength));
}
void fragment(){
 float f=pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),3.0);
 vec2 d=normalize(flow_direction+vec2(0.0001));
 float band=0.5+0.5*sin(dot(UV,d)*flow_band_scale-TIME*flow_speed);
 float foam=smoothstep(0.55,1.0,crest)*(0.15+band*flow_band_strength);
 float pulse=electrical_intensity*(0.55+0.45*sin(TIME*18.0+UV.x*40.0));
 vec3 col=mix(deep_color.rgb,shallow_color.rgb,0.4+f*0.5);
 col=mix(col,hot_color.rgb,heat_intensity*0.25);
 col=mix(col,foam_color.rgb,foam);
 col=mix(col,electrical_color.rgb,pulse*0.7);
 ALBEDO=col; EMISSION=col*surface_emission+foam_color.rgb*foam*0.25+electrical_color.rgb*pulse*2.0;
 ROUGHNESS=surface_roughness; SPECULAR=surface_specular;
 ALPHA=clamp(mix(shallow_color.a,deep_color.a,f*0.55)+foam*0.12,0.0,1.0)*visibility;
}
