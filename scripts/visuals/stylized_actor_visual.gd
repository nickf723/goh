extends Node3D
class_name StylizedActorVisual

@export_group("Locomotion")
@export var idle_bob_height: float = 0.014
@export var idle_bob_speed: float = 2.1
@export var movement_bob_height: float = 0.045
@export var movement_bob_speed: float = 8.2
@export var stride_radians: float = 0.58
@export var arm_swing_radians: float = 0.42
@export var maximum_lean_radians: float = 0.11
@export var locomotion_speed_reference: float = 5.0

@export_group("Response")
@export var pose_response: float = 12.0
@export var accessory_response: float = 8.0
@export var idle_breath_amount: float = 0.018
@export var action_pose_strength: float = 1.0

@onready var visual_root: Node3D = get_node_or_null("VisualRoot") as Node3D
@onready var body_root: Node3D = get_node_or_null("VisualRoot/BodyRoot") as Node3D
@onready var head_root: Node3D = get_node_or_null("VisualRoot/HeadRoot") as Node3D
@onready var left_shoulder: Node3D = get_node_or_null("VisualRoot/LeftShoulderPivot") as Node3D
@onready var right_shoulder: Node3D = get_node_or_null("VisualRoot/RightShoulderPivot") as Node3D
@onready var left_leg: Node3D = get_node_or_null("VisualRoot/LeftLegPivot") as Node3D
@onready var right_leg: Node3D = get_node_or_null("VisualRoot/RightLegPivot") as Node3D
@onready var sash_tail: Node3D = get_node_or_null("VisualRoot/SashTailPivot") as Node3D
@onready var left_hair_lock: Node3D = get_node_or_null("VisualRoot/LeftHairLockPivot") as Node3D
@onready var right_hair_lock: Node3D = get_node_or_null("VisualRoot/RightHairLockPivot") as Node3D
@onready var left_hand: Node3D = get_node_or_null("VisualRoot/LeftShoulderPivot/LeftHand") as Node3D
@onready var right_hand: Node3D = get_node_or_null("VisualRoot/RightShoulderPivot/RightHand") as Node3D

@onready var head_anchor: Marker3D = get_node_or_null("HeadAnchor") as Marker3D
@onready var left_hand_anchor: Marker3D = get_node_or_null("LeftHandAnchor") as Marker3D
@onready var right_hand_anchor: Marker3D = get_node_or_null("RightHandAnchor") as Marker3D
@onready var chest_vfx_anchor: Marker3D = get_node_or_null("ChestVFXAnchor") as Marker3D
@onready var feet_vfx_anchor: Marker3D = get_node_or_null("FeetVFXAnchor") as Marker3D

var actor: CharacterBody3D
var action_state: PlayerActionState
var weapon_controller: Node
var dodge_controller: Node
var defense_controller: Node
var aerial_locomotion: Node
var weapon_hand_anchor: Node3D

var elapsed: float = 0.0
var presentation_state: String = "idle"
var movement_weight: float = 0.0
var stride_phase: float = 0.0
var base_positions: Dictionary = {}
var base_rotations: Dictionary = {}
var base_scales: Dictionary = {}


func _ready() -> void:
	actor = get_parent() as CharacterBody3D
	if actor != null:
		action_state = actor.get_node_or_null("PlayerActionState") as PlayerActionState
		weapon_controller = actor.get_node_or_null("WeaponController")
		dodge_controller = actor.get_node_or_null("PlayerDodgeController")
		defense_controller = actor.get_node_or_null("PlayerDefenseController")
		aerial_locomotion = actor.get_node_or_null("AerialLocomotion")
		weapon_hand_anchor = actor.get_node_or_null("WeaponController/HandAnchor") as Node3D

	for node: Node3D in get_pose_nodes():
		remember_base_pose(node)

	add_to_group("debuggable")
	sync_animation_anchors()


