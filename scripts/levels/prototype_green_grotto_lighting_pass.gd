extends "res://scripts/levels/prototype_green_grotto_calibration_kit_pass.gd"
class_name PrototypeGreenGrottoLightingPass


func _ready() -> void:
	super._ready()
	_retire_legacy_local_lighting()
	set_meta("lighting_pass", "lighting_director_v1")
	set_meta("lighting_authority", "LightingDirector")


func _retire_legacy_local_lighting() -> void:
	for path: String in [
		"GreenGrottoArt/Lighting/ShrineSunBounce",
		"GreenGrottoArt/Lighting/WaterCoolBounce",
	]:
		var light: OmniLight3D = get_node_or_null(path) as OmniLight3D
		if light == null:
			continue
		light.light_energy = 0.0
		light.light_volumetric_fog_energy = 0.0
		light.visible = false
		light.set_meta("retired_by_lighting_director", true)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["green_grotto_lighting_pass"] = true
	data["lighting_authority"] = "LightingDirector"
	data["legacy_local_lights_retired"] = true
	return data
