extends Node
class_name PerceptionMovementEmitter

@export_range(0.1, 10.0, 0.1) var minimum_speed: float = 1.1
@export_range(0.05, 2.0, 0.01) var minimum_step_interval: float = 0.22
@export_range(0.05, 2.0, 0.01) var maximum_step_interval: float = 0.48
@export_range(0.5, 20.0, 0.25) var base_loudness: float = 5.5
@export_range(0.0, 3.0, 0.05) var speed_loudness_scale: float = 0.5
@export var emit_only_on_floor: bool = true
@export var category: String = "footstep"
@export var display_name: String = "Footsteps"
@export var enabled: bool = true

var actor: CharacterBody3D = null
var manager: PerceptionStimulusManager = null
var step_timer: float = 0.0
var emitted_steps: int = 0


func _ready() -> void:
	actor = get_parent() as CharacterBody3D
	manager = get_tree().get_first_node_in_group("perception_stimulus_manager") as PerceptionStimulusManager
	add_to_group("perception_emitters")
	add_to_group("debuggable")
	add_to_group("lab_resettable")


func _physics_process(delta: float) -> void:
	if not enabled or actor == null:
		return
	step_timer -= max(delta, 0.0)
	if step_timer > 0.0:
		return
	if emit_only_on_floor and not actor.is_on_floor():
		return
	var horizontal_velocity := Vector3(actor.velocity.x, 0.0, actor.velocity.z)
	var speed: float = horizontal_velocity.length()
	if speed < minimum_speed:
		return
	resolve_manager()
	if manager == null:
		return
	var speed_ratio: float = clampf((speed - minimum_speed) / 8.0, 0.0, 1.0)
	var interval: float = lerpf(maximum_step_interval, minimum_step_interval, speed_ratio)
	var loudness: float = base_loudness + speed * speed_loudness_scale
	manager.emit_stimulus(
		actor.global_position,
		loudness,
		category,
		max(interval * 1.5, 0.35),
		actor,
		display_name,
		1.0,
		["movement", "actor"]
	)
	step_timer = interval
	emitted_steps += 1


func resolve_manager() -> void:
	if manager == null or not is_instance_valid(manager):
		manager = get_tree().get_first_node_in_group("perception_stimulus_manager") as PerceptionStimulusManager


func reset_target() -> void:
	step_timer = 0.0
	emitted_steps = 0


func get_debug_data() -> Dictionary:
	return {
		"perception_movement_emitter": true,
		"actor": actor.name if actor != null else "none",
		"steps": emitted_steps,
		"timer": snapped(step_timer, 0.01),
	}
