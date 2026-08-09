extends Resource
class_name WaterPresentationProfile

@export var profile_id: String = "default_water"
@export var display_name: String = "Default Water"

@export_group("Shallow Water")
@export var stream_shallow_color: Color = Color(0.08, 0.48, 0.38, 0.72)
@export var stream_deep_color: Color = Color(0.018, 0.16, 0.16, 0.86)
@export var stream_foam_color: Color = Color(0.60, 0.84, 0.68, 0.78)
@export var stream_reflection_tint: Color = Color(0.52, 0.76, 0.64, 1.0)
@export_range(0.0, 0.25, 0.005) var stream_wave_amplitude: float = 0.025
@export_range(0.0, 4.0, 0.05) var stream_wave_speed: float = 0.82
@export_range(0.0, 4.0, 0.05) var stream_refraction_strength: float = 1.05
@export_range(0.0, 1.0, 0.01) var stream_refraction_mix: float = 0.34
@export_range(0.1, 10.0, 0.1) var stream_depth_tint_distance: float = 1.25
@export_range(0.01, 2.0, 0.01) var stream_shoreline_depth: float = 0.32
@export_range(0.0, 2.0, 0.01) var stream_shoreline_foam: float = 0.50
@export_range(0.0, 0.8, 0.01) var stream_micro_wave_strength: float = 0.17
@export_range(1.0, 60.0, 0.5) var stream_micro_wave_scale: float = 23.0
@export_range(0.0, 1.0, 0.01) var stream_reflection_strength: float = 0.16
@export_range(0.0, 1.0, 0.01) var stream_depth_alpha_strength: float = 0.10

@export_group("Deep Basin")
@export var basin_shallow_color: Color = Color(0.035, 0.31, 0.27, 0.76)
@export var basin_deep_color: Color = Color(0.005, 0.070, 0.078, 0.92)
@export var basin_foam_color: Color = Color(0.52, 0.78, 0.65, 0.72)
@export var basin_reflection_tint: Color = Color(0.46, 0.66, 0.58, 1.0)
@export_range(0.0, 0.25, 0.005) var basin_wave_amplitude: float = 0.018
@export_range(0.0, 4.0, 0.05) var basin_wave_speed: float = 0.46
@export_range(0.0, 4.0, 0.05) var basin_refraction_strength: float = 0.74
@export_range(0.0, 1.0, 0.01) var basin_refraction_mix: float = 0.26
@export_range(0.1, 20.0, 0.1) var basin_depth_tint_distance: float = 2.65
@export_range(0.01, 2.0, 0.01) var basin_shoreline_depth: float = 0.42
@export_range(0.0, 2.0, 0.01) var basin_shoreline_foam: float = 0.32
@export_range(0.0, 0.8, 0.01) var basin_micro_wave_strength: float = 0.11
@export_range(1.0, 60.0, 0.5) var basin_micro_wave_scale: float = 17.0
@export_range(0.0, 1.0, 0.01) var basin_reflection_strength: float = 0.22
@export_range(0.0, 1.0, 0.01) var basin_depth_alpha_strength: float = 0.18

@export_group("Shared Horizontal Water")
@export_range(0.01, 8.0, 0.01) var large_wave_scale: float = 0.78
@export_range(0.01, 12.0, 0.01) var small_wave_scale: float = 2.75
@export_range(0.0, 2.0, 0.01) var normal_strength: float = 0.42
@export_range(0.0, 1.0, 0.01) var surface_emission: float = 0.018
@export_range(0.0, 1.0, 0.01) var surface_roughness: float = 0.10
@export_range(0.0, 1.0, 0.01) var surface_specular: float = 0.92
@export_range(0.1, 8.0, 0.05) var fresnel_power: float = 3.4
@export_range(0.0, 6.0, 0.05) var default_flow_speed: float = 0.65
@export_range(1.0, 80.0, 0.5) var flow_band_scale: float = 30.0
@export_range(0.0, 1.0, 0.01) var flow_band_strength: float = 0.18

@export_group("Waterfall")
@export var waterfall_body_color: Color = Color(0.10, 0.42, 0.34, 0.64)
@export var waterfall_highlight_color: Color = Color(0.58, 0.86, 0.70, 0.78)
@export var waterfall_foam_color: Color = Color(0.72, 0.92, 0.78, 0.86)
@export var waterfall_shadow_color: Color = Color(0.020, 0.11, 0.10, 0.58)
@export var waterfall_reflection_tint: Color = Color(0.44, 0.68, 0.57, 1.0)
@export_range(0.0, 4.0, 0.05) var waterfall_flow_speed: float = 1.15
@export_range(1.0, 80.0, 0.5) var waterfall_streak_scale: float = 24.0
@export_range(1.0, 30.0, 0.5) var waterfall_cross_streak_scale: float = 6.0
@export_range(0.0, 2.0, 0.01) var waterfall_turbulence: float = 0.30
@export_range(0.0, 0.20, 0.002) var waterfall_flutter_amplitude: float = 0.024
@export_range(1.0, 40.0, 0.5) var waterfall_flutter_scale: float = 9.0
@export_range(0.0, 4.0, 0.05) var waterfall_refraction_strength: float = 0.58
@export_range(0.0, 1.0, 0.01) var waterfall_refraction_mix: float = 0.38
@export_range(0.0, 2.0, 0.01) var waterfall_edge_foam: float = 0.48
@export_range(0.0, 2.0, 0.01) var waterfall_terminal_foam: float = 0.68
@export_range(0.0, 1.0, 0.01) var waterfall_fresnel_strength: float = 0.16
@export_range(0.0, 1.0, 0.01) var waterfall_roughness: float = 0.14
@export_range(0.0, 1.0, 0.01) var waterfall_specular: float = 0.78
@export_range(0.0, 1.0, 0.01) var waterfall_emission: float = 0.025

func get_debug_data() -> Dictionary:
	return {
		"water_presentation_profile": true,
		"profile_id": profile_id,
		"stream_refraction": stream_refraction_strength,
		"stream_depth_tint": stream_depth_tint_distance,
		"basin_refraction": basin_refraction_strength,
		"basin_depth_tint": basin_depth_tint_distance,
		"waterfall_flow_speed": waterfall_flow_speed,
		"waterfall_refraction": waterfall_refraction_strength,
	}
