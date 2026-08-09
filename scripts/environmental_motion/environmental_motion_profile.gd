extends Resource
class_name EnvironmentalMotionProfile

@export var profile_id: String = "ambient_environment"
@export var display_name: String = "Ambient Environment Motion"

@export_group("Ambient Wind")
@export var ambient_direction: Vector3 = Vector3(0.86, 0.0, 0.32)
@export_range(0.0, 8.0, 0.01) var ambient_speed: float = 0.9
@export_range(0.0, 1.0, 0.01) var gust_strength: float = 0.28
@export_range(0.01, 4.0, 0.01) var gust_frequency: float = 0.22
@export_range(0.0, 2.0, 0.01) var gust_spatial_frequency: float = 0.085
@export_range(0.1, 12.0, 0.1) var reference_wind_speed: float = 1.6
@export_range(0.5, 20.0, 0.1) var maximum_visual_wind_speed: float = 5.5

@export_group("Systemic Airflow")
@export_range(0.0, 1.0, 0.01) var systemic_airflow_scale: float = 0.22
@export_range(0.02, 1.0, 0.01) var airflow_resample_interval: float = 0.14

@export_group("Local Interaction")
@export var local_interaction_enabled: bool = true
@export_range(0.1, 20.0, 0.1) var interaction_response_smoothing: float = 10.0
@export_range(0.0, 30.0, 0.1) var interaction_foliage_bend_degrees: float = 12.0
@export_range(0.0, 30.0, 0.1) var interaction_vine_bend_degrees: float = 8.5
@export_range(0.0, 0.35, 0.005) var interaction_foliage_displacement: float = 0.085
@export_range(0.0, 0.35, 0.005) var interaction_vine_displacement: float = 0.045
@export_range(0.0, 0.30, 0.005) var interaction_foliage_compression: float = 0.055
@export_range(0.0, 2.5, 0.01) var interaction_strength_scale: float = 1.0

@export_group("Vegetation")
@export_range(0.0, 18.0, 0.1) var foliage_sway_degrees: float = 5.2
@export_range(0.0, 8.0, 0.1) var foliage_flutter_degrees: float = 1.35
@export_range(0.0, 8.0, 0.1) var canopy_sway_degrees: float = 1.25
@export_range(0.0, 12.0, 0.1) var vine_sway_degrees: float = 4.0
@export_range(0.0, 3.0, 0.05) var root_sway_degrees: float = 0.22

@export_group("Water")
@export_range(0.0, 0.08, 0.001) var water_bob_height: float = 0.008
@export_range(0.0, 0.04, 0.001) var water_scale_pulse: float = 0.004
@export_range(0.0, 0.20, 0.002) var waterfall_flutter_distance: float = 0.032
@export_range(0.0, 0.20, 0.002) var waterfall_width_pulse: float = 0.045

@export_group("Motion")
@export_range(0.1, 20.0, 0.1) var response_smoothing: float = 7.0
@export_range(0.1, 5.0, 0.05) var base_frequency: float = 0.72


func get_debug_data() -> Dictionary:
	return {
		"environmental_motion_profile": true,
		"profile_id": profile_id,
		"ambient_speed": ambient_speed,
		"gust_strength": gust_strength,
		"systemic_airflow_scale": systemic_airflow_scale,
		"reference_wind_speed": reference_wind_speed,
		"maximum_visual_wind_speed": maximum_visual_wind_speed,
		"local_interaction_enabled": local_interaction_enabled,
		"interaction_foliage_bend_degrees": interaction_foliage_bend_degrees,
		"interaction_vine_bend_degrees": interaction_vine_bend_degrees,
	}
