extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_animation_v23.gd"
class_name GraceHumanoidSkeletalProxyAnimationV24

# V24 overlays weapon-control posture on the phase-authored dodge. The dodge
# still owns legs, center of mass, and travel; this only prevents long/heavy
# weapons from behaving as though Grace's right hand were empty.

@export_group("Dodge Weapon Control")
@export_range(0.0, 1.0, 0.05) var dodge_weapon_control_strength: float = 0.9


func _pose_dodge(targets: Dictionary) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_dodge(targets)
	_apply_dodge_weapon_control(targets)
	return pelvis_offset


func _apply_dodge_weapon_control(targets: Dictionary) -> void:
	var weapon_class: String = _get_equipped_weapon_class()
	if weapon_class not in ["staff", "axe"]:
		return
	var w: float = dodge_weapon_control_strength
	var phase: String = (
		dodge_controller.get_dodge_phase()
		if dodge_controller != null
		else "travel"
	)
	var travel: float = 1.0 if phase == "travel" else 0.65
	var landing: float = 1.0 if phase in ["landing", "recovery"] else 0.0

	match weapon_class:
		"staff":
			# Keep the shaft close along Grace's right flank in travel, then open the
			# elbow slightly as the receiving foot catches the end of the dodge.
			_set_deg(targets, "clavicle_r", Vector3(2.0 * w, -8.0 * w, 5.0 * w))
			_set_deg(targets, "upper_arm_r", Vector3(
				(28.0 + landing * 8.0) * w,
				-15.0 * w,
				(18.0 - travel * 4.0) * w
			))
			_set_deg(targets, "forearm_r", Vector3(
				(-42.0 + landing * 8.0) * w,
				7.0 * w,
				-3.0 * w
			))
			_set_deg(targets, "hand_r", Vector3(-6.0 * w, -4.0 * w, 14.0 * w))
			# Free hand protects the chest during peak travel and reopens on landing.
			_set_deg(targets, "upper_arm_l", Vector3(
				(24.0 - landing * 7.0) * w,
				7.0 * w,
				(-23.0 + landing * 8.0) * w
			))
			_set_deg(targets, "forearm_l", Vector3((-38.0 + landing * 14.0) * w, 0.0, 0.0))
		"axe":
			# Pull the axe inward during travel. The lowered shoulder and bent elbow
			# make the weapon read as protected mass, not a rigid prop stuck to the hand.
			_set_deg(targets, "clavicle_r", Vector3(4.0 * w, -8.0 * w, 7.0 * w))
			_set_deg(targets, "upper_arm_r", Vector3(
				(32.0 + landing * 7.0) * w,
				-16.0 * w,
				(20.0 - travel * 5.0) * w
			))
			_set_deg(targets, "forearm_r", Vector3(
				(-38.0 + landing * 7.0) * w,
				4.0 * w,
				-2.0 * w
			))
			_set_deg(targets, "hand_r", Vector3(-5.0 * w, 0.0, 23.0 * w))
			_add_deg(targets, "pelvis", Vector3(0.0, 2.0 * w, -2.0 * w))
			_add_deg(targets, "spine_01", Vector3(0.0, -1.0 * w, 2.0 * w))
			_add_deg(targets, "chest", Vector3(0.0, -2.0 * w, 3.0 * w))


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["animation_v24"] = true
	data["dodge_weapon_control"] = true
	return data
