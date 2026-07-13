extends Node3D
class_name EnemyVisualShell

@export_enum("goblin", "gremlin") var profile: String = "goblin"
@export var idle_bob_amount: float = 0.025
@export var movement_bob_amount: float = 0.055
@export var movement_bob_speed: float = 10.0
@export var idle_bob_speed: float = 3.2
@export var movement_lean_degrees: float = 5.0
@export var head_twitch_degrees: float = 2.0
@export var windup_pose_time: float = 0.12
@export var recover_pose_time: float = 0.18

var actor: CharacterBody3D
var elapsed: float = 0.0
var pose_tween: Tween
var presentation_locked: bool = false

var pose_root: Node3D
var body_pivot: Node3D
var head_pivot: Node3D
var left_arm_pivot: Node3D
var right_arm_pivot: Node3D
var left_leg_pivot: Node3D
var right_leg_pivot: Node3D
var weapon_pivot: Node3D
var jaw_pivot: Node3D

var base_positions: Dictionary = {}
var base_rotations: Dictionary = {}


func _ready() -> void:
	actor = get_parent() as CharacterBody3D
	pose_root = get_node_or_null("PoseRoot") as Node3D
	body_pivot = get_node_or_null("PoseRoot/BodyPivot") as Node3D
	head_pivot = get_node_or_null("PoseRoot/HeadPivot") as Node3D
	left_arm_pivot = get_node_or_null("PoseRoot/LeftArmPivot") as Node3D
	right_arm_pivot = get_node_or_null("PoseRoot/RightArmPivot") as Node3D
	left_leg_pivot = get_node_or_null("PoseRoot/LeftLegPivot") as Node3D
	right_leg_pivot = get_node_or_null("PoseRoot/RightLegPivot") as Node3D
	weapon_pivot = get_node_or_null("PoseRoot/RightArmPivot/WeaponPivot") as Node3D
	jaw_pivot = get_node_or_null("PoseRoot/HeadPivot/JawPivot") as Node3D
	cache_base_pose()


func _process(delta: float) -> void:
	if pose_root == null or presentation_locked:
		return

	elapsed += delta
	var speed: float = 0.0

	if actor != null:
		var horizontal_velocity := Vector2(actor.velocity.x, actor.velocity.z)
		speed = horizontal_velocity.length()

	var movement_weight: float = clamp(speed / 3.0, 0.0, 1.0)
	var bob_speed: float = lerp(idle_bob_speed, movement_bob_speed, movement_weight)
	var bob_amount: float = idle_bob_amount + movement_bob_amount * movement_weight
	var base_pose_position: Vector3 = get_base_position(pose_root)
	var base_pose_rotation: Vector3 = get_base_rotation(pose_root)

	pose_root.position = base_pose_position + Vector3(0.0, sin(elapsed * bob_speed) * bob_amount, 0.0)
	pose_root.rotation = base_pose_rotation
	pose_root.rotation.z += deg_to_rad(sin(elapsed * bob_speed * 0.5) * movement_lean_degrees * movement_weight)

	if head_pivot != null:
		head_pivot.position = get_base_position(head_pivot)
		head_pivot.rotation = get_base_rotation(head_pivot)
		var twitch_speed: float = 5.5 if profile == "gremlin" else 2.4
		head_pivot.rotation.y += deg_to_rad(sin(elapsed * twitch_speed) * head_twitch_degrees)


func start_windup() -> void:
	kill_pose_tween()
	presentation_locked = true
	restore_base_pose()
	pose_tween = create_tween()
	pose_tween.set_parallel(true)

	if profile == "gremlin":
		tween_rotation(body_pivot, Vector3(-24.0, 0.0, 0.0), windup_pose_time)
		tween_position(body_pivot, Vector3(0.0, -0.12, -0.08), windup_pose_time)
		tween_rotation(head_pivot, Vector3(-18.0, 0.0, 0.0), windup_pose_time)
		tween_rotation(left_arm_pivot, Vector3(-38.0, 0.0, -42.0), windup_pose_time)
		tween_rotation(right_arm_pivot, Vector3(-38.0, 0.0, 42.0), windup_pose_time)
		tween_rotation(left_leg_pivot, Vector3(24.0, 0.0, -10.0), windup_pose_time)
		tween_rotation(right_leg_pivot, Vector3(24.0, 0.0, 10.0), windup_pose_time)
		tween_rotation(jaw_pivot, Vector3(26.0, 0.0, 0.0), windup_pose_time)
	else:
		tween_rotation(body_pivot, Vector3(-12.0, 0.0, 0.0), windup_pose_time)
		tween_position(body_pivot, Vector3(0.0, -0.05, 0.04), windup_pose_time)
		tween_rotation(head_pivot, Vector3(8.0, 0.0, 0.0), windup_pose_time)
		tween_rotation(left_arm_pivot, Vector3(-18.0, 0.0, -24.0), windup_pose_time)
		tween_rotation(right_arm_pivot, Vector3(-70.0, 0.0, 34.0), windup_pose_time)
		tween_rotation(weapon_pivot, Vector3(-34.0, 0.0, -18.0), windup_pose_time)


func start_recover() -> void:
	kill_pose_tween()
	presentation_locked = true
	pose_tween = create_tween()
	pose_tween.set_parallel(true)

	for node: Node3D in get_pose_nodes():
		if node == null:
			continue
		pose_tween.tween_property(node, "position", get_base_position(node), recover_pose_time)
		pose_tween.tween_property(node, "rotation", get_base_rotation(node), recover_pose_time)

	pose_tween.finished.connect(_on_recover_finished)


func reset_presentation() -> void:
	kill_pose_tween()
	presentation_locked = false
	restore_base_pose()


func cache_base_pose() -> void:
	base_positions.clear()
	base_rotations.clear()

	for node: Node3D in get_pose_nodes():
		if node == null:
			continue
		base_positions[node.get_instance_id()] = node.position
		base_rotations[node.get_instance_id()] = node.rotation


func restore_base_pose() -> void:
	for node: Node3D in get_pose_nodes():
		if node == null:
			continue
		node.position = get_base_position(node)
		node.rotation = get_base_rotation(node)


func get_pose_nodes() -> Array[Node3D]:
	return [
		pose_root,
		body_pivot,
		head_pivot,
		left_arm_pivot,
		right_arm_pivot,
		left_leg_pivot,
		right_leg_pivot,
		weapon_pivot,
		jaw_pivot,
	]


func get_base_position(node: Node3D) -> Vector3:
	if node == null:
		return Vector3.ZERO
	return base_positions.get(node.get_instance_id(), node.position) as Vector3


func get_base_rotation(node: Node3D) -> Vector3:
	if node == null:
		return Vector3.ZERO
	return base_rotations.get(node.get_instance_id(), node.rotation) as Vector3


func tween_position(node: Node3D, offset: Vector3, duration: float) -> void:
	if node == null or pose_tween == null:
		return
	pose_tween.tween_property(node, "position", get_base_position(node) + offset, duration)


func tween_rotation(node: Node3D, offset_degrees: Vector3, duration: float) -> void:
	if node == null or pose_tween == null:
		return
	pose_tween.tween_property(node, "rotation", get_base_rotation(node) + degrees_to_radians(offset_degrees), duration)


func degrees_to_radians(value: Vector3) -> Vector3:
	return Vector3(deg_to_rad(value.x), deg_to_rad(value.y), deg_to_rad(value.z))


func kill_pose_tween() -> void:
	if pose_tween != null:
		pose_tween.kill()
		pose_tween = null


func _on_recover_finished() -> void:
	presentation_locked = false
	pose_tween = null
