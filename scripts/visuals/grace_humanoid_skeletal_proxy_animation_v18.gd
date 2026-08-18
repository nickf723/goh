extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_animation_v17.gd"
class_name GraceHumanoidSkeletalProxyAnimationV18

# V18 refines the aerial controller's special traversal states while leaving the
# regular jump/fall progression from Locomotion V2 intact.

var aerial_controller: PlayerAerialLocomotion
var aerial_special_phase: float = 0.0
var last_aerial_special_state: String = "none"


func _ready() -> void:
	super._ready()
	if actor != null:
		aerial_controller = actor.get_node_or_null(
			"AerialLocomotion"
		) as PlayerAerialLocomotion


func _pose_airborne(targets: Dictionary, state_name: String) -> Vector3:
	last_aerial_special_state = "none"
	if aerial_controller == null:
		return super._pose_airborne(targets, state_name)
	if aerial_controller.flight_active:
		last_aerial_special_state = "flight"
		return _pose_flight(targets)
	if aerial_controller.controlled_descent_active:
		last_aerial_special_state = "controlled_descent"
		return _pose_controlled_descent(targets)
	if aerial_controller.traversal_state == "hovering":
		last_aerial_special_state = "hover"
		return _pose_hover(targets)
	if aerial_controller.traversal_state == "double_jump":
		last_aerial_special_state = "double_jump"
		return _pose_double_jump(targets)
	return super._pose_airborne(targets, state_name)


func _pose_double_jump(targets: Dictionary) -> Vector3:
	var phase: float = 0.0
	if locomotion_vertical_controller != null:
		phase = locomotion_vertical_controller.get_phase_progress()
	var burst: float = 1.0 - smoothstep(0.0, 0.5, phase)
	var extend: float = smoothstep(0.18, 1.0, phase)
	_set_deg(targets, "pelvis", Vector3(13.0 * burst - 6.0 * extend, 0.0, 0.0))
	_set_deg(targets, "spine_01", Vector3(12.0 * burst - 6.0 * extend, 0.0, 0.0))
	_set_deg(targets, "spine_02", Vector3(9.0 * burst - 7.0 * extend, 0.0, 0.0))
	_set_deg(targets, "chest", Vector3(7.0 * burst - 8.0 * extend, 0.0, 0.0))
	_set_deg(targets, "head", Vector3(-4.0 * burst + 3.0 * extend, 0.0, 0.0))
	_set_deg(targets, "upper_arm_l", Vector3(-45.0 * burst - 20.0 * extend, 0.0, -26.0))
	_set_deg(targets, "upper_arm_r", Vector3(-45.0 * burst - 20.0 * extend, 0.0, 26.0))
	_set_deg(targets, "thigh_l", Vector3(-34.0 * burst + 18.0 * extend, 0.0, -6.0))
	_set_deg(targets, "thigh_r", Vector3(-30.0 * burst - 8.0 * extend, 0.0, 6.0))
	_set_deg(targets, "shin_l", Vector3(58.0 * burst + 16.0 * extend, 0.0, 0.0))
	_set_deg(targets, "shin_r", Vector3(54.0 * burst + 12.0 * extend, 0.0, 0.0))
	animation_weight = 1.0
	return Vector3(0.0, -0.06 * burst + 0.03 * extend, 0.0)


func _pose_hover(targets: Dictionary) -> Vector3:
	aerial_special_phase += 1.0 / 60.0
	var float_wave: float = sin(elapsed * 4.0)
	var counter: float = sin(elapsed * 4.0 + PI * 0.5)
	var travel: float = 0.0
	if actor != null:
		travel = clampf(
			Vector2(actor.velocity.x, actor.velocity.z).length() / 5.0,
			0.0,
			1.0
		)
	_set_deg(targets, "pelvis", Vector3(-2.0 - travel * 2.0, counter * 1.5, float_wave * 1.0))
	_set_deg(targets, "spine_01", Vector3(-3.0 - travel * 1.5, -counter * 1.0, -float_wave * 0.7))
	_set_deg(targets, "spine_02", Vector3(-4.0 - travel * 2.0, -counter * 1.5, -float_wave * 0.9))
	_set_deg(targets, "chest", Vector3(-5.0 - travel * 2.5, -counter * 2.0, -float_wave * 1.0))
	_set_deg(targets, "head", Vector3(3.0 + travel * 1.0, counter * 1.0, 0.0))
	_set_deg(targets, "upper_arm_l", Vector3(-8.0 + float_wave * 3.0, 0.0, -42.0))
	_set_deg(targets, "upper_arm_r", Vector3(-8.0 - float_wave * 3.0, 0.0, 42.0))
	_set_deg(targets, "forearm_l", Vector3(-18.0, 0.0, -3.0))
	_set_deg(targets, "forearm_r", Vector3(-18.0, 0.0, 3.0))
	_set_deg(targets, "thigh_l", Vector3(14.0 + counter * 4.0, 0.0, -5.0))
	_set_deg(targets, "thigh_r", Vector3(10.0 - counter * 4.0, 0.0, 5.0))
	_set_deg(targets, "shin_l", Vector3(28.0 - counter * 5.0, 0.0, 0.0))
	_set_deg(targets, "shin_r", Vector3(24.0 + counter * 5.0, 0.0, 0.0))
	_set_deg(targets, "foot_l", Vector3(8.0, 0.0, 0.0))
	_set_deg(targets, "foot_r", Vector3(8.0, 0.0, 0.0))
	animation_weight = 0.82
	return Vector3(0.0, float_wave * 0.012, -0.012 * travel)


