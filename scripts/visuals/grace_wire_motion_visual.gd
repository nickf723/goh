extends "res://scripts/visuals/stylized_actor_visual.gd"
class_name GraceWireMotionVisual

const WeaponCharacterPoseCatalogScript = preload(
	"res://scripts/weapons/weapon_character_pose_catalog.gd"
)

@onready var wire_skeleton_renderer: GraceWireSkeletonRenderer = (
	get_node_or_null("WireSkeletonRenderer") as GraceWireSkeletonRenderer
)
@onready var ground_motion_motor: PlayerGroundMotionMotor = (
	get_parent().get_node_or_null("GroundMotionMotor") as PlayerGroundMotionMotor
)
@onready var dodge_motion_controller: PlayerDodgeController = (
	get_parent().get_node_or_null("PlayerDodgeController") as PlayerDodgeController
)
@onready var combat_footwork_controller: PlayerCombatFootworkController = (
	get_parent().get_node_or_null("CombatFootworkController") as PlayerCombatFootworkController
)

var control_pose_sample: Dictionary = {}
var motion_accent_root_position: Vector3 = Vector3.ZERO
var motion_accent_root_rotation: Vector3 = Vector3.ZERO
var motion_accent_body_position: Vector3 = Vector3.ZERO
var motion_accent_body_rotation: Vector3 = Vector3.ZERO
var motion_accent_left_leg_position: Vector3 = Vector3.ZERO
var motion_accent_left_leg_rotation: Vector3 = Vector3.ZERO
var motion_accent_right_leg_position: Vector3 = Vector3.ZERO
var motion_accent_right_leg_rotation: Vector3 = Vector3.ZERO


func _ready() -> void:
	# Gameplay controllers advance first. Grace samples their intent, the wire
	# skeleton follows her, and the residual blade animator runs last.
	process_priority = 40
	super._ready()
	add_to_group("grace_wire_motion_rig")
	if wire_skeleton_renderer != null:
		wire_skeleton_renderer.call_deferred("sample_now")


func sample_animation_pose(delta: float) -> void:
	_remove_motion_accent()
	control_pose_sample = _resolve_control_pose_sample()
	super.sample_animation_pose(delta)
	_pose_controlled_hands(delta)
	_apply_ground_motion_accent()
	_apply_dodge_motion_accent()
	_apply_combat_footwork_accent()
	_apply_dodge_iframe_highlight()
	sync_animation_anchors()


func build_attack_pose() -> Dictionary:
	if control_pose_sample.is_empty():
		return super.build_attack_pose()
	return {
		"body": control_pose_sample.get("body", Vector3.ZERO),
		"head": control_pose_sample.get("head", Vector3.ZERO),
		"left_arm": control_pose_sample.get("left_arm", Vector3.ZERO),
		"right_arm": control_pose_sample.get("right_arm", Vector3.ZERO),
	}


func get_pose_nodes() -> Array[Node3D]:
	var nodes: Array[Node3D] = super.get_pose_nodes()
	for hand: Node3D in [left_hand, right_hand]:
		if hand != null and not nodes.has(hand):
			nodes.append(hand)
	return nodes


func sync_animation_anchors() -> void:
	super.sync_animation_anchors()
	_sync_anchor_transform(head_root, head_anchor, Vector3(0.0, 0.05, 0.0))
	_sync_anchor_transform(left_hand, left_hand_anchor)
	_sync_anchor_transform(right_hand, right_hand_anchor)
	_sync_anchor_transform(body_root, chest_vfx_anchor, Vector3(0.0, 0.34, -0.18))
	if right_hand_anchor != null and weapon_hand_anchor != null:
		weapon_hand_anchor.global_transform = right_hand_anchor.global_transform


func set_wire_outfit(outfit_id: String) -> void:
	if wire_skeleton_renderer != null:
		wire_skeleton_renderer.set_outfit_id(outfit_id)


