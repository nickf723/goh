extends Resource
class_name ProjectedCanopyLightProfile

@export var profile_id: String = "projected_canopy_default"
@export var display_name: String = "Projected Canopy Light"

@export_group("Projector Mask")
@export_range(32, 256, 1) var projector_resolution: int = 96
@export var noise_seed: int = 58173
@export_range(0.005, 0.2, 0.001) var noise_frequency: float = 0.036
@export_range(1, 8, 1) var noise_octaves: int = 4
@export_range(0.0, 1.0, 0.01) var opening_threshold: float = 0.52
@export_range(0.01, 0.4, 0.01) var opening_softness: float = 0.16
@export_range(0.0, 1.0, 0.01) var blocked_floor: float = 0.05
@export_range(0.0, 1.0, 0.01) var edge_fade_start: float = 0.72

@export_group("Light")
@export var light_color: Color = Color(1.0, 0.58, 0.22, 1.0)
@export_range(1.0, 100.0, 0.5) var spot_range: float = 38.0
@export_range(5.0, 88.0, 0.5) var spot_angle: float = 38.0
@export_range(0.0, 4.0, 0.05) var spot_attenuation: float = 0.62
@export_range(0.0, 1.0, 0.01) var light_specular: float = 0.12
@export_range(0.0, 2.0, 0.01) var balanced_energy: float = 0.42
@export_range(0.0, 2.0, 0.01) var cinematic_energy: float = 0.68
@export_range(0.0, 2.0, 0.01) var balanced_volumetric_energy: float = 0.22
@export_range(0.0, 2.0, 0.01) var cinematic_volumetric_energy: float = 0.38

@export_group("Shadow")
@export_range(0.0, 0.5, 0.001) var shadow_bias: float = 0.055
@export_range(0.0, 4.0, 0.01) var shadow_normal_bias: float = 0.82
@export_range(0.0, 4.0, 0.01) var shadow_blur: float = 1.15
@export_range(0.0, 1.0, 0.01) var shadow_opacity: float = 0.74

@export_group("Drift")
@export_range(0.0, 1.0, 0.005) var rotation_drift_speed: float = 0.035
@export_range(0.0, 12.0, 0.1) var rotation_drift_degrees: float = 2.2


func get_debug_data() -> Dictionary:
	return {
		"projected_canopy_light_profile": true,
		"profile_id": profile_id,
		"resolution": projector_resolution,
		"balanced_energy": balanced_energy,
		"cinematic_energy": cinematic_energy,
	}
