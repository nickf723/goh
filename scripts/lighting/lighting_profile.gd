extends Resource
class_name LightingProfile

@export_group("Identity")
@export var profile_id: String = "neutral"
@export var display_name: String = "Neutral Lighting"

@export_group("Sky")
@export var sky_top_color: Color = Color(0.08, 0.12, 0.18, 1.0)
@export var sky_horizon_color: Color = Color(0.45, 0.40, 0.34, 1.0)
@export var ground_bottom_color: Color = Color(0.025, 0.03, 0.035, 1.0)
@export var ground_horizon_color: Color = Color(0.22, 0.20, 0.17, 1.0)
@export_range(0.0, 90.0, 0.1) var sky_sun_angle_max: float = 18.0
@export_range(0.001, 1.0, 0.001) var sky_sun_curve: float = 0.08
@export_range(0.0, 4.0, 0.01) var background_energy: float = 0.65

@export_group("Sun")
@export var sun_rotation_degrees: Vector3 = Vector3(-38.0, 20.0, 0.0)
@export var sun_color: Color = Color(1.0, 0.68, 0.42, 1.0)
@export_range(0.0, 8.0, 0.01) var sun_energy: float = 1.4
@export_range(0.0, 8.0, 0.01) var sun_volumetric_energy: float = 1.2
@export_range(10.0, 300.0, 1.0) var sun_shadow_distance: float = 100.0

@export_group("Fill")
@export var fill_rotation_degrees: Vector3 = Vector3(-62.0, 150.0, 0.0)
@export var fill_color: Color = Color(0.30, 0.46, 0.64, 1.0)
@export_range(0.0, 4.0, 0.01) var fill_energy: float = 0.32
@export_range(0.0, 4.0, 0.01) var fill_volumetric_energy: float = 0.12

@export_group("Ambient")
@export var ambient_color: Color = Color(0.30, 0.38, 0.44, 1.0)
@export_range(0.0, 4.0, 0.01) var ambient_energy: float = 0.50

@export_group("Exposure")
@export_range(0.05, 4.0, 0.01) var tonemap_exposure: float = 1.0
@export_range(0.1, 4.0, 0.01) var tonemap_white: float = 1.4
@export_range(0.05, 4.0, 0.01) var camera_exposure_multiplier: float = 1.0
@export var auto_exposure_enabled: bool = true
@export_range(0.01, 10.0, 0.01) var auto_exposure_speed: float = 0.65
@export_range(0.01, 4.0, 0.01) var auto_exposure_scale: float = 0.42
@export_range(0.0, 6400.0, 1.0) var auto_exposure_min_sensitivity: float = 60.0
@export_range(1.0, 6400.0, 1.0) var auto_exposure_max_sensitivity: float = 640.0

@export_group("Distance Fog")
@export var fog_enabled: bool = true
@export var fog_color: Color = Color(0.42, 0.43, 0.38, 1.0)
@export_range(0.0, 8.0, 0.01) var fog_light_energy: float = 0.55
@export_range(0.0, 0.2, 0.0001) var fog_density: float = 0.004
@export_range(-50.0, 50.0, 0.1) var fog_height: float = 3.0
@export_range(0.0, 2.0, 0.001) var fog_height_density: float = 0.06
@export_range(0.0, 1.0, 0.01) var fog_sun_scatter: float = 0.45
@export_range(0.0, 1.0, 0.01) var fog_sky_affect: float = 0.55

@export_group("Volumetric Fog")
@export var volumetric_fog_enabled: bool = true
@export_range(0.0, 0.2, 0.0001) var volumetric_fog_density: float = 0.014
@export var volumetric_fog_albedo: Color = Color(0.76, 0.76, 0.69, 1.0)
@export var volumetric_fog_emission: Color = Color(0.015, 0.018, 0.020, 1.0)
@export_range(0.0, 4.0, 0.01) var volumetric_fog_emission_energy: float = 0.05
@export_range(-1.0, 1.0, 0.01) var volumetric_fog_anisotropy: float = 0.55
@export_range(8.0, 256.0, 1.0) var volumetric_fog_length: float = 64.0
@export_range(0.5, 4.0, 0.01) var volumetric_fog_detail_spread: float = 1.8
@export_range(0.0, 1.0, 0.01) var volumetric_fog_ambient_inject: float = 0.28
@export_range(0.0, 4.0, 0.01) var volumetric_fog_gi_inject: float = 0.8
@export_range(0.0, 1.0, 0.01) var volumetric_fog_sky_affect: float = 0.75

@export_group("Screen Space")
@export var glow_enabled: bool = true
@export_range(0.0, 4.0, 0.01) var glow_intensity: float = 0.18
@export_range(0.0, 1.0, 0.01) var glow_bloom: float = 0.03
@export_range(0.0, 8.0, 0.01) var glow_hdr_threshold: float = 1.4
@export var ssao_enabled: bool = true
@export_range(0.0, 8.0, 0.01) var ssao_intensity: float = 1.65
@export_range(0.05, 10.0, 0.01) var ssao_radius: float = 2.2
@export var ssil_enabled: bool = true
@export_range(0.0, 8.0, 0.01) var ssil_intensity: float = 0.85
@export_range(0.1, 20.0, 0.1) var ssil_radius: float = 4.0
@export var ssr_enabled: bool = true
@export_range(8, 256, 1) var ssr_max_steps: int = 72

@export_group("Global Illumination")
@export var sdfgi_enabled: bool = true
@export_range(0.0, 4.0, 0.01) var sdfgi_energy: float = 0.88
@export_range(1, 8, 1) var sdfgi_cascades: int = 3
@export_range(0.05, 2.0, 0.01) var sdfgi_min_cell_size: float = 0.28
@export var sdfgi_use_occlusion: bool = true
@export var sdfgi_read_sky_light: bool = true


func get_debug_data() -> Dictionary:
	return {
		"lighting_profile": true,
		"profile_id": profile_id,
		"display_name": display_name,
		"auto_exposure": auto_exposure_enabled,
		"volumetric_fog": volumetric_fog_enabled,
		"sdfgi": sdfgi_enabled,
		"ssil": ssil_enabled,
		"ssr": ssr_enabled,
	}