func get_animation_debug_data() -> Dictionary:
	var debug_data: Dictionary = super.get_animation_debug_data()
	var right_hand_position: Vector3 = control_pose_sample.get(
		"right_hand_position",
		Vector3.ZERO
	)
	debug_data["rig_mode"] = "wire_skeleton"
	debug_data["control_pose_id"] = str(control_pose_sample.get("profile_id", ""))
	debug_data["control_pose_phase"] = str(control_pose_sample.get("phase", "idle"))
	debug_data["control_pose_weight"] = snappedf(
		float(control_pose_sample.get("phase_weight", 0.0)),
		0.01
	)
	debug_data["right_hand_drive"] = right_hand_position.length()
	if ground_motion_motor != null:
		var ground_motion: Dictionary = ground_motion_motor.get_debug_data()
		debug_data["ground_motion_state"] = str(ground_motion.get("state", "idle"))
		debug_data["ground_target_speed"] = float(ground_motion.get("target_speed", 0.0))
		debug_data["ground_actual_speed"] = float(ground_motion.get("actual_speed", 0.0))
		debug_data["ground_input_strength"] = float(ground_motion.get("input_strength", 0.0))
		debug_data["ground_turn_angle"] = float(ground_motion.get("turn_angle_degrees", 0.0))
		debug_data["ground_braking_weight"] = float(ground_motion.get("braking_weight", 0.0))
		debug_data["ground_reversal_weight"] = float(ground_motion.get("reversal_weight", 0.0))
	if dodge_motion_controller != null:
		var dodge_motion: Dictionary = dodge_motion_controller.get_debug_data()
		debug_data["dodge_phase"] = str(dodge_motion.get("phase", "idle"))
		debug_data["dodge_progress"] = float(dodge_motion.get("progress", 0.0))
		debug_data["dodge_kind"] = str(dodge_motion.get("kind", "forward"))
		debug_data["dodge_speed"] = float(dodge_motion.get("speed", 0.0))
		debug_data["dodge_iframe"] = bool(dodge_motion.get("iframe", false))
		debug_data["dodge_iframe_weight"] = float(dodge_motion.get("iframe_weight", 0.0))
		debug_data["dodge_chain_count"] = int(dodge_motion.get("chain_count", 0))
		debug_data["dodge_chain_ready"] = bool(dodge_motion.get("chain_ready", false))
		debug_data["dodge_buffered_follow_up"] = str(dodge_motion.get("buffered_follow_up", ""))
	if combat_footwork_controller != null:
		var footwork: Dictionary = combat_footwork_controller.get_debug_data()
		debug_data["footwork_active"] = bool(footwork.get("active", false))
		debug_data["footwork_root_active"] = bool(footwork.get("root_motion_active", false))
		debug_data["footwork_profile_id"] = str(footwork.get("profile_id", ""))
		debug_data["footwork_phase"] = str(footwork.get("phase", "idle"))
		debug_data["footwork_progress"] = float(footwork.get("progress", 0.0))
		debug_data["footwork_plant_foot"] = str(footwork.get("plant_foot", "both"))
		debug_data["footwork_requested_distance"] = float(footwork.get("requested_distance", 0.0))
		debug_data["footwork_actual_distance"] = float(footwork.get("actual_distance", 0.0))
		debug_data["footwork_blocked"] = bool(footwork.get("blocked", false))
	if wire_skeleton_renderer != null:
		var wire_data: Dictionary = wire_skeleton_renderer.get_debug_data()
		var grounding: Dictionary = wire_data.get("grounding", {}) as Dictionary
		debug_data["wire_joint_count"] = int(wire_data.get("joint_count", 0))
		debug_data["wire_segment_count"] = int(wire_data.get("segment_count", 0))
		debug_data["wire_finite_pose"] = bool(wire_data.get("finite_pose", false))
		debug_data["wire_outfit_id"] = str(wire_data.get("outfit_id", ""))
		debug_data["wire_grounding_active"] = bool(grounding.get("active", false))
		debug_data["wire_left_ground_hit"] = bool(grounding.get("left_hit", false))
		debug_data["wire_right_ground_hit"] = bool(grounding.get("right_hit", false))
		debug_data["wire_left_toe_offset"] = float(grounding.get("left_toe_offset", 0.0))
		debug_data["wire_right_toe_offset"] = float(grounding.get("right_toe_offset", 0.0))
	return debug_data


