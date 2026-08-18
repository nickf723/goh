extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_animation_v16.gd"
class_name GraceHumanoidSkeletalProxyAnimationV17

# V17 keeps mounted Grace visually attached to the animal's gait. The mount owns
# all locomotion and collision; Grace only supplies seated balance and hand/leg
# presentation.

var riding_controller: PlayerRidingController
var riding_phase: float = 0.0
var last_riding_weight: float = 0.0
var last_riding_gait: String = "none"


func _ready() -> void:
	super._ready()
	if actor != null:
		riding_controller = actor.get_node_or_null(
			"RidingController"
		) as PlayerRidingController


func _pose_idle(targets: Dictionary) -> Vector3:
	if riding_controller != null and riding_controller.is_riding():
		return _pose_riding(targets)
	return super._pose_idle(targets)


func _pose_locomotion(targets: Dictionary, delta: float) -> Vector3:
	if riding_controller != null and riding_controller.is_riding():
		return _pose_riding(targets, delta)
	return super._pose_locomotion(targets, delta)


func _pose_riding(targets: Dictionary, delta: float = 0.0) -> Vector3:
	if riding_controller == null or not riding_controller.is_riding():
		return Vector3.ZERO
	var mount: RideableMount = riding_controller.get_current_mount()
	if mount == null:
		return Vector3.ZERO
	var speed: float = absf(mount.current_speed)
	var speed_weight: float = clampf(speed / 8.0, 0.0, 1.0)
	last_riding_weight = speed_weight
	last_riding_gait = mount.current_gait
	var gait_multiplier: float = 1.0
	var gait_name: String = mount.current_gait.to_lower()
	if gait_name.contains("gallop"):
		gait_multiplier = 1.55
	elif gait_name.contains("trot"):
		gait_multiplier = 1.25
	riding_phase = fposmod(
		riding_phase + maxf(delta, 1.0 / 60.0) * lerpf(2.8, 7.2, speed_weight) * gait_multiplier,
		TAU
	)
	var bounce: float = sin(riding_phase)
	var double_bounce: float = absf(sin(riding_phase * 2.0))
	var counter: float = sin(riding_phase + PI * 0.5)

	_set_deg(targets, "pelvis", Vector3(8.0 + bounce * 2.0 * speed_weight, 0.0, counter * 2.0 * speed_weight))
	_set_deg(targets, "spine_01", Vector3(-3.0 - bounce * 1.5 * speed_weight, 0.0, -counter * 1.0 * speed_weight))
	_set_deg(targets, "spine_02", Vector3(-5.0 - bounce * 2.0 * speed_weight, 0.0, -counter * 1.5 * speed_weight))
	_set_deg(targets, "chest", Vector3(-7.0 - bounce * 2.2 * speed_weight, 0.0, -counter * 1.8 * speed_weight))
	_set_deg(targets, "neck", Vector3(3.0 + bounce * 0.8 * speed_weight, 0.0, 0.0))
	_set_deg(targets, "head", Vector3(2.0 + bounce * 1.0 * speed_weight, 0.0, 0.0))

	# Hands stay forward and slightly separated as a reins/withers-ready position.
	_set_deg(targets, "upper_arm_l", Vector3(43.0 + bounce * 2.0 * speed_weight, 10.0, -19.0))
	_set_deg(targets, "upper_arm_r", Vector3(43.0 + bounce * 2.0 * speed_weight, -10.0, 19.0))
	_set_deg(targets, "forearm_l", Vector3(-52.0 + counter * 2.0 * speed_weight, -2.0, 2.0))
	_set_deg(targets, "forearm_r", Vector3(-52.0 + counter * 2.0 * speed_weight, 2.0, -2.0))
	_set_deg(targets, "hand_l", Vector3(-5.0, 0.0, -7.0))
	_set_deg(targets, "hand_r", Vector3(-5.0, 0.0, 7.0))

	# Deep hip flexion plus outward roll gives the readable straddling silhouette.
	_set_deg(targets, "thigh_l", Vector3(62.0 - bounce * 3.0 * speed_weight, 0.0, -21.0))
	_set_deg(targets, "thigh_r", Vector3(62.0 + bounce * 3.0 * speed_weight, 0.0, 21.0))
	_set_deg(targets, "shin_l", Vector3(74.0 + counter * 3.0 * speed_weight, 0.0, 4.0))
	_set_deg(targets, "shin_r", Vector3(74.0 - counter * 3.0 * speed_weight, 0.0, -4.0))
	_set_deg(targets, "foot_l", Vector3(-18.0, 0.0, -8.0))
	_set_deg(targets, "foot_r", Vector3(-18.0, 0.0, 8.0))
	animation_weight = lerpf(0.75, 1.0, speed_weight)
	return Vector3(
		0.0,
		-0.115 - double_bounce * 0.016 * speed_weight,
		0.015
	)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["animation_v17"] = true
	data["riding_animation"] = true
	data["riding_weight"] = snappedf(last_riding_weight, 0.01)
	data["riding_gait"] = last_riding_gait
	return data
