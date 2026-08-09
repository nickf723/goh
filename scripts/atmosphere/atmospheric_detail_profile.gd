extends Resource
class_name AtmosphericDetailProfile

@export var profile_id: String = "atmospheric_detail"
@export var display_name: String = "Atmospheric Detail"
@export_range(0.0, 1.0, 0.01) var performance_density_scale: float = 0.0
@export_range(0.0, 1.0, 0.01) var balanced_density_scale: float = 0.55
@export_range(0.0, 1.0, 0.01) var cinematic_density_scale: float = 1.0
@export_range(0.02, 0.25, 0.01) var update_interval: float = 0.05
@export_range(32, 1024, 1) var maximum_instances: int = 520
@export_range(0.5, 8.0, 0.1) var maximum_visual_wind_speed: float = 3.5
@export_range(8, 64, 1) var soft_texture_resolution: int = 32
@export_range(0.0, 8.0, 0.05) var camera_clear_radius: float = 0.0
@export_range(0.0, 8.0, 0.05) var camera_fade_distance: float = 0.0
@export var follow_lighting_quality: bool = true


func get_density_scale(quality: int) -> float:
	match clampi(quality, 0, 2):
		0:
			return performance_density_scale
		1:
			return balanced_density_scale
		_:
			return cinematic_density_scale


func get_debug_data() -> Dictionary:
	return {
		"atmospheric_detail_profile": true,
		"profile_id": profile_id,
		"performance_density_scale": performance_density_scale,
		"balanced_density_scale": balanced_density_scale,
		"cinematic_density_scale": cinematic_density_scale,
		"maximum_instances": maximum_instances,
		"camera_clear_radius": camera_clear_radius,
		"camera_fade_distance": camera_fade_distance,
		"follow_lighting_quality": follow_lighting_quality,
	}
