extends Node
class_name PerceptionStimulusManager

signal stimulus_emitted(stimulus: PerceptionStimulus)
signal stimulus_expired(stimulus_id: int)

@export_range(1, 256, 1) var maximum_active_stimuli: int = 64
@export var retain_debug_history: bool = true
@export_range(1, 64, 1) var maximum_debug_history: int = 12

var active_stimuli: Array[PerceptionStimulus] = []
var debug_history: Array[Dictionary] = []
var next_stimulus_id: int = 1
var total_emitted: int = 0


func _ready() -> void:
	add_to_group("perception_stimulus_manager")
	add_to_group("debuggable")


func _process(delta: float) -> void:
	for index: int in range(active_stimuli.size() - 1, -1, -1):
		var stimulus: PerceptionStimulus = active_stimuli[index]
		if stimulus == null:
			active_stimuli.remove_at(index)
			continue
		stimulus.advance(delta)
		if stimulus.is_expired():
			var expired_id: int = stimulus.stimulus_id
			active_stimuli.remove_at(index)
			stimulus_expired.emit(expired_id)


func emit_stimulus(
	world_position: Vector3,
	loudness: float,
	category: String = "sound",
	duration: float = 1.0,
	source: Node = null,
	display_name: String = "",
	priority: float = 1.0,
	tags: Array[String] = []
) -> PerceptionStimulus:
	var stimulus := PerceptionStimulus.new().configure(
		next_stimulus_id,
		world_position,
		loudness,
		category,
		duration,
		source,
		display_name,
		priority,
		tags
	)
	next_stimulus_id += 1
	total_emitted += 1
	active_stimuli.append(stimulus)
	trim_active_stimuli()
	store_debug_history(stimulus)
	stimulus_emitted.emit(stimulus)
	return stimulus


func emit_from_node(
	source: Node3D,
	loudness: float,
	category: String = "sound",
	duration: float = 1.0,
	display_name: String = "",
	priority: float = 1.0,
	tags: Array[String] = []
) -> PerceptionStimulus:
	if source == null:
		return emit_stimulus(Vector3.ZERO, loudness, category, duration, null, display_name, priority, tags)
	return emit_stimulus(source.global_position, loudness, category, duration, source, display_name, priority, tags)


func trim_active_stimuli() -> void:
	var maximum_count: int = max(maximum_active_stimuli, 1)
	while active_stimuli.size() > maximum_count:
		active_stimuli.pop_front()


func store_debug_history(stimulus: PerceptionStimulus) -> void:
	if not retain_debug_history or stimulus == null:
		return
	debug_history.push_front(stimulus.get_debug_data())
	while debug_history.size() > maximum_debug_history:
		debug_history.pop_back()


func get_active_stimuli() -> Array[PerceptionStimulus]:
	return active_stimuli.duplicate()


func get_stimuli_near(world_position: Vector3, maximum_radius: float) -> Array[PerceptionStimulus]:
	var results: Array[PerceptionStimulus] = []
	var radius_squared: float = pow(max(maximum_radius, 0.0), 2.0)
	for stimulus: PerceptionStimulus in active_stimuli:
		if stimulus == null:
			continue
		if stimulus.world_position.distance_squared_to(world_position) <= radius_squared:
			results.append(stimulus)
	return results


func clear_stimuli() -> void:
	active_stimuli.clear()


func get_debug_data() -> Dictionary:
	return {
		"perception_stimulus_manager": true,
		"active": active_stimuli.size(),
		"total_emitted": total_emitted,
		"next_id": next_stimulus_id,
		"history": debug_history.duplicate(true),
	}
