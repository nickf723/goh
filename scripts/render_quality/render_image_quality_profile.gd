extends Resource
class_name RenderImageQualityProfile

@export var profile_id: String = "render_image_default"
@export var display_name: String = "Render Image Quality"

@export_group("Performance")
@export var performance_taa: bool = false
@export_enum("Disabled:0", "FXAA:1", "SMAA:2") var performance_screen_space_aa: int = 1
@export_enum("Disabled:0", "2x:1", "4x:2", "8x:3") var performance_msaa_3d: int = 0
@export var performance_debanding: bool = false

@export_group("Balanced")
@export var balanced_taa: bool = true
@export_enum("Disabled:0", "FXAA:1", "SMAA:2") var balanced_screen_space_aa: int = 0
@export_enum("Disabled:0", "2x:1", "4x:2", "8x:3") var balanced_msaa_3d: int = 0
@export var balanced_debanding: bool = true

@export_group("Cinematic")
@export var cinematic_taa: bool = true
@export_enum("Disabled:0", "FXAA:1", "SMAA:2") var cinematic_screen_space_aa: int = 0
@export_enum("Disabled:0", "2x:1", "4x:2", "8x:3") var cinematic_msaa_3d: int = 1
@export var cinematic_debanding: bool = true


func get_tier(quality: int) -> Dictionary:
	match clampi(quality, 0, 2):
		0:
			return {
				"taa": performance_taa,
				"screen_space_aa": performance_screen_space_aa,
				"msaa_3d": performance_msaa_3d,
				"debanding": performance_debanding,
			}
		1:
			return {
				"taa": balanced_taa,
				"screen_space_aa": balanced_screen_space_aa,
				"msaa_3d": balanced_msaa_3d,
				"debanding": balanced_debanding,
			}
		_:
			return {
				"taa": cinematic_taa,
				"screen_space_aa": cinematic_screen_space_aa,
				"msaa_3d": cinematic_msaa_3d,
				"debanding": cinematic_debanding,
			}


func get_debug_data() -> Dictionary:
	return {
		"render_image_quality_profile": true,
		"profile_id": profile_id,
		"performance": get_tier(0),
		"balanced": get_tier(1),
		"cinematic": get_tier(2),
	}
