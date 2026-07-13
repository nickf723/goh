extends Node3D
class_name StylizedActorVisual

@export var idle_bob_height: float = 0.018
@export var idle_bob_speed: float = 2.1
@export var movement_bob_height: float = 0.035
@export var movement_bob_speed: float = 7.5
@export var maximum_lean_radians: float = 0.08
@export var lean_response: float = 8.0

@onready var visual_root: Node3D = get_node_or_null("VisualRoot") as Node3D

var elapsed: float = 0.0
var base_visual_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	if visual_root != null:
		base_visual_position = visual_root.position


func _process(delta: float) -> void:
	if visual_root == null:
		return

	elapsed += delta

	var body: CharacterBody3D = get_parent() as CharacterBody3D
	var horizontal_velocity: Vector3 = Vector3.ZERO

	if body != null:
		horizontal_velocity = Vector3(body.velocity.x, 0.0, body.velocity.z)

	var speed: float = horizontal_velocity.length()
	var moving_weight: float = clampf(speed / 2.0, 0.0, 1.0)
	var bob_speed: float = lerpf(idle_bob_speed, movement_bob_speed, moving_weight)
	var bob_height: float = lerpf(idle_bob_height, movement_bob_height, moving_weight)
	var bob_offset: float = sin(elapsed * bob_speed) * bob_height

	visual_root.position = base_visual_position + Vector3(0.0, bob_offset, 0.0)

	var target_lean: float = clampf(-horizontal_velocity.x * 0.018, -maximum_lean_radians, maximum_lean_radians)
	visual_root.rotation.z = lerp_angle(visual_root.rotation.z, target_lean, clampf(delta * lean_response, 0.0, 1.0))
