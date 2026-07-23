extends RefCounted
class_name PerceptionStimulus

var stimulus_id: int = 0
var world_position: Vector3 = Vector3.ZERO
var loudness: float = 1.0
var category: String = "sound"
var display_name: String = "Sound"
var duration: float = 1.0
var remaining_lifetime: float = 1.0
var priority: float = 1.0
var tags: Array[String] = []
var source_reference: WeakRef = null
var source_name: String = "world"


func configure(
	new_id: int,
	position_value: Vector3,
	loudness_value: float,
	category_value: String,
	duration_value: float,
	source: Node = null,
	display_name_value: String = "",
	priority_value: float = 1.0,
	tags_value: Array[String] = []
) -> PerceptionStimulus:
	stimulus_id = new_id
	world_position = position_value
	loudness = max(loudness_value, 0.0)
	category = category_value.to_lower().strip_edges()
	if category == "":
		category = "sound"
	display_name = display_name_value.strip_edges()
	if display_name == "":
		display_name = category.capitalize()
	duration = max(duration_value, 0.02)
	remaining_lifetime = duration
	priority = max(priority_value, 0.0)
	tags = tags_value.duplicate()
	if source != null:
		source_reference = weakref(source)
		source_name = source.name
	return self


func advance(delta: float) -> void:
	remaining_lifetime = max(remaining_lifetime - max(delta, 0.0), 0.0)


func is_expired() -> bool:
	return remaining_lifetime <= 0.0


func get_source() -> Node:
	if source_reference == null:
		return null
	var source_value: Variant = source_reference.get_ref()
	return source_value as Node if source_value is Node else null


func get_age_ratio() -> float:
	return 1.0 - clampf(remaining_lifetime / max(duration, 0.02), 0.0, 1.0)


func get_debug_data() -> Dictionary:
	return {
		"id": stimulus_id,
		"category": category,
		"name": display_name,
		"position": world_position,
		"loudness": snapped(loudness, 0.01),
		"remaining": snapped(remaining_lifetime, 0.01),
		"priority": snapped(priority, 0.01),
		"source": source_name,
		"tags": tags.duplicate(),
	}
