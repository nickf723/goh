extends Resource
class_name HeroReadabilityLightProfile

@export var profile_id: String = "hero_readability_default"
@export var display_name: String = "Hero Readability Light"
@export_range(1, 20, 1) var character_render_layer: int = 2

@export_group("Light")
@export var light_color: Color = Color(0.64, 0.75, 1.0, 1.0)
@export_range(0.0, 1.0, 0.01) var balanced_energy: float = 0.18
@export_range(0.0, 1.0, 0.01) var cinematic_energy: float = 0.30
@export_range(0.0, 1.0, 0.01) var light_specular: float = 0.36

@export_group("Camera-relative direction")
@export_range(0.0, 8.0, 0.1) var behind_distance: float = 3.2
@export_range(-4.0, 4.0, 0.1) var side_offset: float = 1.0
@export_range(-2.0, 5.0, 0.1) var height_offset: float = 2.0
@export_range(0.0, 3.0, 0.05) var target_height: float = 1.05
@export_range(0.1, 20.0, 0.1) var direction_smoothing: float = 5.5


func get_debug_data() -> Dictionary:
	return {
		"hero_readability_light_profile": true,
		"profile_id": profile_id,
		"render_layer": character_render_layer,
		"balanced_energy": balanced_energy,
		"cinematic_energy": cinematic_energy,
	}
