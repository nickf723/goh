extends Node
class_name GraceLocomotionPolish

@export var enabled: bool = true
@export_range(0.0, 0.08, 0.001) var weight_shift_distance: float = 0.020
@export_range(0.0, 0.08, 0.001) var swing_foot_lift: float = 0.020
@export_range(0.0, 0.05, 0.001) var planted_foot_settle: float = 0.006
@export_range(0.0, 0.12, 0.002) var weight_roll_radians: float = 0.026
@export_range(0.0, 0.12, 0.002) var body_turn_scale: float = 0.042
@export_range(0.0, 0.18, 0.002) var head_turn_scale: float = 0.070
@export_range(0.0, 0.01, 0.0005) var acceleration_shift_scale: float = 0.002

var visual: StylizedActorVisual = null
var actor: CharacterBody3D = null
var lighting_director: LightingDirector3D = null
var visual_root: Node3D = null
var body_root: Node3D = null
var head_root: Node3D = null
var left_leg: Node3D = null
var right_leg: Node3D = null
var previous_offsets: Dictionary = {}
var apply_scheduled: bool = false
var last_quality_scale: float = 0.0
var last_left_stance: float = 0.0
var last_right_stance: float = 0.0
var last_turn_offset: float = 0.0
var applied_frames: int = 0


func _ready() -> void:
	process_priority = -100
	add_to_group("grace_locomotion_polish")
	add_to_group("debuggable")
	_resolve_targets()
	set_meta("grace_locomotion_polish_initialized", visual != null)


func _exit_tree() -> void:
	_remove_previous_offsets()


func _process(_delta: float) -> void:
	_remove_previous_offsets()
	if not enabled:
		return
	if visual == null or not is_instance_valid(visual):
		_resolve_targets()
	if visual == null:
		return
	if not apply_scheduled:
		apply_scheduled = true
		call_deferred("_apply_after_base_pose")


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		_remove_previous_offsets()


func _resolve_targets() -> void:
	visual = null
	actor = null
	lighting_director = null
	if get_tree() == null:
		return
	var player_node: Node = get_tree().get_first_node_in_group("player")
	if player_node is CharacterBody3D:
		actor = player_node as CharacterBody3D
		visual = actor.get_node_or_null("GraceVisualV1") as StylizedActorVisual
	var lighting_node: Node = get_tree().get_first_node_in_group("lighting_director")
	if lighting_node is LightingDirector3D:
		lighting_director = lighting_node as LightingDirector3D
	if visual == null:
		return
	visual_root = visual.get_node_or_null("VisualRoot") as Node3D
	body_root = visual.get_node_or_null("VisualRoot/BodyRoot") as Node3D
	head_root = visual.get_node_or_null("VisualRoot/HeadRoot") as Node3D
	left_leg = visual.get_node_or_null("VisualRoot/LeftLegPivot") as Node3D
	right_leg = visual.get_node_or_null("VisualRoot/RightLegPivot") as Node3D


