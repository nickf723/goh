extends Resource
class_name FaunaMaterialPresentationProfile

@export var profile_id: String = "fauna_material_default"
@export var display_name: String = "Fauna Material Presentation"

@export_group("Detail")
@export_range(32, 256, 1) var texture_resolution: int = 128
@export var detail_seed: int = 90371
@export_range(0.005, 0.3, 0.001) var normal_noise_frequency: float = 0.075
@export_range(0.0, 2.0, 0.01) var balanced_normal_scale: float = 0.34
@export_range(0.0, 2.0, 0.01) var cinematic_normal_scale: float = 0.52
@export_range(0.0, 8.0, 0.05) var normal_bump_strength: float = 2.4

@export_group("Hide")
@export_range(0.0, 1.0, 0.01) var balanced_hide_roughness_scale: float = 0.94
@export_range(0.0, 1.0, 0.01) var cinematic_hide_roughness_scale: float = 0.86
@export var hide_backlight_color: Color = Color(0.20, 0.30, 0.13, 1.0)
@export_range(0.0, 1.0, 0.01) var cinematic_hide_backlight_strength: float = 0.08

@export_group("Feather")
@export_range(0.0, 1.0, 0.01) var balanced_feather_roughness_scale: float = 0.90
@export_range(0.0, 1.0, 0.01) var cinematic_feather_roughness_scale: float = 0.80
@export var feather_backlight_color: Color = Color(0.46, 0.30, 0.10, 1.0)
@export_range(0.0, 1.0, 0.01) var balanced_feather_backlight_strength: float = 0.10
@export_range(0.0, 1.0, 0.01) var cinematic_feather_backlight_strength: float = 0.22

@export_group("Accent Hide")
@export_range(0.0, 1.0, 0.01) var balanced_accent_roughness_scale: float = 0.91
@export_range(0.0, 1.0, 0.01) var cinematic_accent_roughness_scale: float = 0.82
@export var accent_backlight_color: Color = Color(0.34, 0.25, 0.10, 1.0)
@export_range(0.0, 1.0, 0.01) var cinematic_accent_backlight_strength: float = 0.10

@export_group("Eyes")
@export_range(0.0, 1.0, 0.01) var balanced_eye_roughness: float = 0.13
@export_range(0.0, 1.0, 0.01) var cinematic_eye_roughness: float = 0.07
@export_range(0.0, 1.0, 0.01) var cinematic_eye_metallic: float = 0.16

@export_group("Budget")
@export_range(4, 64, 1) var maximum_shared_variants: int = 28


func get_debug_data() -> Dictionary:
	return {
		"fauna_material_presentation_profile": true,
		"profile_id": profile_id,
		"texture_resolution": texture_resolution,
		"maximum_shared_variants": maximum_shared_variants,
	}
