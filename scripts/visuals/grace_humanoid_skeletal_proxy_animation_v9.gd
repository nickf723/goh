extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_animation_v8.gd"
class_name GraceHumanoidSkeletalProxyAnimationV9

# V9 fills the non-weapon presentation gap without replacing locomotion. Guard,
# casting, item use, manipulation, and interaction become upper-body overlays so
# the feet can keep their support logic while Grace's hands visibly do the action.

@export_group("Context Action Animation")
@export_range(0.0, 1.0, 0.05) var context_overlay_strength: float = 1.0

var last_context_action: String = "none"
var context_action_weight: float = 0.0


func _pose_idle(targets: Dictionary) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_idle(targets)
	pelvis_offset += _apply_context_action_overlay(targets, false)
	return pelvis_offset


func _pose_locomotion(targets: Dictionary, delta: float) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_locomotion(targets, delta)
	pelvis_offset += _apply_context_action_overlay(targets, true)
	return pelvis_offset


func _apply_context_action_overlay(
	targets: Dictionary,
	moving: bool
) -> Vector3:
	last_context_action = "none"
	context_action_weight = 0.0
	if action_state == null:
		return Vector3.ZERO
	var moving_scale: float = 0.78 if moving else 1.0
	var strength: float = context_overlay_strength * moving_scale

	if action_state.is_guarding:
		last_context_action = "guard"
		context_action_weight = strength
		return _apply_guard_overlay(targets, strength, moving)
	if action_state.is_manipulating:
		last_context_action = "manipulate"
		context_action_weight = strength
		return _apply_manipulation_overlay(targets, strength, moving)
	if action_state.is_using_item:
		last_context_action = "item"
		context_action_weight = strength
		return _apply_item_overlay(targets, strength, moving)
	if action_state.is_interacting:
		last_context_action = "interact"
		context_action_weight = strength
		return _apply_interaction_overlay(targets, strength, moving)
	if action_state.is_casting:
		last_context_action = "cast_channel" if action_state.cast_channel_active else "cast"
		context_action_weight = strength
		return _apply_cast_overlay(targets, strength, moving, action_state.cast_channel_active)
	return Vector3.ZERO


func _apply_guard_overlay(
	targets: Dictionary,
	weight: float,
	moving: bool
) -> Vector3:
	var weapon_class: String = _get_equipped_weapon_class()
	var pulse: float = sin(elapsed * 2.8) * 0.5 + 0.5
	_add_deg(targets, "pelvis", Vector3(4.0 * weight, 0.0, 0.0))
	_add_deg(targets, "spine_01", Vector3(3.0 * weight, 0.0, 0.0))
	_add_deg(targets, "spine_02", Vector3(2.0 * weight, 0.0, 0.0))
	_add_deg(targets, "chest", Vector3(-3.0 * weight, 0.0, 0.0))
	_add_deg(targets, "head", Vector3(1.5 * weight, 0.0, 0.0))

	match weapon_class:
		"staff":
			_set_deg(targets, "upper_arm_r", Vector3(53.0 * weight, -14.0 * weight, 22.0 * weight))
			_set_deg(targets, "forearm_r", Vector3(-53.0 * weight, 7.0 * weight, -4.0 * weight))
			_set_deg(targets, "hand_r", Vector3(-5.0 * weight, -3.0 * weight, 23.0 * weight))
			_set_deg(targets, "upper_arm_l", Vector3(45.0 * weight, 13.0 * weight, -22.0 * weight))
			_set_deg(targets, "forearm_l", Vector3(-49.0 * weight, -5.0 * weight, 3.0 * weight))
			_set_deg(targets, "hand_l", Vector3(-4.0 * weight, 0.0, -18.0 * weight))
		"axe":
			_set_deg(targets, "upper_arm_r", Vector3(70.0 * weight, -16.0 * weight, 24.0 * weight))
			_set_deg(targets, "forearm_r", Vector3(-48.0 * weight, 5.0 * weight, -4.0 * weight))
			_set_deg(targets, "hand_r", Vector3(-6.0 * weight, 0.0, 30.0 * weight))
			_set_deg(targets, "upper_arm_l", Vector3(57.0 * weight, 15.0 * weight, -23.0 * weight))
			_set_deg(targets, "forearm_l", Vector3(-51.0 * weight, -4.0 * weight, 4.0 * weight))
			_set_deg(targets, "hand_l", Vector3(-5.0 * weight, 0.0, 26.0 * weight))
		_:
			_set_deg(targets, "upper_arm_l", Vector3(47.0 * weight, 8.0 * weight, -28.0 * weight))
			_set_deg(targets, "upper_arm_r", Vector3(50.0 * weight, -8.0 * weight, 28.0 * weight))
			_set_deg(targets, "forearm_l", Vector3(-57.0 * weight, 0.0, 0.0))
			_set_deg(targets, "forearm_r", Vector3(-57.0 * weight, 0.0, 0.0))

	if not moving:
		_add_deg(targets, "thigh_l", Vector3(-11.0 * weight, 0.0, -3.0 * weight))
		_add_deg(targets, "thigh_r", Vector3(-10.0 * weight, 0.0, 3.0 * weight))
		_add_deg(targets, "shin_l", Vector3(22.0 * weight, 0.0, 0.0))
		_add_deg(targets, "shin_r", Vector3(20.0 * weight, 0.0, 0.0))
	return Vector3(0.0, -0.035 * weight - pulse * 0.003 * weight, -0.012 * weight)


