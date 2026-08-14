extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_weapon_languages_v4h.gd"

# V4I removes the ±180-degree discontinuity from the sustained Chain orbit.


func _build_attack_stage_pose(
	attack: WeaponAttackDefinition,
	stage: String
) -> Dictionary:
	if (
		_get_equipped_weapon_class() == "chains"
		and attack != null
		and attack.extra_tags.has("chain_charge_orbit")
	):
		return _build_chain_charge_pose_continuous()
	return super._build_attack_stage_pose(attack, stage)


func _build_chain_charge_pose_continuous() -> Dictionary:
	var pose: Dictionary = {}
	var state: Dictionary = _get_chain_head_state()
	var head_yaw: float = float(state.get("yaw", 0.0))
	var speed_ratio: float = float(state.get("speed", 0.0))
	var radians: float = deg_to_rad(head_yaw)
	var lateral: float = sin(radians)
	var rearward: float = maxf(-cos(radians), 0.0)
	var charge: float = 0.0
	if weapon_controller != null and weapon_controller.has_method("get_weapon_charge_ratio"):
		charge = float(weapon_controller.call("get_weapon_charge_ratio"))
	var crouch: float = lerpf(18.0, 27.0, charge)
	var pull: float = lerpf(0.72, 1.0, speed_ratio)
	var counter_yaw: float = -lateral * 23.0
	var shoulder_yaw: float = lateral * 28.0
	_set_pose_deg(pose, "pelvis", Vector3(10.0 + rearward * 3.0, counter_yaw, -lateral * 5.0))
	_set_pose_deg(pose, "spine_01", Vector3(7.0, shoulder_yaw * 0.45, lateral * 3.0))
	_set_pose_deg(pose, "spine_02", Vector3(5.0, shoulder_yaw * 0.72, lateral * 4.0))
	_set_pose_deg(pose, "chest", Vector3(3.0, shoulder_yaw, lateral * 6.0))
	_set_pose_deg(pose, "head", Vector3(-3.0, -shoulder_yaw * 0.3, -lateral * 2.0))
	_set_pose_deg(pose, "upper_arm_r", Vector3(43.0, shoulder_yaw * 0.6, 18.0))
	_set_pose_deg(pose, "forearm_r", Vector3(-50.0 + pull * 8.0, 0.0, 0.0))
	_set_pose_deg(pose, "upper_arm_l", Vector3(37.0, shoulder_yaw * 0.5, -20.0))
	_set_pose_deg(pose, "forearm_l", Vector3(-54.0 + pull * 7.0, 0.0, 0.0))
	_set_pose_deg(pose, "thigh_l", Vector3(-crouch, 0.0, -11.0))
	_set_pose_deg(pose, "thigh_r", Vector3(-crouch, 0.0, 11.0))
	_set_pose_deg(pose, "shin_l", Vector3(crouch * 1.72, 0.0, 0.0))
	_set_pose_deg(pose, "shin_r", Vector3(crouch * 1.72, 0.0, 0.0))
	pose["__pelvis_offset"] = Vector3(
		-lateral * 0.022,
		-0.115 - charge * 0.025 - rearward * 0.01,
		0.0
	)
	return pose


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["weapon_language_v4i"] = true
	data["chain_charge_wrap_safe"] = true
	return data
