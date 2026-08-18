extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_animation_v29.gd"
class_name GraceHumanoidSkeletalProxyAnimationV30

# V30 promotes Metal Tether to an authored traversal silhouette. The tether
# controller owns constraint physics and momentum; the skeleton hangs into the
# radial force and lets its legs trail the tangential velocity.

@export_group("Metal Tether Animation")
@export_range(0.0, 1.0, 0.05) var tether_pose_strength: float = 0.9
@export_range(0.0, 30.0, 0.5) var tether_anchor_reach_degrees: float = 18.0
@export_range(0.0, 24.0, 0.5) var tether_trail_degrees: float = 14.0
@export_range(0.0, 0.12, 0.005) var tether_hang_drop: float = 0.055

var tether_controller: MetalTetherSpellController
var last_tether_pose_weight: float = 0.0
var last_tether_anchor_local: Vector3 = Vector3.ZERO
var last_tether_speed_weight: float = 0.0


func _ready() -> void:
	super._ready()
	if actor != null:
		tether_controller = actor.get_node_or_null(
			"MetalTetherController"
		) as MetalTetherSpellController


func _pose_airborne(targets: Dictionary, state_name: String) -> Vector3:
	if (
		tether_controller != null
		and tether_controller.should_handle_locomotion()
	):
		return _pose_metal_tether(targets)
	return super._pose_airborne(targets, state_name)


func _pose_locomotion(targets: Dictionary, delta: float) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_locomotion(targets, delta)
	if (
		tether_controller != null
		and tether_controller.should_handle_locomotion()
		and actor != null
		and actor.is_on_floor()
	):
		pelvis_offset += _apply_grounded_tether_lean(targets)
	return pelvis_offset


func _pose_metal_tether(targets: Dictionary) -> Vector3:
	if actor == null or tether_controller == null:
		return Vector3.ZERO
	var anchor: Node3D = tether_controller.active_anchor
	if anchor == null or not is_instance_valid(anchor):
		return super._pose_airborne(targets, "fall")
	var to_anchor: Vector3 = anchor.global_position - actor.global_position
	if to_anchor.length_squared() <= 0.0001:
		return super._pose_airborne(targets, "fall")
	to_anchor = to_anchor.normalized()
	var local_anchor: Vector3 = (
		actor.global_transform.basis.orthonormalized().inverse()
		* to_anchor
	)
	var local_velocity: Vector3 = (
		actor.global_transform.basis.orthonormalized().inverse()
		* actor.velocity
	)
	var speed_weight: float = clampf(
		tether_controller.tangential_speed
		/ maxf(tether_controller.maximum_swing_speed, 0.1),
		0.0,
		1.0
	)
	var tension_weight: float = clampf(
		tether_controller.current_tension / 1800.0,
		0.12,
		1.0
	)
	var weight: float = clampf(
		maxf(speed_weight * 0.72, tension_weight)
		* tether_pose_strength,
		0.0,
		1.0
	)
	last_tether_pose_weight = weight
	last_tether_anchor_local = local_anchor
	last_tether_speed_weight = speed_weight

	var anchor_side: float = clampf(local_anchor.x, -1.0, 1.0)
	var anchor_up: float = clampf(local_anchor.y, -1.0, 1.0)
	var anchor_forward: float = clampf(-local_anchor.z, -1.0, 1.0)
	var horizontal_speed: float = Vector2(local_velocity.x, local_velocity.z).length()
	var trail_side: float = clampf(
		-local_velocity.x / maxf(horizontal_speed, 0.001),
		-1.0,
		1.0
	) if horizontal_speed > 0.001 else 0.0
	var trail_forward: float = clampf(
		local_velocity.z / maxf(horizontal_speed, 0.001),
		-1.0,
		1.0
	) if horizontal_speed > 0.001 else 0.0

	# Chest points toward the radial support while the pelvis hangs beneath it.
	_set_deg(targets, "pelvis", Vector3(
		8.0 * weight - anchor_up * 5.0 * weight,
		-anchor_side * 8.0 * weight,
		-anchor_side * 8.0 * weight
	))
	_set_deg(targets, "spine_01", Vector3(
		-5.0 * anchor_up * weight,
		anchor_side * 5.0 * weight,
		anchor_side * 5.0 * weight
	))
	_set_deg(targets, "spine_02", Vector3(
		-7.0 * anchor_up * weight,
		anchor_side * 8.0 * weight,
		anchor_side * 7.0 * weight
	))
	_set_deg(targets, "chest", Vector3(
		-10.0 * anchor_up * weight - anchor_forward * 4.0 * weight,
		anchor_side * 12.0 * weight,
		anchor_side * 9.0 * weight
	))
	_set_deg(targets, "head", Vector3(
		6.0 * anchor_up * weight,
		-anchor_side * 5.0 * weight,
		-anchor_side * 3.0 * weight
	))

	# Both arms rise toward the anchor direction but remain asymmetric so Grace
	# looks suspended/braced rather than as though she is doing a pull-up.
	var reach: float = tether_anchor_reach_degrees * weight
	_set_deg(targets, "upper_arm_l", Vector3(
		72.0 + anchor_up * reach,
		anchor_side * 10.0,
		-28.0 - anchor_side * 8.0
	))
	_set_deg(targets, "upper_arm_r", Vector3(
		62.0 + anchor_up * reach * 0.85,
		anchor_side * 8.0,
		24.0 - anchor_side * 6.0
	))
	_set_deg(targets, "forearm_l", Vector3(-42.0 + anchor_up * 8.0, -anchor_side * 4.0, 2.0))
	_set_deg(targets, "forearm_r", Vector3(-36.0 + anchor_up * 7.0, anchor_side * 4.0, -2.0))
	_set_deg(targets, "hand_l", Vector3(-5.0, -anchor_side * 4.0, -4.0))
	_set_deg(targets, "hand_r", Vector3(-4.0, anchor_side * 4.0, 5.0))

	# Legs trail tangential velocity. Faster swings extend them farther and reduce
	# knee bend, producing a readable pendulum silhouette.
	var trail: float = tether_trail_degrees * speed_weight
	_set_deg(targets, "thigh_l", Vector3(
		13.0 + trail_forward * trail,
		0.0,
		-5.0 + trail_side * trail * 0.45
	))
	_set_deg(targets, "thigh_r", Vector3(
		8.0 + trail_forward * trail * 0.9,
		0.0,
		5.0 + trail_side * trail * 0.4
	))
	_set_deg(targets, "shin_l", Vector3(lerpf(31.0, 15.0, speed_weight), 0.0, 0.0))
	_set_deg(targets, "shin_r", Vector3(lerpf(27.0, 13.0, speed_weight), 0.0, 0.0))
	_set_deg(targets, "foot_l", Vector3(14.0 + speed_weight * 5.0, 0.0, 0.0))
	_set_deg(targets, "foot_r", Vector3(14.0 + speed_weight * 5.0, 0.0, 0.0))
	animation_weight = weight
	return Vector3(
		-anchor_side * 0.02 * weight,
		-tether_hang_drop * weight,
		anchor_forward * 0.012 * weight
	)