func _apply_cast_overlay(
	targets: Dictionary,
	weight: float,
	moving: bool,
	channeling: bool
) -> Vector3:
	var pulse: float = sin(elapsed * (4.2 if channeling else 5.4))
	var gather: float = 0.5 + 0.5 * sin(elapsed * 2.1)
	# Left hand is the default free casting hand so the equipped weapon can remain
	# readable in the right. Channeling gradually recruits the torso and right shoulder.
	_add_deg(targets, "pelvis", Vector3(0.0, -4.0 * weight, 0.0))
	_add_deg(targets, "spine_01", Vector3(-2.0 * weight, -5.0 * weight, 1.0 * weight))
	_add_deg(targets, "spine_02", Vector3(-4.0 * weight, -8.0 * weight, 2.0 * weight))
	_add_deg(targets, "chest", Vector3(-6.0 * weight, -12.0 * weight, 3.0 * weight))
	_add_deg(targets, "head", Vector3(2.0 * weight, 5.0 * weight, -1.0 * weight))
	_set_deg(targets, "upper_arm_l", Vector3(70.0 * weight + pulse * 3.0, 12.0 * weight, -28.0 * weight))
	_set_deg(targets, "forearm_l", Vector3(-29.0 * weight + pulse * 2.0, -4.0 * weight, 4.0 * weight))
	_set_deg(targets, "hand_l", Vector3(-2.0 * weight, pulse * 4.0 * weight, -7.0 * weight))
	if channeling:
		_add_deg(targets, "upper_arm_r", Vector3(8.0 * gather * weight, -5.0 * weight, 3.0 * weight))
		_add_deg(targets, "forearm_r", Vector3(-7.0 * gather * weight, 0.0, 0.0))
	if not moving:
		_add_deg(targets, "thigh_l", Vector3(-6.0 * weight, 0.0, -2.0))
		_add_deg(targets, "thigh_r", Vector3(-4.0 * weight, 0.0, 2.0))
		_add_deg(targets, "shin_l", Vector3(12.0 * weight, 0.0, 0.0))
		_add_deg(targets, "shin_r", Vector3(9.0 * weight, 0.0, 0.0))
	return Vector3(-0.012 * weight, -0.02 * weight, -0.018 * weight)


func _apply_item_overlay(
	targets: Dictionary,
	weight: float,
	moving: bool
) -> Vector3:
	var use_wave: float = sin(elapsed * 5.0) * 0.5 + 0.5
	_add_deg(targets, "chest", Vector3(4.0 * weight, -5.0 * weight, 1.5 * weight))
	_add_deg(targets, "head", Vector3(-5.0 * weight, 4.0 * weight, -1.0 * weight))
	_set_deg(targets, "upper_arm_l", Vector3(76.0 * weight, 15.0 * weight, -27.0 * weight))
	_set_deg(targets, "forearm_l", Vector3((-73.0 + use_wave * 8.0) * weight, -4.0 * weight, 3.0 * weight))
	_set_deg(targets, "hand_l", Vector3(-7.0 * weight, 0.0, -8.0 * weight))
	if not moving:
		_add_deg(targets, "pelvis", Vector3(4.0 * weight, 0.0, 0.0))
		_add_deg(targets, "thigh_l", Vector3(-7.0 * weight, 0.0, -2.0))
		_add_deg(targets, "shin_l", Vector3(13.0 * weight, 0.0, 0.0))
	return Vector3(-0.008 * weight, -0.018 * weight, 0.0)


