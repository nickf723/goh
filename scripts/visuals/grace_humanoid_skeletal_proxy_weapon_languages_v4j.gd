extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_weapon_languages_v4i.gd"

# Quaternion bone blending always chooses the shortest orientation path, so a
# target pose of 360 degrees is equivalent to zero and cannot display a complete
# corkscrew. V4J puts that one authored revolution on the presentation root while
# the skeleton owns the tuck, axe orbit, leverage, and landing posture.


func _process(delta: float) -> void:
	_update_axe_charge_root_twist()
	super._process(delta)


func _update_axe_charge_root_twist() -> void:
	if weapon_controller == null or weapon_controller.current_attack == null:
		rotation = Vector3.ZERO
		return
	var attack: WeaponAttackDefinition = weapon_controller.current_attack
	if not attack.extra_tags.has("axe_lever_vault"):
		rotation = Vector3.ZERO
		return
	var startup: float = maxf(
		attack.get_startup_duration(weapon_controller.get_attack_speed()),
		0.01
	)
	var p: float = clampf(
		weapon_controller.current_attack_elapsed / startup,
		0.0,
		1.0
	)
	if p < 0.58:
		rotation = Vector3.ZERO
		return
	if p < 0.9:
		var twist: float = smoothstep(0.0, 1.0, (p - 0.58) / 0.32)
		rotation = Vector3(
			deg_to_rad(-18.0 * sin(twist * PI)),
			deg_to_rad(360.0 * twist),
			deg_to_rad(32.0 * sin(twist * PI))
		)
		return
	# The final tenth of startup completes the revolution and sheds the diagonal
	# lean while the body and axe commit to the second downstroke.
	var descend: float = smoothstep(0.0, 1.0, (p - 0.9) / 0.1)
	rotation = Vector3(
		deg_to_rad(lerpf(-2.0, 0.0, descend)),
		deg_to_rad(360.0),
		deg_to_rad(lerpf(6.0, 0.0, descend))
	)


func _build_axe_lever_twist_pose(
	attack: WeaponAttackDefinition,
	stage: String
) -> Dictionary:
	var pose: Dictionary = super._build_axe_lever_twist_pose(attack, stage)
	if weapon_controller == null or attack == null:
		return pose
	var startup: float = maxf(
		attack.get_startup_duration(weapon_controller.get_attack_speed()),
		0.01
	)
	var p: float = clampf(
		weapon_controller.current_attack_elapsed / startup,
		0.0,
		1.0
	)
	if p < 0.58 or weapon_controller.current_attack_elapsed >= startup:
		return pose
	# Remove wrapped axial values from the torso bones. The root above performs
	# the visible full turn, avoiding shortest-path quaternion cancellation.
	for bone_name: String in ["pelvis", "spine_01", "spine_02", "chest"]:
		if not pose.has(bone_name):
			continue
		var bone_rotation: Vector3 = pose.get(bone_name, Vector3.ZERO) as Vector3
		bone_rotation.y = 0.0
		pose[bone_name] = bone_rotation
	return pose


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["weapon_language_v4j"] = true
	data["axe_root_corkscrew"] = true
	return data
