extends "res://scripts/player/player_controller_free_aim_status.gd"
class_name PlayerControllerWeaponCharge

const CHARGE_MOVEMENT_META: StringName = &"weapon_charge_movement_multiplier"


func _get_requested_ground_velocity() -> Vector3:
	var requested: Vector3 = super._get_requested_ground_velocity()
	if not has_meta(CHARGE_MOVEMENT_META):
		return requested
	var multiplier: float = clampf(
		float(get_meta(CHARGE_MOVEMENT_META)),
		0.0,
		1.0
	)
	return requested * multiplier
