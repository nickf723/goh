extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_animation_v22.gd"
class_name GraceHumanoidSkeletalProxyAnimationV23

# V23 carries the Staff/Axe ordinary movement language into non-attacking aerial
# poses. Special traversal still owns the body silhouette; this layer only keeps
# the weapon arm from reverting to an empty-handed spread.

@export_group("Airborne Weapon Carry")
@export_range(0.0, 1.0, 0.05) var airborne_weapon_carry_strength: float = 0.82


func _pose_airborne(targets: Dictionary, state_name: String) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_airborne(targets, state_name)
	_apply_airborne_weapon_carry(targets, state_name)
	return pelvis_offset


func _apply_airborne_weapon_carry(
	targets: Dictionary,
	state_name: String
) -> void:
	var weapon_class: String = _get_equipped_weapon_class()
	if weapon_class not in ["staff", "axe"]:
		return
	var w: float = airborne_weapon_carry_strength
	var falling: float = 1.0 if state_name == "fall" or (actor != null and actor.velocity.y < -0.2) else 0.0
	var rising: float = 1.0 - falling
	var travel: float = 0.0
	if actor != null:
		travel = clampf(
			Vector2(actor.velocity.x, actor.velocity.z).length()
			/ maxf(locomotion_speed_reference, 0.1),
			0.0,
			1.0
		)

	match weapon_class:
		"staff":
			# Shaft stays diagonally across the right side. During a fall Grace brings
			# the free hand closer, anticipating either landing or the aerial vault.
			_set_deg(targets, "clavicle_r", Vector3(1.0 * w, -5.0 * w, 4.0 * w))
			_set_deg(targets, "upper_arm_r", Vector3(
				lerpf(18.0, 28.0, falling) * w,
				-10.0 * w,
				14.0 * w
			))
			_set_deg(targets, "forearm_r", Vector3(
				lerpf(-28.0, -36.0, falling) * w,
				5.0 * w,
				-2.0 * w
			))
			_set_deg(targets, "hand_r", Vector3(-5.0 * w, -3.0 * w, 13.0 * w))
			_add_deg(targets, "upper_arm_l", Vector3(
				falling * 14.0 * w - rising * 2.0 * w,
				4.0 * w,
				12.0 * falling * w
			))
			_add_deg(targets, "forearm_l", Vector3(-falling * 18.0 * w, 0.0, 0.0))
			_add_deg(targets, "chest", Vector3(0.0, -2.0 * w, -travel * 1.5 * w))
		"axe":
			# Heavy head stays close to Grace's right hip/rib cage instead of swinging
			# overhead with the generic airborne arm. Falling tightens the elbow further.
			_set_deg(targets, "clavicle_r", Vector3(3.0 * w, -5.0 * w, 6.0 * w))
			_set_deg(targets, "upper_arm_r", Vector3(
				lerpf(22.0, 31.0, falling) * w,
				-11.0 * w,
				17.0 * w
			))
			_set_deg(targets, "forearm_r", Vector3(
				lerpf(-24.0, -34.0, falling) * w,
				2.0 * w,
				-1.0 * w
			))
			_set_deg(targets, "hand_r", Vector3(-4.0 * w, 0.0, 21.0 * w))
			_add_deg(targets, "upper_arm_l", Vector3(-rising * 4.0 * w, 0.0, -4.0 * w))
			_add_deg(targets, "pelvis", Vector3(0.0, 1.5 * w, -1.5 * w))
			_add_deg(targets, "spine_01", Vector3(0.0, -1.0 * w, 1.8 * w))
			_add_deg(targets, "chest", Vector3(0.0, -1.8 * w, 2.5 * w))


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["animation_v23"] = true
	data["airborne_weapon_carry"] = true
	return data
