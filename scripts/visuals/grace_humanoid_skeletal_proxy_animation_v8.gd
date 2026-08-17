extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_animation_v7.gd"
class_name GraceHumanoidSkeletalProxyAnimationV8

# V8 adds visual intention before a redirect. The head and upper torso look into
# a meaningful turn slightly more than the pelvis, while ordinary straight-line
# locomotion stays unchanged.

@export_group("Turn Anticipation")
@export_range(0.0, 24.0, 0.5) var maximum_head_lead_degrees: float = 12.0
@export_range(0.0, 16.0, 0.5) var maximum_chest_lead_degrees: float = 6.5
@export_range(0.0, 12.0, 0.5) var maximum_pelvis_follow_degrees: float = 3.5
@export_range(0.0, 1.0, 0.05) var turn_lead_threshold: float = 0.18

var last_turn_lead: float = 0.0
var last_turn_lead_side: float = 0.0


func _pose_locomotion(targets: Dictionary, delta: float) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_locomotion(targets, delta)
	_apply_turn_intention(targets)
	return pelvis_offset


func _apply_turn_intention(targets: Dictionary) -> void:
	last_turn_lead = 0.0
	last_turn_lead_side = 0.0
	if ground_motion_motor == null:
		return
	var motion: Dictionary = ground_motion_motor.get_debug_data()
	var turning: float = clampf(float(motion.get("turning_weight", 0.0)), 0.0, 1.0)
	var reversal: float = clampf(float(motion.get("reversal_weight", 0.0)), 0.0, 1.0)
	var angle: float = clampf(absf(float(motion.get("turn_angle_degrees", 0.0))) / 135.0, 0.0, 1.0)
	var local_direction: Vector3 = motion.get("local_direction", Vector3.ZERO) as Vector3
	var side: float = signf(local_direction.x)
	if absf(side) < 0.5 and reversal > 0.05:
		# For a straight 180° reversal, choose the shoulder already favored by the
		# current support foot rather than flipping randomly frame to frame.
		side = -1.0 if last_left_support > last_right_support else 1.0
	var weight: float = maxf(turning, reversal) * angle
	if weight <= turn_lead_threshold or absf(side) < 0.5:
		return
	weight = inverse_lerp(turn_lead_threshold, 1.0, weight)
	weight = smoothstep(0.0, 1.0, clampf(weight, 0.0, 1.0))
	last_turn_lead = weight
	last_turn_lead_side = side

	# The gaze leads, clavicles/chest follow, pelvis barely participates. Existing
	# pivot logic still owns the actual support-foot and lower-body redirect.
	_add_deg(targets, "pelvis", Vector3(0.0, side * maximum_pelvis_follow_degrees * weight, 0.0))
	_add_deg(targets, "spine_01", Vector3(0.0, side * maximum_chest_lead_degrees * 0.28 * weight, 0.0))
	_add_deg(targets, "spine_02", Vector3(0.0, side * maximum_chest_lead_degrees * 0.58 * weight, 0.0))
	_add_deg(targets, "chest", Vector3(0.0, side * maximum_chest_lead_degrees * weight, 0.0))
	_add_deg(targets, "neck", Vector3(0.0, side * maximum_head_lead_degrees * 0.48 * weight, 0.0))
	_add_deg(targets, "head", Vector3(0.0, side * maximum_head_lead_degrees * weight, -side * 1.5 * weight))


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["animation_v8"] = true
	data["turn_intention"] = true
	data["turn_lead_weight"] = snappedf(last_turn_lead, 0.01)
	data["turn_lead_side"] = last_turn_lead_side
	return data
