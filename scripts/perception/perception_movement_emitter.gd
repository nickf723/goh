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
var emitted_landings: int = 0
var was_on_floor: bool = false
var previous_vertical_velocity: float = 0.0
var last_surface: String = "stone"


func _ready() -> void:
	actor = get_parent() as CharacterBody3D
	manager = get_tree().get_first_node_in_group("perception_stimulus_manager") as PerceptionStimulusManager
	add_to_group("perception_emitters")
	add_to_group("debuggable")
	add_to_group("lab_resettable")
	was_on_floor = actor.is_on_floor() if actor != null else false


func _physics_process(delta: float) -> void:
	if not enabled or actor == null:
		return
	var on_floor: bool = actor.is_on_floor()
	if on_floor and not was_on_floor and previous_vertical_velocity < -2.4:
		emit_landing(absf(previous_vertical_velocity))
	was_on_floor = on_floor
	previous_vertical_velocity = actor.velocity.y
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
	var surface: Dictionary = sample_surface()
	last_surface = str(surface.get("id", "stone"))
	var loudness: float = (base_loudness + speed * speed_loudness_scale) * float(surface.get("noise", 1.0))
	loudness *= get_stealth_noise_multiplier()
	var tags: Array[String] = ["movement", "actor", "acoustic", "surface:" + last_surface, "frequency:mid"]
	manager.emit_stimulus(
		actor.global_position,
		loudness,
		category,
		max(interval * 1.5, 0.35),
		actor,
		display_name + " on " + last_surface.capitalize(),
		1.0,
		tags
	)
	report_to_stealth(category, loudness)
	step_timer = interval
	emitted_steps += 1


func emit_landing(impact_speed: float) -> void:
	resolve_manager()
	if manager == null:
		return
	var surface: Dictionary = sample_surface()
	last_surface = str(surface.get("id", "stone"))
	var loudness: float = clampf(impact_speed * 1.35, 3.0, 15.0) * float(surface.get("noise", 1.0))
	loudness *= get_stealth_noise_multiplier()
	var tags: Array[String] = ["movement", "landing", "acoustic", "surface:" + last_surface, "frequency:low"]
	manager.emit_stimulus(actor.global_position, loudness, "landing", 0.8, actor, "Landing", 1.2, tags)
	report_to_stealth("landing", loudness)
	emitted_landings += 1


func sample_surface() -> Dictionary:
	if actor == null or actor.get_world_3d() == null:
		return {"id": "stone", "noise": 1.0}
	var query := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * 0.2, actor.global_position + Vector3.DOWN * 1.4, 1)
	query.exclude = [actor.get_rid()]
	var result: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(query)
	var collider: Object = result.get("collider") as Object
	if collider != null and collider.has_meta("acoustic_surface"):
		var surface_id: String = str(collider.get_meta("acoustic_surface"))
		var multipliers: Dictionary = {"grass": 0.5, "dirt": 0.72, "wood": 1.05, "stone": 1.25, "metal": 1.65, "water": 1.45}
		return {"id": surface_id, "noise": float(multipliers.get(surface_id, 1.0))}
	return {"id": "stone", "noise": 1.0}


func get_stealth_noise_multiplier() -> float:
	var stealth: Node = actor.get_node_or_null("StealthController") if actor != null else null
	if stealth != null and stealth.has_method("get_noise_multiplier"):
		return float(stealth.call("get_noise_multiplier"))
	return 1.0


func report_to_stealth(event_category: String, loudness: float) -> void:
	var stealth: Node = actor.get_node_or_null("StealthController") if actor != null else null
	if stealth != null and stealth.has_method("report_acoustic_event"):
		stealth.call("report_acoustic_event", event_category, loudness)


func resolve_manager() -> void:
	if manager == null or not is_instance_valid(manager):
		manager = get_tree().get_first_node_in_group("perception_stimulus_manager") as PerceptionStimulusManager


func reset_target() -> void:
	step_timer = 0.0
	emitted_steps = 0
	emitted_landings = 0


func get_debug_data() -> Dictionary:
	return {
		"perception_movement_emitter": true,
		"actor": actor.name if actor != null else "none",
		"steps": emitted_steps,
		"landings": emitted_landings,
		"surface": last_surface,
		"timer": snapped(step_timer, 0.01),
	}