func _process(delta: float) -> void:
	sample_animation_pose(delta)


func sample_animation_pose(delta: float) -> void:
	if visual_root == null:
		return

	elapsed += maxf(delta, 0.0)

	var horizontal_velocity: Vector3 = Vector3.ZERO
	if actor != null:
		horizontal_velocity = Vector3(actor.velocity.x, 0.0, actor.velocity.z)

	var speed: float = horizontal_velocity.length()
	movement_weight = clampf(speed / maxf(locomotion_speed_reference, 0.1), 0.0, 1.0)
	stride_phase = elapsed * lerpf(idle_bob_speed, movement_bob_speed, movement_weight)
	presentation_state = resolve_presentation_state()

	var root_rotation: Vector3 = Vector3.ZERO
	var root_position: Vector3 = Vector3.ZERO
	var body_rotation: Vector3 = Vector3.ZERO
	var body_position: Vector3 = Vector3.ZERO
	var head_rotation: Vector3 = Vector3.ZERO
	var left_arm_rotation: Vector3 = Vector3.ZERO
	var right_arm_rotation: Vector3 = Vector3.ZERO
	var left_leg_rotation: Vector3 = Vector3.ZERO
	var right_leg_rotation: Vector3 = Vector3.ZERO

	var idle_bob: float = sin(elapsed * idle_bob_speed) * idle_bob_height
	var step_wave: float = sin(stride_phase)
	var movement_bob: float = abs(sin(stride_phase)) * movement_bob_height
	root_position.y = lerpf(idle_bob, movement_bob, movement_weight)

	var local_velocity: Vector3 = horizontal_velocity
	if actor != null:
		local_velocity = actor.global_transform.basis.inverse() * horizontal_velocity
	root_rotation.x = clampf(
		local_velocity.z * 0.018,
		-maximum_lean_radians,
		maximum_lean_radians
	)
	root_rotation.z = clampf(
		-local_velocity.x * 0.018,
		-maximum_lean_radians,
		maximum_lean_radians
	)

	left_leg_rotation.x = step_wave * stride_radians * movement_weight
	right_leg_rotation.x = -step_wave * stride_radians * movement_weight
	left_arm_rotation.x = -step_wave * arm_swing_radians * movement_weight
	right_arm_rotation.x = step_wave * arm_swing_radians * movement_weight
	body_rotation.y = -step_wave * 0.035 * movement_weight
	head_rotation.y = sin(elapsed * 0.72) * 0.025 * (1.0 - movement_weight)

	match presentation_state:
		"attack":
			var attack_pose: Dictionary = build_attack_pose()
			body_rotation += attack_pose.get("body", Vector3.ZERO)
			head_rotation += attack_pose.get("head", Vector3.ZERO)
			left_arm_rotation += attack_pose.get("left_arm", Vector3.ZERO)
			right_arm_rotation += attack_pose.get("right_arm", Vector3.ZERO)
		"guard":
			body_rotation.x -= 0.11
			body_rotation.y += 0.08
			body_position.y -= 0.035
			left_arm_rotation += Vector3(-0.92, 0.1, -0.62)
			right_arm_rotation += Vector3(-1.08, -0.16, 0.52)
			left_leg_rotation.x -= 0.15
			right_leg_rotation.x += 0.18
			head_rotation.x += 0.08
		"dodge":
			var dodge_wave: float = get_dodge_wave()
			root_position.y -= 0.16 * dodge_wave
			body_rotation.x -= 0.42 * dodge_wave
			body_rotation.z += get_dodge_side_lean() * 0.24 * dodge_wave
			left_arm_rotation += Vector3(-0.64, 0.0, -0.24)
			right_arm_rotation += Vector3(-0.64, 0.0, 0.24)
			left_leg_rotation.x -= 0.32 * dodge_wave
			right_leg_rotation.x -= 0.18 * dodge_wave
		"hit":
			var recoil: float = 0.82 + sin(elapsed * 34.0) * 0.06
			body_rotation.x += 0.28 * recoil
			body_rotation.z -= 0.12 * recoil
			head_rotation.x -= 0.16 * recoil
			left_arm_rotation += Vector3(0.38, 0.0, -0.32)
			right_arm_rotation += Vector3(0.5, 0.0, 0.4)
		"cast":
			body_rotation.y -= 0.18
			body_rotation.x -= 0.05
			right_arm_rotation += Vector3(-1.2, -0.18, 0.34)
			left_arm_rotation += Vector3(-0.42, 0.2, -0.38)
			head_rotation.x -= 0.08
			root_position.y += 0.025
		"item":
			body_rotation.y -= 0.08
			right_arm_rotation += Vector3(-1.38, -0.12, 0.28)
			left_arm_rotation += Vector3(-0.22, 0.0, -0.12)
			head_rotation.x += 0.1
		"interact":
			body_rotation.y -= 0.12
			right_arm_rotation += Vector3(-0.88, -0.08, 0.18)
			head_rotation.x += 0.06
		"flight":
			root_rotation.x -= 0.16
			body_rotation.x -= 0.12
			left_arm_rotation += Vector3(0.22, 0.0, -1.02)
			right_arm_rotation += Vector3(0.22, 0.0, 1.02)
			left_leg_rotation.x += 0.18
			right_leg_rotation.x -= 0.18
			root_position.y += sin(elapsed * 3.2) * 0.035
		"jump":
			body_rotation.x -= 0.08
			left_arm_rotation.x -= 0.48
			right_arm_rotation.x -= 0.48
			left_leg_rotation.x += 0.28
			right_leg_rotation.x -= 0.18
		"fall":
			body_rotation.x += 0.06
			left_arm_rotation += Vector3(-0.12, 0.0, -0.7)
			right_arm_rotation += Vector3(-0.12, 0.0, 0.7)
			left_leg_rotation.x -= 0.12
			right_leg_rotation.x += 0.14
		"defeated":
			root_rotation = Vector3(0.0, 0.0, -1.38)
			root_position = Vector3(-0.08, 0.54, 0.0)
			body_rotation = Vector3(0.08, 0.0, 0.0)
			head_rotation = Vector3(0.0, 0.0, -0.14)
			left_arm_rotation = Vector3(0.28, 0.0, -0.5)
			right_arm_rotation = Vector3(-0.18, 0.0, 0.36)
			left_leg_rotation.x = -0.18
			right_leg_rotation.x = 0.22

	var response: float = pose_response
	if presentation_state == "defeated":
		response = 8.0

	pose_node(visual_root, root_rotation, root_position, delta, response)
	pose_node(body_root, body_rotation, body_position, delta, response)
	pose_node(head_root, head_rotation, Vector3.ZERO, delta, response)
	pose_node(left_shoulder, left_arm_rotation, Vector3.ZERO, delta, response)
	pose_node(right_shoulder, right_arm_rotation, Vector3.ZERO, delta, response)
	pose_node(left_leg, left_leg_rotation, Vector3.ZERO, delta, response)
	pose_node(right_leg, right_leg_rotation, Vector3.ZERO, delta, response)
	pose_accessories(delta, speed)
	pose_breathing(delta)
	sync_animation_anchors()