func _apply_after_base_pose() -> void:
	apply_scheduled = false
	if not enabled or visual == null or not is_instance_valid(visual):
		return
	if visual.presentation_state not in ["locomotion", "idle", "landing"]:
		return
	var quality_scale: float = _quality_scale()
	last_quality_scale = quality_scale
	if quality_scale <= 0.001:
		return

	var movement: float = clampf(visual.movement_weight, 0.0, 1.0)
	var support_wave: float = cos(visual.stride_phase)
	var left_stance: float = clampf(0.5 + support_wave * 0.5, 0.0, 1.0)
	var right_stance: float = 1.0 - left_stance
	last_left_stance = left_stance
	last_right_stance = right_stance

	var body_position_offset := Vector3.ZERO
	var body_rotation_offset := Vector3.ZERO
	var head_rotation_offset := Vector3.ZERO
	var left_leg_position_offset := Vector3.ZERO
	var right_leg_position_offset := Vector3.ZERO

	if visual.presentation_state == "locomotion":
		body_position_offset.x -= support_wave * weight_shift_distance * movement
		body_rotation_offset.z += support_wave * weight_roll_radians * movement
		left_leg_position_offset.y += (
			(1.0 - left_stance) * swing_foot_lift
			- left_stance * planted_foot_settle
		) * movement
		right_leg_position_offset.y += (
			(1.0 - right_stance) * swing_foot_lift
			- right_stance * planted_foot_settle
		) * movement

		if actor != null and is_instance_valid(actor):
			var local_acceleration: Vector3 = (
				actor.global_basis.inverse() * visual.smoothed_acceleration
			)
			body_position_offset.z += clampf(
				local_acceleration.z * acceleration_shift_scale,
				-0.026,
				0.026
			) * movement

	var turn: float = clampf(
		visual.turn_velocity * body_turn_scale,
		-0.13,
		0.13
	)
	last_turn_offset = turn
	body_rotation_offset.y -= turn * lerpf(0.55, 1.0, movement)
	head_rotation_offset.y += clampf(
		visual.turn_velocity * head_turn_scale,
		-0.18,
		0.18
	) * lerpf(0.45, 1.0, movement)

	body_position_offset *= quality_scale
	body_rotation_offset *= quality_scale
	head_rotation_offset *= quality_scale
	left_leg_position_offset *= quality_scale
	right_leg_position_offset *= quality_scale

	_apply_offset(body_root, body_position_offset, body_rotation_offset, "body")
	_apply_offset(head_root, Vector3.ZERO, head_rotation_offset, "head")
	_apply_offset(left_leg, left_leg_position_offset, Vector3.ZERO, "left_leg")
	_apply_offset(right_leg, right_leg_position_offset, Vector3.ZERO, "right_leg")
	applied_frames += 1


func _apply_offset(
	node: Node3D,
	position_offset: Vector3,
	rotation_offset: Vector3,
	key: String
) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.position += position_offset
	node.rotation += rotation_offset
	previous_offsets[key] = {
		"ref": weakref(node),
		"position": position_offset,
		"rotation": rotation_offset,
	}


func _remove_previous_offsets() -> void:
	for raw_key: Variant in previous_offsets.keys():
		var record: Dictionary = previous_offsets[raw_key] as Dictionary
		var weak_value: Variant = record.get("ref", null)
		if not weak_value is WeakRef:
			continue
		var node_value: Variant = (weak_value as WeakRef).get_ref()
		if not node_value is Node3D:
			continue
		var node: Node3D = node_value as Node3D
		node.position -= record.get("position", Vector3.ZERO) as Vector3
		node.rotation -= record.get("rotation", Vector3.ZERO) as Vector3
	previous_offsets.clear()


func _quality_scale() -> float:
	if lighting_director == null or not is_instance_valid(lighting_director):
		var lighting_node: Node = (
			get_tree().get_first_node_in_group("lighting_director")
			if get_tree() != null
			else null
		)
		if lighting_node is LightingDirector3D:
			lighting_director = lighting_node as LightingDirector3D
	if lighting_director == null:
		return 1.0
	match lighting_director.quality:
		LightingDirector3D.Quality.PERFORMANCE:
			return 0.0
		LightingDirector3D.Quality.BALANCED:
			return 0.65
		_:
			return 1.0


func get_debug_data() -> Dictionary:
	return {
		"grace_locomotion_polish": true,
		"initialized": visual != null,
		"enabled": enabled,
		"presentation_state": visual.presentation_state if visual != null else "none",
		"quality_scale": last_quality_scale,
		"left_stance": snappedf(last_left_stance, 0.01),
		"right_stance": snappedf(last_right_stance, 0.01),
		"turn_offset": snappedf(last_turn_offset, 0.001),
		"applied_frames": applied_frames,
		"additive_after_base_pose": true,
		"grounded_states_only": true,
		"combat_pose_authority": false,
		"gameplay_authority": false,
	}
