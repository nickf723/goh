extends "res://scripts/weapons/axe_weapon_rig_v1.gd"
class_name AxeWeaponRigV2


func _process(_delta: float) -> void:
	_update_momentum_glow()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["axe_weapon_rig_v2"] = true
	data["live_momentum_glow"] = true
	return data
