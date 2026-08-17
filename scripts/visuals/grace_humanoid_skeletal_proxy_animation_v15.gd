extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_animation_v14.gd"
class_name GraceHumanoidSkeletalProxyAnimationV15

# V15 adds low-amplitude terrain posture. It does not solve feet with IK or alter
# collision; it simply lets ankles, pelvis, and torso acknowledge the floor normal
# during idle/locomotion so uneven ground does not leave Grace perfectly vertical.

@export_group("Terrain Posture")
@export_range(0.0, 24.0, 0.5) var maximum_slope_pose_degrees: float = 12.0
@export_range(0.0, 1.0, 0.05) var foot_slope_alignment: float = 0.82
@export_range(0.0, 1.0, 0.05) var pelvis_slope_alignment: float = 0.32
@export_range(0.0, 1.0, 0.05) var torso_slope_compensation: float = 0.22
@export_range(1.0, 30.0, 0.5) var slope_response: float = 12.0

var smoothed_slope_pitch: float = 0.0
var smoothed_slope_roll: float = 0.0
var last_floor_normal: Vector3 = Vector3.UP


func _process(delta: float) -> void:
	_update_slope_pose(maxf(delta, 0.0))
	super._process(delta)


func _pose_idle(targets: Dictionary) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_idle(targets)
	_apply_slope_pose(targets, 1.0)
	return pelvis_offset


func _pose_locomotion(targets: Dictionary, delta: float) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_locomotion(targets, delta)
	var speed_weight: float = (
		clampf(Vector2(actor.velocity.x, actor.velocity.z).length() / maxf(locomotion_speed_reference, 0.1), 0.0, 1.0)
		if actor != null
		else 0.0
	)
	# Full ankle alignment remains useful at speed, while torso compensation fades
	# slightly so strong movement animation still reads clearly.
	_apply_slope_pose(targets, lerpf(1.0, 0.76, speed_weight))
	return pelvis_offset


func _update_slope_pose(delta: float) -> void:
	var target_pitch: float = 0.0
	var target_roll: float = 0.0
	last_floor_normal = Vector3.UP
	if actor != null and actor.is_on_floor():
		var normal: Vector3 = actor.get_floor_normal()
		if normal.length_squared() > 0.0001:
			normal = normal.normalized()
			last_floor_normal = normal
			var local_normal: Vector3 = (
				actor.global_transform.basis.orthonormalized().inverse() * normal
			)
			target_pitch = rad_to_deg(atan2(local_normal.z, maxf(local_normal.y, 0.01)))
			target_roll = rad_to_deg(atan2(-local_normal.x, maxf(local_normal.y, 0.01)))
			target_pitch = clampf(target_pitch, -maximum_slope_pose_degrees, maximum_slope_pose_degrees)
			target_roll = clampf(target_roll, -maximum_slope_pose_degrees, maximum_slope_pose_degrees)
	var blend: float = (
		1.0
		if delta <= 0.0
		else 1.0 - exp(-maxf(slope_response, 0.01) * delta)
	)
	smoothed_slope_pitch = lerpf(smoothed_slope_pitch, target_pitch, blend)
	smoothed_slope_roll = lerpf(smoothed_slope_roll, target_roll, blend)


func _apply_slope_pose(targets: Dictionary, weight: float) -> void:
	var pitch: float = smoothed_slope_pitch * clampf(weight, 0.0, 1.0)
	var roll: float = smoothed_slope_roll * clampf(weight, 0.0, 1.0)
	if absf(pitch) < 0.05 and absf(roll) < 0.05:
		return

	_add_deg(targets, "foot_l", Vector3(
		pitch * foot_slope_alignment,
		0.0,
		roll * foot_slope_alignment
	))
	_add_deg(targets, "foot_r", Vector3(
		pitch * foot_slope_alignment,
		0.0,
		roll * foot_slope_alignment
	))
	_add_deg(targets, "toe_l", Vector3(pitch * 0.24, 0.0, roll * 0.18))
	_add_deg(targets, "toe_r", Vector3(pitch * 0.24, 0.0, roll * 0.18))
	_add_deg(targets, "pelvis", Vector3(
		pitch * pelvis_slope_alignment,
		0.0,
		roll * pelvis_slope_alignment
	))
	# Upper body partially counters the floor angle so Grace adapts through the legs
	# instead of tilting like a single rigid board.
	_add_deg(targets, "spine_01", Vector3(
		-pitch * torso_slope_compensation * 0.35,
		0.0,
		-roll * torso_slope_compensation * 0.35
	))
	_add_deg(targets, "spine_02", Vector3(
		-pitch * torso_slope_compensation * 0.62,
		0.0,
		-roll * torso_slope_compensation * 0.62
	))
	_add_deg(targets, "chest", Vector3(
		-pitch * torso_slope_compensation,
		0.0,
		-roll * torso_slope_compensation
	))
	_add_deg(targets, "head", Vector3(
		pitch * torso_slope_compensation * 0.35,
		0.0,
		roll * torso_slope_compensation * 0.35
	))


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["animation_v15"] = true
	data["terrain_posture"] = true
	data["slope_pitch"] = snappedf(smoothed_slope_pitch, 0.1)
	data["slope_roll"] = snappedf(smoothed_slope_roll, 0.1)
	data["floor_normal"] = last_floor_normal
	return data