func resolve_presentation_state() -> String:
	if action_state != null:
		if action_state.is_defeated:
			return "defeated"
		if action_state.is_staggered:
			return "hit"

	if defense_controller != null and defense_controller.has_method("is_hit_reaction_active"):
		if bool(defense_controller.call("is_hit_reaction_active")):
			return "hit"

	if dodge_controller != null and dodge_controller.has_method("is_dodge_active"):
		if bool(dodge_controller.call("is_dodge_active")):
			return "dodge"

	if action_state != null:
		if action_state.is_attacking:
			return "attack"
		if action_state.is_guarding:
			return "guard"
		if action_state.is_casting:
			return "cast"
		if action_state.is_using_item:
			return "item"
		if action_state.is_interacting or action_state.is_manipulating:
			return "interact"
		if action_state.is_flying:
			return "flight"

	if aerial_locomotion != null and bool(aerial_locomotion.get("flight_active")):
		return "flight"

	if actor != null and not actor.is_on_floor():
		return "jump" if actor.velocity.y > 0.05 else "fall"

	if movement_weight > 0.04:
		return "locomotion"

	return "idle"


func build_attack_pose() -> Dictionary:
	var normalized: float = 0.45
	var heavy_multiplier: float = 1.0

	if weapon_controller != null:
		var attack: WeaponAttackDefinition = (
			weapon_controller.get("current_attack") as WeaponAttackDefinition
		)
		var attack_elapsed: float = float(weapon_controller.get("current_attack_elapsed"))
		if attack != null:
			var attack_speed: float = 1.0
			if weapon_controller.has_method("get_attack_speed"):
				attack_speed = float(weapon_controller.call("get_attack_speed"))
			var total_duration: float = 0.6
			total_duration = attack.get_total_duration(attack_speed)
			normalized = clampf(attack_elapsed / maxf(total_duration, 0.01), 0.0, 1.0)
			if attack.input_kind == "heavy":
				heavy_multiplier = 1.2

	var windup: float = smoothstep(0.0, 0.28, normalized)
	var strike: float = smoothstep(0.24, 0.58, normalized)
	var recovery: float = smoothstep(0.66, 1.0, normalized)
	var action_weight: float = (1.0 - recovery) * action_pose_strength
	var attack_arm_x: float = lerpf(0.76 * windup, -1.18, strike)
	var attack_twist: float = lerpf(-0.38 * windup, 0.54, strike)

	return {
		"body": Vector3(
			-0.08 * action_weight * heavy_multiplier,
			attack_twist * action_weight * heavy_multiplier,
			0.0
		),
		"head": Vector3(0.0, -attack_twist * 0.32 * action_weight, 0.0),
		"left_arm": Vector3(
			-0.22 * action_weight,
			0.0,
			-0.28 * action_weight
		),
		"right_arm": Vector3(
			attack_arm_x * action_weight * heavy_multiplier,
			0.0,
			0.42 * action_weight
		),
	}