func _resolve_control_pose_sample() -> Dictionary:
	if weapon_controller == null:
		return {}
	var attack: WeaponAttackDefinition = (
		weapon_controller.get("current_attack") as WeaponAttackDefinition
	)
	if attack == null or not WeaponCharacterPoseCatalogScript.has_profile(attack.character_pose_id):
		return {}
	var attack_speed: float = 1.0
	if weapon_controller.has_method("get_attack_speed"):
		attack_speed = float(weapon_controller.call("get_attack_speed"))
	return WeaponCharacterPoseCatalogScript.sample_attack(
		attack,
		float(weapon_controller.get("current_attack_elapsed")),
		attack_speed
	)


func _pose_controlled_hands(delta: float) -> void:
	var left_rotation: Vector3 = control_pose_sample.get("left_hand_rotation", Vector3.ZERO)
	var right_rotation: Vector3 = control_pose_sample.get("right_hand_rotation", Vector3.ZERO)
	var left_position: Vector3 = control_pose_sample.get("left_hand_position", Vector3.ZERO)
	var right_position: Vector3 = control_pose_sample.get("right_hand_position", Vector3.ZERO)
	var response: float = pose_response * (1.35 if not control_pose_sample.is_empty() else 1.0)
	pose_node(left_hand, left_rotation, left_position, delta, response)
	pose_node(right_hand, right_rotation, right_position, delta, response)


func _remove_motion_accent() -> void:
	if visual_root != null:
		visual_root.position -= motion_accent_root_position
		visual_root.rotation -= motion_accent_root_rotation
	if body_root != null:
		body_root.position -= motion_accent_body_position
		body_root.rotation -= motion_accent_body_rotation
	if left_leg != null:
		left_leg.position -= motion_accent_left_leg_position
		left_leg.rotation -= motion_accent_left_leg_rotation
	if right_leg != null:
		right_leg.position -= motion_accent_right_leg_position
		right_leg.rotation -= motion_accent_right_leg_rotation
	motion_accent_root_position = Vector3.ZERO
	motion_accent_root_rotation = Vector3.ZERO
	motion_accent_body_position = Vector3.ZERO
	motion_accent_body_rotation = Vector3.ZERO
	motion_accent_left_leg_position = Vector3.ZERO
	motion_accent_left_leg_rotation = Vector3.ZERO
	motion_accent_right_leg_position = Vector3.ZERO
	motion_accent_right_leg_rotation = Vector3.ZERO


func _apply_ground_motion_accent() -> void:
	if ground_motion_motor == null or not control_pose_sample.is_empty():
		return
	if dodge_motion_controller != null and dodge_motion_controller.is_dodge_active():
		return
	if presentation_state not in ["idle", "locomotion"]:
		return
	var motion: Dictionary = ground_motion_motor.get_debug_data()
	var acceleration: float = float(motion.get("acceleration_weight", 0.0))
	var braking: float = float(motion.get("braking_weight", 0.0))
	var reversal: float = float(motion.get("reversal_weight", 0.0))
	var turning: float = float(motion.get("turning_weight", 0.0))
	var local_direction: Vector3 = motion.get("local_direction", Vector3.ZERO)

	motion_accent_root_position.y = -0.025 * braking - 0.055 * reversal
	motion_accent_root_rotation.z = -local_direction.x * (0.045 * turning + 0.035 * reversal)
	motion_accent_body_rotation.x = -0.025 * acceleration + 0.075 * braking - 0.035 * reversal
	motion_accent_body_rotation.y = -local_direction.x * (0.055 * turning + 0.08 * reversal)
	_apply_motion_accent()


