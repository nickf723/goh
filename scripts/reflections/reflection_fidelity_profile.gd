extends Resource
class_name ReflectionFidelityProfile

@export var profile_id: String = "default_reflections"

@export_group("Performance")
@export var performance_enabled: bool = false
@export_range(0.0, 2.0, 0.01) var performance_intensity_scale: float = 0.0
@export_range(0.1, 8.0, 0.1) var performance_mesh_lod_threshold: float = 4.0
@export var performance_enable_probe_shadows: bool = false

@export_group("Balanced")
@export var balanced_enabled: bool = true
@export_range(0.0, 2.0, 0.01) var balanced_intensity_scale: float = 0.82
@export_range(0.1, 8.0, 0.1) var balanced_mesh_lod_threshold: float = 2.6
@export var balanced_enable_probe_shadows: bool = false

@export_group("Cinematic")
@export var cinematic_enabled: bool = true
@export_range(0.0, 2.0, 0.01) var cinematic_intensity_scale: float = 1.0
@export_range(0.1, 8.0, 0.1) var cinematic_mesh_lod_threshold: float = 1.0
@export var cinematic_enable_probe_shadows: bool = true

@export_group("Shared")
@export_range(0.1, 4.0, 0.05) var maximum_intensity: float = 1.25
@export_range(1.0, 200.0, 1.0) var maximum_capture_distance: float = 72.0


func get_tier(quality: int) -> Dictionary:
	match clampi(quality, 0, 2):
		0:
			return {
				"enabled": performance_enabled,
				"intensity_scale": performance_intensity_scale,
				"mesh_lod_threshold": performance_mesh_lod_threshold,
				"enable_shadows": performance_enable_probe_shadows,
			}
		1:
			return {
				"enabled": balanced_enabled,
				"intensity_scale": balanced_intensity_scale,
				"mesh_lod_threshold": balanced_mesh_lod_threshold,
				"enable_shadows": balanced_enable_probe_shadows,
			}
		_:
			return {
				"enabled": cinematic_enabled,
				"intensity_scale": cinematic_intensity_scale,
				"mesh_lod_threshold": cinematic_mesh_lod_threshold,
				"enable_shadows": cinematic_enable_probe_shadows,
			}


func get_debug_data() -> Dictionary:
	return {
		"reflection_fidelity_profile": true,
		"profile_id": profile_id,
		"performance_enabled": performance_enabled,
		"balanced_enabled": balanced_enabled,
		"cinematic_enabled": cinematic_enabled,
	}
