extends "res://scripts/levels/prototype_green_grotto_vegetation_pass.gd"
class_name PrototypeGreenGrottoShadowPass

var shadow_fidelity_director: ShadowFidelityDirector3D = null


func _ready() -> void:
	super._ready()
	shadow_fidelity_director = get_node_or_null(
		"ShadowFidelityDirector"
	) as ShadowFidelityDirector3D
	if shadow_fidelity_director != null:
		shadow_fidelity_director.call_deferred("synchronize_now")
	set_meta("shadow_fidelity_pass", "shadow_fidelity_v1")
	set_meta("shadow_fidelity_authority", "ShadowFidelityDirector")
	set_meta("shadow_quality_control", "LightingDirector_F7")


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["green_grotto_shadow_fidelity"] = true
	data["shadow_fidelity_authority"] = "ShadowFidelityDirector"
	data["shadow_quality_control"] = "LightingDirector_F7"
	data["shadow_geometry_unchanged"] = true
	return data
