extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_animation_v28.gd"
class_name GraceHumanoidSkeletalProxyAnimationV29

# V29 corrects low-speed analog gait amplitude. Locomotion V2 intentionally made
# cadence speed-aware, but its minimum stride angle was still large enough to read
# as a run cycle played slowly. This layer scales ordinary walk limbs/lean without
# affecting crouch, riding, traversal, or authored combat.

@export_group("Walk Run Blend")
@export_range(0.1, 0.8, 0.05) var full_walk_speed_ratio: float = 0.42
@export_range(0.3, 1.0, 0.05) var full_run_speed_ratio: float = 0.74
@export_range(0.1, 1.0, 0.05) var minimum_walk_leg_scale: float = 0.46
@export_range(0.1, 1.0, 0.05) var minimum_walk_arm_scale: float = 0.38
@export_range(0.0, 8.0, 0.25) var walk_upright_correction_degrees: float = 3.0

var last_walk_weight: float = 0.0
var last_run_weight: float = 0.0
var last_walk_speed_ratio: float = 0.0


func _pose_locomotion(targets: Dictionary, delta: float) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_locomotion(targets, delta)
	_apply_walk_run_blend(targets)
	return pelvis_offset


func _apply_walk_run_blend(targets: Dictionary) -> void:
	last_walk_weight = 0.0
	last_run_weight = 0.0
	last_walk_speed_ratio = 0.0
	if actor == null:
		return
	if stealth_controller != null and stealth_controller.is_crouched():
		return
	if riding_controller != null and riding_controller.is_riding():
		return
	if climbing_controller != null and climbing_controller.should_handle_locomotion():
		return
	if swimming_controller != null and swimming_controller.should_handle_locomotion():
		return

	var speed_ratio: float = clampf(
		Vector2(actor.velocity.x, actor.velocity.z).length()
		/ maxf(locomotion_speed_reference, 0.1),
		0.0,
		1.0
	)
	last_walk_speed_ratio = speed_ratio
	if speed_ratio >= full_run_speed_ratio:
		last_run_weight = 1.0
		return
	var run_blend: float = smoothstep(
		full_walk_speed_ratio,
		maxf(full_run_speed_ratio, full_walk_speed_ratio + 0.05),
		speed_ratio
	)
	last_run_weight = run_blend
	last_walk_weight = 1.0 - run_blend

	# At the slowest valid locomotion speed, scale swing sharply down. By the full
	# walk threshold the stride has grown, then blends naturally into the authored run.
	var walk_progress: float = clampf(
		speed_ratio / maxf(full_walk_speed_ratio, 0.05),
		0.0,
		1.0
	)
	var leg_scale: float = lerpf(minimum_walk_leg_scale, 0.78, walk_progress)
	leg_scale = lerpf(leg_scale, 1.0, run_blend)
	var arm_scale: float = lerpf(minimum_walk_arm_scale, 0.7, walk_progress)
	arm_scale = lerpf(arm_scale, 1.0, run_blend)

	for bone_name: String in ["thigh_l", "thigh_r"]:
		var value: Vector3 = targets.get(bone_name, Vector3.ZERO) as Vector3
		value.x *= leg_scale
		targets[bone_name] = value
	for bone_name: String in ["shin_l", "shin_r"]:
		var value: Vector3 = targets.get(bone_name, Vector3.ZERO) as Vector3
		value.x *= lerpf(leg_scale, 1.0, 0.16)
		targets[bone_name] = value
	for bone_name: String in ["foot_l", "foot_r", "toe_l", "toe_r"]:
		var value: Vector3 = targets.get(bone_name, Vector3.ZERO) as Vector3
		value.x *= lerpf(leg_scale, 1.0, 0.28)
		targets[bone_name] = value
	for bone_name: String in ["upper_arm_l", "upper_arm_r"]:
		var value: Vector3 = targets.get(bone_name, Vector3.ZERO) as Vector3
		# Preserve lateral weapon-carry angles; only fore/aft swing is reduced.
		value.x *= arm_scale
		targets[bone_name] = value
	for bone_name: String in ["forearm_l", "forearm_r"]:
		var value: Vector3 = targets.get(bone_name, Vector3.ZERO) as Vector3
		value.x *= lerpf(arm_scale, 1.0, 0.35)
		targets[bone_name] = value

	var upright: float = (1.0 - run_blend) * walk_upright_correction_degrees
	_add_deg(targets, "spine_01", Vector3(upright * 0.45, 0.0, 0.0))
	_add_deg(targets, "spine_02", Vector3(upright * 0.72, 0.0, 0.0))
	_add_deg(targets, "chest", Vector3(upright, 0.0, 0.0))
	_add_deg(targets, "head", Vector3(-upright * 0.28, 0.0, 0.0))


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["animation_v29"] = true
	data["walk_run_blend"] = true
	data["walk_weight"] = snappedf(last_walk_weight, 0.01)
	data["run_weight"] = snappedf(last_run_weight, 0.01)
	data["walk_speed_ratio"] = snappedf(last_walk_speed_ratio, 0.01)
	return data
