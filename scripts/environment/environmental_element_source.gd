extends Node3D
class_name EnvironmentalElementSource

@export var source_label: String = "Environmental Source"
@export var resettable: bool = true

var initial_transform: Transform3D


func _ready() -> void:
	initial_transform = transform
	add_to_group("debuggable")
	if resettable:
		add_to_group("lab_resettable")


func get_emitter() -> ElementEmitter:
	return get_node_or_null("ElementEmitter") as ElementEmitter


func set_source_active(is_active: bool) -> void:
	var emitter: ElementEmitter = get_emitter()
	if emitter != null:
		emitter.set_emitting(is_active)
	update_source_visual(is_active)


func request_element_units(requested_units: float) -> float:
	var emitter: ElementEmitter = get_emitter()
	if emitter == null:
		return 0.0
	return emitter.request_element_units(requested_units)


func reset_source() -> void:
	transform = initial_transform
	var emitter: ElementEmitter = get_emitter()
	if emitter != null:
		emitter.reset_emitter()
	update_source_visual(emitter.active if emitter != null else true)


func reset_target() -> void:
	reset_source()


func update_source_visual(is_active: bool) -> void:
	var visual_root: Node3D = get_node_or_null("VisualRoot") as Node3D
	if visual_root != null:
		visual_root.visible = is_active


func interact() -> Dictionary:
	var emitter: ElementEmitter = get_emitter()
	var state_text: String = "inactive"
	if emitter != null and emitter.active:
		state_text = emitter.element + " source active"
	return {
		"message": source_label + " | " + state_text,
		"objective": "Use environmental sources to create reactions without casting both ingredients.",
	}


func get_debug_data() -> Dictionary:
	var emitter: ElementEmitter = get_emitter()
	return {
		"environment_source": source_label,
		"emitter": emitter.get_debug_data() if emitter != null else {},
	}
