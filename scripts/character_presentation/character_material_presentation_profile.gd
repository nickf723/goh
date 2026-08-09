extends Resource
class_name CharacterMaterialPresentationProfile

@export var profile_id: String = "character_material_presentation"
@export var display_name: String = "Character Material Presentation"
@export_range(32, 256, 1) var texture_resolution: int = 128
@export var detail_seed: int = 9417
@export_range(0.005, 0.2, 0.001) var detail_frequency: float = 0.045
@export_range(4, 48, 1) var maximum_shared_variants: int = 24

@export_group("Balanced")
@export_range(0.0, 2.0, 0.01) var balanced_normal_scale: float = 0.32
@export_range(0.0, 1.0, 0.01) var balanced_skin_backlight: float = 0.10
@export_range(0.0, 1.0, 0.01) var balanced_hair_backlight: float = 0.04

@export_group("Cinematic")
@export_range(0.0, 2.0, 0.01) var cinematic_normal_scale: float = 0.52
@export_range(0.0, 1.0, 0.01) var cinematic_skin_backlight: float = 0.18
@export_range(0.0, 1.0, 0.01) var cinematic_hair_backlight: float = 0.07
@export_range(0.0, 1.0, 0.01) var cinematic_skin_sss_strength: float = 0.12
@export var skin_transmittance_color: Color = Color(0.82, 0.34, 0.22, 1.0)
@export_range(0.0, 8.0, 0.05) var skin_transmittance_boost: float = 0.85
@export_range(0.01, 2.0, 0.01) var skin_transmittance_depth: float = 0.18


func get_debug_data() -> Dictionary:
	return {
		"character_material_presentation_profile": true,
		"profile_id": profile_id,
		"texture_resolution": texture_resolution,
		"maximum_shared_variants": maximum_shared_variants,
		"balanced_normal_scale": balanced_normal_scale,
		"cinematic_normal_scale": cinematic_normal_scale,
		"cinematic_skin_sss_strength": cinematic_skin_sss_strength,
	}