func pose_accessories(delta: float, speed: float) -> void:
	var action_energy: float = 1.0 if presentation_state in [
		"attack",
		"dodge",
		"hit",
		"cast",
		"flight",
	] else 0.0
	var sway: float = sin(elapsed * (3.2 + speed * 0.35))
	var sash_rotation := Vector3(
		0.18 * movement_weight + 0.22 * action_energy,
		0.0,
		sway * (0.08 + 0.12 * movement_weight)
	)
	var hair_rotation := Vector3(
		0.08 * movement_weight + 0.1 * action_energy,
		0.0,
		sway * 0.055
	)
	pose_node(sash_tail, sash_rotation, Vector3.ZERO, delta, accessory_response)
	pose_node(left_hair_lock, hair_rotation + Vector3(0.0, 0.0, -0.025), Vector3.ZERO, delta, accessory_response)
	pose_node(right_hair_lock, hair_rotation + Vector3(0.0, 0.0, 0.025), Vector3.ZERO, delta, accessory_response)


func pose_breathing(delta: float) -> void:
	if body_root == null:
		return
	var base_scale: Vector3 = get_base_scale(body_root)
	var breath_weight: float = 1.0
	if presentation_state not in ["idle", "guard", "item"]:
		breath_weight = 0.25
	var breath: float = sin(elapsed * idle_bob_speed) * idle_breath_amount * breath_weight
	var target_scale := Vector3(
		base_scale.x * (1.0 - breath * 0.22),
		base_scale.y * (1.0 + breath),
		base_scale.z * (1.0 - breath * 0.22)
	)
	body_root.scale = body_root.scale.lerp(
		target_scale,
		clampf(delta * pose_response, 0.0, 1.0)
	)


