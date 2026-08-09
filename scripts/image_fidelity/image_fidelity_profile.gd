extends Resource
class_name ImageFidelityProfile

@export var profile_id: String = "image_fidelity"
@export var display_name: String = "Image Fidelity"

@export_group("Performance")
@export var performance_taa: bool = false
@export var performance_debanding: bool = false
@export var performance_msaa_2x: bool = false
@export var performance_roughness_limiter: bool = false

@export_group("Balanced")
@export var balanced_taa: bool = true
@export var balanced_debanding: bool = true
@export var balanced_msaa_2x: bool = false
@export var balanced_roughness_limiter: bool = true
@export_range(0.0, 1.0, 0.01) var balanced_roughness_amount: float = 0.25
@export_range(0.0, 1.0, 0.01) var balanced_roughness_limit: float = 0.18

@export_group("Cinematic")
@export var cinematic_taa: bool = true
@export var cinematic_debanding: bool = true
@export var cinematic_msaa_2x: bool = true
@export var cinematic_roughness_limiter: bool = true
@export_range(0.0, 1.0, 0.01) var cinematic_roughness_amount: float = 0.32
@export_range(0.0, 1.0, 0.01) var cinematic_roughness_limit: float = 0.15


func get_tier(quality: int) -> Dictionary:
	match clampi(quality, 0, 2):
		0:
			return {
				"taa": performance_taa,
				"debanding": performance_debanding,
				"msaa_2x": performance_msaa_2x,
				"roughness_limiter": performance_roughness_limiter,
				"roughness_amount": 0.25,
				"roughness_limit": 0.18,
			}
		1:
			return {
				"taa": balanced_taa,
				"debanding": balanced_debanding,
				"msaa_2x": balanced_msaa_2x,
				"roughness_limiter": balanced_roughness_limiter,
				"roughness_amount": balanced_roughness_amount,
				"roughness_limit": balanced_roughness_limit,
			}
		_:
			return {
				"taa": cinematic_taa,
				"debanding": cinematic_debanding,
				"msaa_2x": cinematic_msaa_2x,
				"roughness_limiter": cinematic_roughness_limiter,
				"roughness_amount": cinematic_roughness_amount,
				"roughness_limit": cinematic_roughness_limit,
			}


func get_debug_data() -> Dictionary:
	return {
		"image_fidelity_profile": true,
		"profile_id": profile_id,
		"performance_raw": (
			not performance_taa
			and not performance_debanding
			and not performance_msaa_2x
		),
		"balanced_taa": balanced_taa,
		"cinematic_taa": cinematic_taa,
		"cinematic_msaa_2x": cinematic_msaa_2x,
	}