func _apply_interaction_overlay(
	targets: Dictionary,
	weight: float,
	moving: bool
) -> Vector3:
	_add_deg(targets, "pelvis", Vector3(3.0 * weight, -3.0 * weight, 0.0))
	_add_deg(targets, "spine_01", Vector3(5.0 * weight, -4.0 * weight, 0.0))
	_add_deg(targets, "spine_02", Vector3(6.0 * weight, -6.0 * weight, 0.0))
	_add_deg(targets, "chest", Vector3(7.0 * weight, -8.0 * weight, 1.0 * weight))
	_add_deg(targets, "head", Vector3(-4.0 * weight, 5.0 * weight, 0.0))
	_set_deg(targets, "upper_arm_l", Vector3(64.0 * weight, 9.0 * weight, -20.0 * weight))
	_set_deg(targets, "forearm_l", Vector3(-26.0 * weight, -3.0 * weight, 2.0 * weight))
	_set_deg(targets, "hand_l", Vector3(-3.0 * weight, 0.0, -5.0 * weight))
	if not moving:
		_add_deg(targets, "thigh_l", Vector3(-8.0 * weight, 0.0, -2.0))
		_add_deg(targets, "thigh_r", Vector3(-5.0 * weight, 0.0, 2.0))
		_add_deg(targets, "shin_l", Vector3(16.0 * weight, 0.0, 0.0))
	return Vector3(-0.01 * weight, -0.025 * weight, -0.018 * weight)


func _apply_manipulation_overlay(
	targets: Dictionary,
	weight: float,
	moving: bool
) -> Vector3:
	var strain: float = 0.5 + 0.5 * sin(elapsed * 3.2)
	_add_deg(targets, "pelvis", Vector3(7.0 * weight, 0.0, 0.0))
	_add_deg(targets, "spine_01", Vector3(5.0 * weight, 0.0, 0.0))
	_add_deg(targets, "spine_02", Vector3(2.0 * weight, 0.0, 0.0))
	_add_deg(targets, "chest", Vector3(-5.0 * weight, 0.0, 0.0))
	_add_deg(targets, "head", Vector3(3.0 * weight, 0.0, 0.0))
	_set_deg(targets, "upper_arm_l", Vector3((73.0 + strain * 5.0) * weight, 8.0 * weight, -24.0 * weight))
	_set_deg(targets, "upper_arm_r", Vector3((73.0 + strain * 5.0) * weight, -8.0 * weight, 24.0 * weight))
	_set_deg(targets, "forearm_l", Vector3(-18.0 * weight, -4.0 * weight, 2.0 * weight))
	_set_deg(targets, "forearm_r", Vector3(-18.0 * weight, 4.0 * weight, -2.0 * weight))
	_set_deg(targets, "hand_l", Vector3(-2.0 * weight, -4.0 * strain * weight, -4.0 * weight))
	_set_deg(targets, "hand_r", Vector3(-2.0 * weight, 4.0 * strain * weight, 4.0 * weight))
	if not moving:
		_add_deg(targets, "thigh_l", Vector3(-13.0 * weight, 0.0, -3.0))
		_add_deg(targets, "thigh_r", Vector3(-13.0 * weight, 0.0, 3.0))
		_add_deg(targets, "shin_l", Vector3(25.0 * weight, 0.0, 0.0))
		_add_deg(targets, "shin_r", Vector3(25.0 * weight, 0.0, 0.0))
	return Vector3(0.0, -0.04 * weight, -0.012 * weight)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["animation_v9"] = true
	data["context_action_overlays"] = true
	data["context_action"] = last_context_action
	data["context_action_weight"] = snappedf(context_action_weight, 0.01)
	return data