func get_dodge_wave() -> float:
	if dodge_controller == null:
		return 1.0
	var duration: float = maxf(float(dodge_controller.get("dodge_duration")), 0.01)
	var remaining: float = maxf(float(dodge_controller.get("dodge_timer")), 0.0)
	var progress: float = clampf(1.0 - remaining / duration, 0.0, 1.0)
	return sin(progress * PI)


func get_dodge_side_lean() -> float:
	if dodge_controller == null or actor == null:
		return 0.0
	var direction: Vector3 = dodge_controller.get("dodge_direction")
	var local_direction: Vector3 = actor.global_transform.basis.inverse() * direction
	return clampf(local_direction.x, -1.0, 1.0)


func sync_animation_anchors() -> void:
	if head_root != null and head_anchor != null:
		head_anchor.global_position = head_root.global_position + head_root.global_basis.y * 0.05
	if left_hand != null and left_hand_anchor != null:
		left_hand_anchor.global_position = left_hand.global_position
	if right_hand != null and right_hand_anchor != null:
		right_hand_anchor.global_position = right_hand.global_position
	if body_root != null and chest_vfx_anchor != null:
		chest_vfx_anchor.global_position = body_root.to_global(Vector3(0.0, 0.34, -0.28))
	if visual_root != null and feet_vfx_anchor != null:
		feet_vfx_anchor.global_position = visual_root.to_global(Vector3(0.0, 0.06, 0.0))
	if right_hand != null and weapon_hand_anchor != null:
		weapon_hand_anchor.global_position = right_hand.global_position


func pose_node(
	node: Node3D,
	rotation_offset: Vector3,
	position_offset: Vector3,
	delta: float,
	response: float
) -> void:
	if node == null:
		return

	var target_rotation: Vector3 = get_base_rotation(node) + rotation_offset
	var target_position: Vector3 = get_base_position(node) + position_offset
	var weight: float = clampf(delta * response, 0.0, 1.0)
	node.rotation = Vector3(
		lerp_angle(node.rotation.x, target_rotation.x, weight),
		lerp_angle(node.rotation.y, target_rotation.y, weight),
		lerp_angle(node.rotation.z, target_rotation.z, weight)
	)
	node.position = node.position.lerp(target_position, weight)


func remember_base_pose(node: Node3D) -> void:
	if node == null:
		return
	base_positions[node.name] = node.position
	base_rotations[node.name] = node.rotation
	base_scales[node.name] = node.scale


func get_pose_nodes() -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	for node: Node3D in [
		visual_root,
		body_root,
		head_root,
		left_shoulder,
		right_shoulder,
		left_leg,
		right_leg,
		sash_tail,
		left_hair_lock,
		right_hair_lock,
	]:
		if node != null:
			nodes.append(node)
	return nodes


func get_base_position(node: Node3D) -> Vector3:
	if node == null:
		return Vector3.ZERO
	return base_positions.get(node.name, node.position)


func get_base_rotation(node: Node3D) -> Vector3:
	if node == null:
		return Vector3.ZERO
	return base_rotations.get(node.name, node.rotation)


func get_base_scale(node: Node3D) -> Vector3:
	if node == null:
		return Vector3.ONE
	return base_scales.get(node.name, node.scale)


func get_animation_debug_data() -> Dictionary:
	return {
		"presentation_state": presentation_state,
		"movement_weight": snappedf(movement_weight, 0.01),
		"stride_phase": snappedf(fposmod(stride_phase, TAU), 0.01),
		"articulated_pivots": get_pose_nodes().size(),
		"weapon_hand_synced": weapon_hand_anchor != null,
	}


func get_debug_data() -> Dictionary:
	return get_animation_debug_data()
