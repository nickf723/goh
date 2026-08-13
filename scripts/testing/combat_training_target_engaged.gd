extends "res://scripts/testing/combat_training_target.gd"
class_name CombatTrainingTargetEngaged

@export_range(0.0, 2.0, 0.05) var cut_reaction_strength: float = 1.0
@export_range(0.0, 20.0, 0.5) var cut_twist_degrees: float = 8.0
@export_range(0.0, 0.2, 0.01) var cut_side_shift: float = 0.045


func receive_weapon_impact(
	payload: DamagePayload,
	direction: Vector3,
	attack: WeaponAttackDefinition
) -> void:
	super.receive_weapon_impact(payload, direction, attack)
	if payload == null or attack == null or visual_root == null:
		return
	if _airborne_presentation_is_active():
		return
	if (
		payload.knockback_up_strength > 0.8
		or payload.tags.has("launcher")
		or payload.tags.has("ground_launcher")
	):
		return

	var thrust_like: bool = (
		attack.extra_tags.has("thrust")
		or attack.extra_tags.has("pierce")
		or attack.cone_angle_degrees <= 48.0
	)
	var reaction_scale: float = clampf(
		0.75 + float(maxi(payload.amount, 0)) * 0.06,
		0.75,
		1.4
	) * cut_reaction_strength

	if thrust_like:
		# Thrusts drive through the target's centerline. Keep the response axial so
		# it does not look as though an invisible sideways force twisted the dummy.
		impact_visual_position.z += 0.035 * reaction_scale
		impact_visual_rotation.x -= deg_to_rad(3.0 * reaction_scale)
		_apply_impact_visual_now()
		return

	var swing_sign: float = _resolve_cut_sign(attack)
	impact_visual_position.x += -swing_sign * cut_side_shift * reaction_scale
	impact_visual_rotation.y += deg_to_rad(
		swing_sign * cut_twist_degrees * 0.65 * reaction_scale
	)
	impact_visual_rotation.z += deg_to_rad(
		swing_sign * cut_twist_degrees * reaction_scale
	)
	_apply_impact_visual_now()


func _resolve_cut_sign(attack: WeaponAttackDefinition) -> float:
	if attack == null:
		return 1.0
	var yaw_delta: float = (
		attack.strike_rotation_degrees.y
		- attack.windup_rotation_degrees.y
	)
	if absf(yaw_delta) > 1.0:
		return signf(yaw_delta)
	var profile_id: String = attack.character_pose_id.to_lower()
	if profile_id.contains("left"):
		return -1.0
	if profile_id.contains("right"):
		return 1.0
	return 1.0


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["paired_impact_reaction"] = true
	data["cut_reaction_strength"] = cut_reaction_strength
	return data
