extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_animation_v26.gd"
class_name GraceHumanoidSkeletalProxyAnimationV27

# V27 lets the body acknowledge strong airflow already sampled by AirflowResponse.
# Wind force remains gameplay-owned; this layer only leans Grace into the relative
# flow and uses arms/legs for balance when the acceleration is meaningful.

@export_group("Airflow Body Response")
@export_range(0.1, 20.0, 0.1) var airflow_full_acceleration: float = 7.5
@export_range(0.0, 16.0, 0.5) var airflow_torso_lean_degrees: float = 7.0
@export_range(0.0, 16.0, 0.5) var airflow_side_bank_degrees: float = 6.0
@export_range(0.0, 18.0, 0.5) var airflow_arm_balance_degrees: float = 8.0
@export_range(0.0, 0.08, 0.005) var airflow_center_shift: float = 0.026

var airflow_response: AirflowResponse
var last_airflow_pose_weight: float = 0.0
var last_airflow_local: Vector3 = Vector3.ZERO


func _ready() -> void:
	super._ready()
	if actor != null:
		airflow_response = actor.get_node_or_null(
			"AirflowResponse"
		) as AirflowResponse


func _pose_idle(targets: Dictionary) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_idle(targets)
	pelvis_offset += _apply_airflow_pose(targets, 1.0)
	return pelvis_offset


func _pose_locomotion(targets: Dictionary, delta: float) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_locomotion(targets, delta)
	pelvis_offset += _apply_airflow_pose(targets, 0.72)
	return pelvis_offset


func _pose_airborne(targets: Dictionary, state_name: String) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_airborne(targets, state_name)
	# Airborne airflow is mostly visible through trajectory and secondary cloth.
	# Keep skeletal bracing small so jump/flight silhouettes remain readable.
	pelvis_offset += _apply_airflow_pose(targets, 0.38)
	return pelvis_offset


func _apply_airflow_pose(
	targets: Dictionary,
	state_scale: float
) -> Vector3:
	last_airflow_pose_weight = 0.0
	last_airflow_local = Vector3.ZERO
	if airflow_response == null or actor == null:
		return Vector3.ZERO
	var acceleration: Vector3 = airflow_response.last_acceleration
	var magnitude: float = acceleration.length()
	if magnitude <= 0.15:
		return Vector3.ZERO
	var local: Vector3 = (
		actor.global_transform.basis.orthonormalized().inverse()
		* acceleration
	)
	var weight: float = clampf(
		magnitude / maxf(airflow_full_acceleration, 0.1),
		0.0,
		1.0
	) * clampf(state_scale, 0.0, 1.0)
	last_airflow_pose_weight = weight
	last_airflow_local = local
	var horizontal_length: float = Vector2(local.x, local.z).length()
	if horizontal_length <= 0.001:
		return Vector3.ZERO
	var side: float = clampf(local.x / horizontal_length, -1.0, 1.0)
	var forward_push: float = clampf(-local.z / horizontal_length, -1.0, 1.0)

	# Lean into the force, opposite the direction Grace is being accelerated.
	var pitch: float = forward_push * airflow_torso_lean_degrees * weight
	var roll: float = side * airflow_side_bank_degrees * weight
	_add_deg(targets, "pelvis", Vector3(-pitch * 0.35, 0.0, -roll * 0.8))
	_add_deg(targets, "spine_01", Vector3(-pitch * 0.55, 0.0, roll * 0.5))
	_add_deg(targets, "spine_02", Vector3(-pitch * 0.72, 0.0, roll * 0.7))
	_add_deg(targets, "chest", Vector3(-pitch, 0.0, roll))
	_add_deg(targets, "head", Vector3(pitch * 0.32, 0.0, -roll * 0.25))

	var weapon_class: String = _get_equipped_weapon_class()
	var weapon_arm_scale: float = 0.38 if weapon_class in ["staff", "axe"] else 0.72
	_add_deg(targets, "upper_arm_l", Vector3(2.0 * weight, -side * 2.0 * weight, -side * airflow_arm_balance_degrees * weight))
	_add_deg(targets, "upper_arm_r", Vector3(2.0 * weight, -side * 2.0 * weight, side * airflow_arm_balance_degrees * weapon_arm_scale * weight))
	_add_deg(targets, "thigh_l", Vector3(-4.0 * weight, 0.0, -side * 3.0 * weight))
	_add_deg(targets, "thigh_r", Vector3(-4.0 * weight, 0.0, -side * 3.0 * weight))
	_add_deg(targets, "shin_l", Vector3(8.0 * weight, 0.0, 0.0))
	_add_deg(targets, "shin_r", Vector3(8.0 * weight, 0.0, 0.0))
	return Vector3(
		-side * airflow_center_shift * weight,
		-0.012 * weight,
		forward_push * airflow_center_shift * 0.6 * weight
	)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["animation_v27"] = true
	data["airflow_body_response"] = true
	data["airflow_pose_weight"] = snappedf(last_airflow_pose_weight, 0.01)
	data["airflow_local"] = last_airflow_local
	return data