func _apply_grounded_tether_lean(targets: Dictionary) -> Vector3:
	var anchor: Node3D = tether_controller.active_anchor
	if anchor == null or not is_instance_valid(anchor) or actor == null:
		return Vector3.ZERO
	var to_anchor: Vector3 = anchor.global_position - actor.global_position
	if to_anchor.length_squared() <= 0.0001:
		return Vector3.ZERO
	var local: Vector3 = (
		actor.global_transform.basis.orthonormalized().inverse()
		* to_anchor.normalized()
	)
	var tension: float = clampf(tether_controller.current_tension / 1800.0, 0.0, 1.0)
	if tension <= 0.02:
		return Vector3.ZERO
	var side: float = clampf(local.x, -1.0, 1.0)
	var forward: float = clampf(-local.z, -1.0, 1.0)
	_add_deg(targets, "pelvis", Vector3(-forward * 4.0 * tension, side * 2.0 * tension, side * 3.0 * tension))
	_add_deg(targets, "spine_01", Vector3(-forward * 5.0 * tension, -side * 1.5 * tension, -side * 2.0 * tension))
	_add_deg(targets, "chest", Vector3(-forward * 7.0 * tension, -side * 2.5 * tension, -side * 3.0 * tension))
	_add_deg(targets, "thigh_l", Vector3(-5.0 * tension, 0.0, -side * 2.0 * tension))
	_add_deg(targets, "thigh_r", Vector3(-5.0 * tension, 0.0, -side * 2.0 * tension))
	_add_deg(targets, "shin_l", Vector3(10.0 * tension, 0.0, 0.0))
	_add_deg(targets, "shin_r", Vector3(10.0 * tension, 0.0, 0.0))
	return Vector3(-side * 0.012 * tension, -0.016 * tension, forward * 0.012 * tension)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["animation_v30"] = true
	data["metal_tether_animation"] = true
	data["tether_pose_weight"] = snappedf(last_tether_pose_weight, 0.01)
	data["tether_anchor_local"] = last_tether_anchor_local
	data["tether_speed_weight"] = snappedf(last_tether_speed_weight, 0.01)
	return data