func _pose_controlled_descent(targets: Dictionary) -> Vector3:
	var fall_speed: float = maxf(-actor.velocity.y, 0.0) if actor != null else 0.0
	var weight: float = clampf(
		fall_speed / maxf(aerial_controller.controlled_descent_speed, 0.1),
		0.2,
		1.0
	)
	var sway: float = sin(elapsed * 3.4)
	_set_deg(targets, "pelvis", Vector3(6.0 * weight, 0.0, sway * 1.5 * weight))
	_set_deg(targets, "spine_01", Vector3(6.0 * weight, 0.0, -sway * 1.0 * weight))
	_set_deg(targets, "spine_02", Vector3(7.0 * weight, 0.0, -sway * 1.3 * weight))
	_set_deg(targets, "chest", Vector3(8.0 * weight, 0.0, -sway * 1.5 * weight))
	_set_deg(targets, "head", Vector3(-4.0 * weight, 0.0, sway * 0.5 * weight))
	_set_deg(targets, "upper_arm_l", Vector3(9.0 * weight, 0.0, -54.0 * weight))
	_set_deg(targets, "upper_arm_r", Vector3(9.0 * weight, 0.0, 54.0 * weight))
	_set_deg(targets, "thigh_l", Vector3(25.0 * weight, 0.0, -7.0))
	_set_deg(targets, "thigh_r", Vector3(22.0 * weight, 0.0, 7.0))
	_set_deg(targets, "shin_l", Vector3(39.0 * weight, 0.0, 0.0))
	_set_deg(targets, "shin_r", Vector3(36.0 * weight, 0.0, 0.0))
	_set_deg(targets, "foot_l", Vector3(-8.0 * weight, 0.0, 0.0))
	_set_deg(targets, "foot_r", Vector3(-8.0 * weight, 0.0, 0.0))
	animation_weight = weight
	return Vector3(0.0, -0.015 * weight, 0.0)


func _pose_flight(targets: Dictionary) -> Vector3:
	if actor == null:
		return Vector3.ZERO
	var basis: Basis = actor.global_transform.basis.orthonormalized()
	var local_velocity: Vector3 = basis.inverse() * actor.velocity
	var horizontal_speed: float = Vector2(local_velocity.x, local_velocity.z).length()
	var forward_drive: float = clampf(
		-local_velocity.z / maxf(aerial_controller.flight_speed, 0.1),
		-1.0,
		1.0
	)
	var side_drive: float = clampf(
		local_velocity.x / maxf(aerial_controller.flight_speed, 0.1),
		-1.0,
		1.0
	)
	var vertical_drive: float = clampf(
		local_velocity.y / maxf(aerial_controller.flight_vertical_speed, 0.1),
		-1.0,
		1.0
	)
	var travel_weight: float = clampf(horizontal_speed / maxf(aerial_controller.flight_speed, 0.1), 0.0, 1.0)
	var wing_wave: float = sin(elapsed * 3.2) * (1.0 - travel_weight) * 0.5

	_set_deg(targets, "pelvis", Vector3(-10.0 * forward_drive + vertical_drive * 4.0, -side_drive * 3.0, -side_drive * 5.0))
	_set_deg(targets, "spine_01", Vector3(-11.0 * forward_drive + vertical_drive * 3.0, side_drive * 2.0, side_drive * 3.0))
	_set_deg(targets, "spine_02", Vector3(-12.0 * forward_drive + vertical_drive * 2.0, side_drive * 3.0, side_drive * 4.0))
	_set_deg(targets, "chest", Vector3(-14.0 * forward_drive + vertical_drive * 1.0, side_drive * 4.0, side_drive * 5.0))
	_set_deg(targets, "head", Vector3(6.0 * forward_drive - vertical_drive * 3.0, -side_drive * 2.0, -side_drive * 1.0))
	_set_deg(targets, "upper_arm_l", Vector3(-18.0 + wing_wave * 5.0, 0.0, -lerpf(45.0, 24.0, travel_weight)))
	_set_deg(targets, "upper_arm_r", Vector3(-18.0 - wing_wave * 5.0, 0.0, lerpf(45.0, 24.0, travel_weight)))
	_set_deg(targets, "forearm_l", Vector3(-14.0, 0.0, -2.0))
	_set_deg(targets, "forearm_r", Vector3(-14.0, 0.0, 2.0))
	_set_deg(targets, "thigh_l", Vector3(-4.0 + vertical_drive * 8.0, 0.0, -4.0))
	_set_deg(targets, "thigh_r", Vector3(-6.0 + vertical_drive * 7.0, 0.0, 4.0))
	_set_deg(targets, "shin_l", Vector3(12.0 - vertical_drive * 4.0, 0.0, 0.0))
	_set_deg(targets, "shin_r", Vector3(14.0 - vertical_drive * 4.0, 0.0, 0.0))
	_set_deg(targets, "foot_l", Vector3(17.0, 0.0, 0.0))
	_set_deg(targets, "foot_r", Vector3(17.0, 0.0, 0.0))
	animation_weight = lerpf(0.72, 1.0, travel_weight)
	return Vector3(-side_drive * 0.018, vertical_drive * 0.012, -forward_drive * 0.025)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["animation_v18"] = true
	data["aerial_special_states"] = true
	data["aerial_special_state"] = last_aerial_special_state
	return data
