extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_animation_v24.gd"
class_name GraceHumanoidSkeletalProxyAnimationV25

# V25 reads the existing StepUpController's resolved step height. The collision
# controller still teleports the CharacterBody safely onto the step; presentation
# supplies a brief free-leg lift and pelvis follow so stairs do not read as sliding.

@export_group("Step-Up Animation")
@export_range(0.05, 0.35, 0.01) var step_pose_seconds: float = 0.16
@export_range(0.0, 42.0, 0.5) var maximum_step_knee_lift_degrees: float = 26.0
@export_range(0.0, 0.16, 0.005) var maximum_step_pelvis_lift: float = 0.055

var step_up_controller: PlayerStepUpController
var step_pose_remaining: float = 0.0
var step_pose_height_ratio: float = 0.0
var step_lead_sign: float = 1.0
var step_count: int = 0


func _ready() -> void:
	super._ready()
	if actor != null:
		step_up_controller = actor.get_node_or_null(
			"StepUpController"
		) as PlayerStepUpController


func _process(delta: float) -> void:
	_update_step_pose(maxf(delta, 0.0))
	super._process(delta)


func _pose_locomotion(targets: Dictionary, delta: float) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_locomotion(targets, delta)
	pelvis_offset += _apply_step_pose(targets)
	return pelvis_offset


func _update_step_pose(delta: float) -> void:
	step_pose_remaining = maxf(step_pose_remaining - delta, 0.0)
	if step_up_controller == null or not step_up_controller.stepped_this_frame:
		return
	var height: float = maxf(step_up_controller.last_step_height, 0.0)
	var maximum_height: float = maxf(step_up_controller.maximum_step_height, 0.01)
	step_pose_height_ratio = clampf(height / maximum_height, 0.0, 1.0)
	# Lift the leg that is not currently carrying most of Grace's weight.
	step_lead_sign = -1.0 if last_left_support >= last_right_support else 1.0
	step_pose_remaining = step_pose_seconds
	step_count += 1


func _apply_step_pose(targets: Dictionary) -> Vector3:
	if step_pose_remaining <= 0.001 or step_pose_seconds <= 0.001:
		return Vector3.ZERO
	var age: float = 1.0 - clampf(
		step_pose_remaining / step_pose_seconds,
		0.0,
		1.0
	)
	var wave: float = sin(age * PI)
	var settle: float = smoothstep(0.22, 1.0, age)
	var weight: float = wave * step_pose_height_ratio
	var lead_left: bool = step_lead_sign > 0.0
	var knee_lift: float = maximum_step_knee_lift_degrees * weight

	if lead_left:
		_add_deg(targets, "thigh_l", Vector3(knee_lift, 0.0, -2.0 * weight))
		_add_deg(targets, "shin_l", Vector3(knee_lift * 0.72, 0.0, 0.0))
		_add_deg(targets, "foot_l", Vector3(-knee_lift * 0.28, 0.0, 0.0))
		_add_deg(targets, "toe_l", Vector3(knee_lift * 0.16, 0.0, 0.0))
		_add_deg(targets, "shin_r", Vector3(5.0 * weight, 0.0, 0.0))
	else:
		_add_deg(targets, "thigh_r", Vector3(knee_lift, 0.0, 2.0 * weight))
		_add_deg(targets, "shin_r", Vector3(knee_lift * 0.72, 0.0, 0.0))
		_add_deg(targets, "foot_r", Vector3(-knee_lift * 0.28, 0.0, 0.0))
		_add_deg(targets, "toe_r", Vector3(knee_lift * 0.16, 0.0, 0.0))
		_add_deg(targets, "shin_l", Vector3(5.0 * weight, 0.0, 0.0))

	# Torso stays mostly quiet. A tiny counter-lean keeps the lifted knee from
	# making Grace look as though she is jumping the stair.
	_add_deg(targets, "pelvis", Vector3(-2.0 * weight, 0.0, 0.0))
	_add_deg(targets, "spine_01", Vector3(1.0 * weight, 0.0, 0.0))
	_add_deg(targets, "chest", Vector3(1.5 * weight, 0.0, 0.0))
	return Vector3(
		0.0,
		maximum_step_pelvis_lift * step_pose_height_ratio * settle,
		-0.008 * weight
	)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["animation_v25"] = true
	data["step_up_animation"] = true
	data["step_pose_remaining"] = snappedf(step_pose_remaining, 0.001)
	data["step_height_ratio"] = snappedf(step_pose_height_ratio, 0.01)
	data["step_lead"] = "left" if step_lead_sign > 0.0 else "right"
	data["step_count"] = step_count
	return data