func _apply_dodge_motion_accent() -> void:
	if dodge_motion_controller == null or not dodge_motion_controller.is_dodge_active():
		return
	if not control_pose_sample.is_empty():
		return
	var profile: DodgeMotionProfile = dodge_motion_controller.profile
	var progress: float = dodge_motion_controller.get_normalized_progress()
	var phase: String = dodge_motion_controller.get_dodge_phase()
	var pose_weight: float = dodge_motion_controller.get_visual_pose_weight()
	var local_direction: Vector3 = dodge_motion_controller.dodge_direction
	if actor != null:
		local_direction = actor.global_transform.basis.inverse() * local_direction

	var launch_compression: float = profile.launch_compression if profile != null else 0.05
	var landing_compression: float = profile.landing_compression if profile != null else 0.08
	var body_lean: float = profile.body_lean_radians if profile != null else 0.18
	var launch_weight: float = 1.0 - smoothstep(0.0, maxf(dodge_motion_controller.get_launch_end(), 0.01), progress)
	var landing_weight: float = 0.0
	if phase in ["landing", "recovery"]:
		landing_weight = smoothstep(
			dodge_motion_controller.get_travel_end(),
			1.0,
			progress
		)

	motion_accent_root_position.y = -launch_compression * launch_weight - landing_compression * landing_weight
	motion_accent_root_rotation.z = -local_direction.x * body_lean * 0.55 * pose_weight
	motion_accent_body_rotation.x = -local_direction.z * body_lean * pose_weight
	motion_accent_body_rotation.y = -local_direction.x * body_lean * 0.35 * pose_weight
	_apply_motion_accent()


func _apply_combat_footwork_accent() -> void:
	if combat_footwork_controller == null:
		return
	if not combat_footwork_controller.is_visual_footwork_active():
		return
	if presentation_state != "attack":
		return
	var sample: Dictionary = combat_footwork_controller.get_visual_pose()
	if sample.is_empty():
		return
	var strength: float = (
		combat_footwork_controller.profile.pose_strength
		if combat_footwork_controller.profile != null
		else 1.0
	)
	motion_accent_root_position = (
		sample.get("root_position", Vector3.ZERO) as Vector3
	) * strength
	motion_accent_root_rotation = (
		sample.get("root_rotation", Vector3.ZERO) as Vector3
	) * strength
	motion_accent_body_position = (
		sample.get("body_position", Vector3.ZERO) as Vector3
	) * strength
	motion_accent_body_rotation = (
		sample.get("body_rotation", Vector3.ZERO) as Vector3
	) * strength
	motion_accent_left_leg_position = (
		sample.get("left_leg_position", Vector3.ZERO) as Vector3
	) * strength
	motion_accent_left_leg_rotation = (
		sample.get("left_leg_rotation", Vector3.ZERO) as Vector3
	) * strength
	motion_accent_right_leg_position = (
		sample.get("right_leg_position", Vector3.ZERO) as Vector3
	) * strength
	motion_accent_right_leg_rotation = (
		sample.get("right_leg_rotation", Vector3.ZERO) as Vector3
	) * strength
	_apply_motion_accent()


func _apply_motion_accent() -> void:
	if visual_root != null:
		visual_root.position += motion_accent_root_position
		visual_root.rotation += motion_accent_root_rotation
	if body_root != null:
		body_root.position += motion_accent_body_position
		body_root.rotation += motion_accent_body_rotation
	if left_leg != null:
		left_leg.position += motion_accent_left_leg_position
		left_leg.rotation += motion_accent_left_leg_rotation
	if right_leg != null:
		right_leg.position += motion_accent_right_leg_position
		right_leg.rotation += motion_accent_right_leg_rotation


func _apply_dodge_iframe_highlight() -> void:
	if wire_skeleton_renderer == null:
		return
	var weight: float = 0.0
	var peak_energy: float = 2.15
	if dodge_motion_controller != null:
		weight = dodge_motion_controller.get_iframe_visual_weight()
		if dodge_motion_controller.profile != null:
			peak_energy = dodge_motion_controller.profile.iframe_emission_multiplier
	var energy: float = lerpf(1.35, peak_energy, weight)
	for material: StandardMaterial3D in [
		wire_skeleton_renderer.center_material,
		wire_skeleton_renderer.left_material,
		wire_skeleton_renderer.right_material,
		wire_skeleton_renderer.joint_material,
	]:
		if material != null:
			material.emission_energy_multiplier = energy


func _sync_anchor_transform(
	source: Node3D,
	target: Node3D,
	local_offset: Vector3 = Vector3.ZERO
) -> void:
	if source == null or target == null:
		return
	var basis: Basis = source.global_basis.orthonormalized()
	target.global_transform = Transform3D(basis, source.to_global(local_offset))
