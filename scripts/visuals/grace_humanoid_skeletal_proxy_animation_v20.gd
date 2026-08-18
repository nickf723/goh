extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_animation_v19.gd"
class_name GraceHumanoidSkeletalProxyAnimationV20

# V20 gives the production skeleton an actual stealth posture. The existing
# StealthController continues to own collision height, camera drop, visibility,
# noise, and speed. This layer only makes Grace's body agree with that state.

@export_group("Stealth Animation")
@export_range(0.0, 32.0, 0.5) var crouch_knee_degrees: float = 24.0
@export_range(0.0, 24.0, 0.5) var crouch_hip_degrees: float = 15.0
@export_range(0.0, 0.3, 0.005) var crouch_center_drop: float = 0.16
@export_range(0.0, 1.0, 0.05) var crouch_stride_scale: float = 0.56

var stealth_controller: PlayerStealthController
var last_crouch_weight: float = 0.0
var crouch_phase: float = 0.0


func _ready() -> void:
	super._ready()
	if actor != null:
		stealth_controller = actor.get_node_or_null(
			"StealthController"
		) as PlayerStealthController


func _pose_idle(targets: Dictionary) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_idle(targets)
	if stealth_controller == null or not stealth_controller.is_crouched():
		last_crouch_weight = 0.0
		return pelvis_offset
	last_crouch_weight = 1.0
	pelvis_offset += _apply_crouch_idle(targets)
	return pelvis_offset


func _pose_locomotion(targets: Dictionary, delta: float) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_locomotion(targets, delta)
	if stealth_controller == null or not stealth_controller.is_crouched():
		last_crouch_weight = 0.0
		return pelvis_offset
	last_crouch_weight = 1.0
	pelvis_offset += _apply_crouch_walk(targets, delta)
	return pelvis_offset


func _apply_crouch_idle(targets: Dictionary) -> Vector3:
	var breath: float = sin(elapsed * 1.9)
	_set_deg(targets, "pelvis", Vector3(crouch_hip_degrees, 0.0, 0.0))
	_set_deg(targets, "spine_01", Vector3(8.0 + breath * 0.35, 0.0, 0.0))
	_set_deg(targets, "spine_02", Vector3(5.5 + breath * 0.45, 0.0, 0.0))
	_set_deg(targets, "chest", Vector3(2.0 + breath * 0.4, 0.0, 0.0))
	_set_deg(targets, "neck", Vector3(-3.0, 0.0, 0.0))
	_set_deg(targets, "head", Vector3(-5.0, 0.0, 0.0))

	_set_deg(targets, "thigh_l", Vector3(-crouch_knee_degrees * 0.8, 0.0, -5.0))
	_set_deg(targets, "thigh_r", Vector3(-crouch_knee_degrees * 0.76, 0.0, 5.0))
	_set_deg(targets, "shin_l", Vector3(crouch_knee_degrees * 1.45, 0.0, 0.0))
	_set_deg(targets, "shin_r", Vector3(crouch_knee_degrees * 1.38, 0.0, 0.0))
	_set_deg(targets, "foot_l", Vector3(-5.0, 0.0, 0.0))
	_set_deg(targets, "foot_r", Vector3(-5.0, 0.0, 0.0))

	# Arms stay closer to the torso, preserving whichever weapon carry was already
	# layered in but removing the loose upright idle silhouette.
	_add_deg(targets, "upper_arm_l", Vector3(6.0, 0.0, 5.0))
	_add_deg(targets, "upper_arm_r", Vector3(6.0, 0.0, -5.0))
	_add_deg(targets, "forearm_l", Vector3(-8.0, 0.0, 0.0))
	_add_deg(targets, "forearm_r", Vector3(-8.0, 0.0, 0.0))
	return Vector3(0.0, -crouch_center_drop + breath * 0.003, -0.015)


func _apply_crouch_walk(
	targets: Dictionary,
	delta: float
) -> Vector3:
	var speed: float = (
		Vector2(actor.velocity.x, actor.velocity.z).length()
		if actor != null
		else 0.0
	)
	var speed_weight: float = clampf(
		speed / maxf(locomotion_speed_reference * 0.55, 0.1),
		0.0,
		1.0
	)
	crouch_phase = fposmod(
		crouch_phase + delta * lerpf(3.4, 6.0, speed_weight),
		TAU
	)
	var step: float = sin(crouch_phase)
	var support: float = cos(crouch_phase)
	var stride: float = crouch_stride_scale * speed_weight

	_set_deg(targets, "pelvis", Vector3(
		crouch_hip_degrees + absf(step) * 2.0,
		-step * 2.0 * stride,
		-support * 2.5 * stride
	))
	_set_deg(targets, "spine_01", Vector3(8.0, step * 1.0 * stride, support * 1.5 * stride))
	_set_deg(targets, "spine_02", Vector3(5.0, step * 1.4 * stride, support * 1.8 * stride))
	_set_deg(targets, "chest", Vector3(2.0, step * 1.8 * stride, support * 2.0 * stride))
	_set_deg(targets, "head", Vector3(-4.0, -step * 1.2 * stride, -support * 0.6 * stride))

	_set_deg(targets, "thigh_l", Vector3(
		-crouch_knee_degrees * 0.75 + step * 12.0 * stride,
		0.0,
		-5.0
	))
	_set_deg(targets, "thigh_r", Vector3(
		-crouch_knee_degrees * 0.75 - step * 12.0 * stride,
		0.0,
		5.0
	))
	_set_deg(targets, "shin_l", Vector3(
		crouch_knee_degrees * 1.4 + maxf(-step, 0.0) * 12.0 * stride,
		0.0,
		0.0
	))
	_set_deg(targets, "shin_r", Vector3(
		crouch_knee_degrees * 1.4 + maxf(step, 0.0) * 12.0 * stride,
		0.0,
		0.0
	))
	_set_deg(targets, "foot_l", Vector3(-5.0 - step * 5.0 * stride, 0.0, 0.0))
	_set_deg(targets, "foot_r", Vector3(-5.0 + step * 5.0 * stride, 0.0, 0.0))
	_set_deg(targets, "toe_l", Vector3(maxf(support, 0.0) * 3.0 * stride, 0.0, 0.0))
	_set_deg(targets, "toe_r", Vector3(maxf(-support, 0.0) * 3.0 * stride, 0.0, 0.0))

	# Small, contained arm counter-swing remains compatible with the weapon-aware
	# carry underneath it.
	_add_deg(targets, "upper_arm_l", Vector3(-step * 5.0 * stride, 0.0, 3.0))
	_add_deg(targets, "upper_arm_r", Vector3(step * 5.0 * stride, 0.0, -3.0))
	return Vector3(
		support * support_weight_shift * 0.45 * stride,
		-crouch_center_drop - absf(support) * 0.01 * stride,
		-0.02
	)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["animation_v20"] = true
	data["stealth_crouch_animation"] = true
	data["crouch_weight"] = snappedf(last_crouch_weight, 0.01)
	data["crouch_phase"] = snappedf(crouch_phase, 0.01)
	return data
