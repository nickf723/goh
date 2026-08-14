extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_weapon_languages_v4m.gd"

# V4N lets the authored Axe rig decide how strongly the left hand grips the lower
# haft. Lights keep a loose guiding hand; heavy and charged attacks close into a
# firm two-handed leverage grip without changing the other weapon contracts.


func _update_support_hand_ik_state() -> void:
	if _get_equipped_weapon_class() != "axe":
		super._update_support_hand_ik_state()
		return
	if (
		not support_hand_ik_ready
		or support_hand_ik == null
		or support_hand_pole == null
		or support_grip_contract == null
	):
		return
	var target_influence: float = 0.0
	if support_grip_contract.has_method("get_support_influence"):
		target_influence = float(
			support_grip_contract.call("get_support_influence")
		)
	support_hand_ik.influence = clampf(target_influence, 0.0, 1.0)
	if support_hand_ik.influence <= 0.001 or not bones.has("upper_arm_l"):
		return
	var shoulder_pose: Transform3D = skeleton.get_bone_global_pose(
		int(bones["upper_arm_l"])
	)
	var shoulder_world: Vector3 = global_transform * shoulder_pose.origin
	var actor_basis: Basis = actor.global_transform.basis.orthonormalized()
	var left: Vector3 = -actor_basis.x.normalized()
	var forward: Vector3 = -actor_basis.z.normalized()
	support_hand_pole.global_position = (
		shoulder_world
		+ left * 0.5
		+ Vector3.UP * 0.02
		+ forward * 0.11
	)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["weapon_language_v4n"] = true
	data["axe_support_hand_ik"] = (
		_get_equipped_weapon_class() == "axe"
		and support_hand_ik != null
		and support_hand_ik.influence > 0.001
	)
	return data
