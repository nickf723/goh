extends Node3D
class_name StatusVisualController

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")

var status_receiver: Node
var status_signature: String = ""
var elapsed: float = 0.0
var target_height: float = 1.0


func bind(receiver: Node) -> void:
	status_receiver = receiver
	target_height = ElementVisuals.estimate_target_height(get_parent())
	rebuild_visuals()


func _ready() -> void:
	if status_receiver == null:
		status_receiver = get_parent().get_node_or_null("StatusReceiver")

	target_height = ElementVisuals.estimate_target_height(get_parent())
	rebuild_visuals()


func _process(delta: float) -> void:
	elapsed += delta
	var next_signature: String = get_status_signature()

	if next_signature != status_signature:
		rebuild_visuals()

	rotation.y = elapsed * 0.72
	position.y = sin(elapsed * 2.4) * 0.025

	for child: Node in get_children():
		if not (child is Node3D):
			continue

		var child_3d := child as Node3D
		var pulse_offset: float = float(child_3d.get_index()) * 0.7
		var pulse: float = 1.0 + sin(elapsed * 4.2 + pulse_offset) * 0.055
		child_3d.scale = Vector3.ONE * pulse


func rebuild_visuals() -> void:
	ElementVisuals.clear_children(self)
	var statuses: Array[String] = get_sorted_statuses()

	for index: int in range(statuses.size()):
		ElementVisuals.build_status_marker(self, statuses[index], target_height, index)

	status_signature = ",".join(statuses)


func get_sorted_statuses() -> Array[String]:
	var statuses: Array[String] = []

	if status_receiver == null:
		return statuses

	var active_statuses_value: Variant = status_receiver.get("active_statuses")

	if not (active_statuses_value is Dictionary):
		return statuses

	var active_statuses: Dictionary = active_statuses_value as Dictionary

	for status_name_value: Variant in active_statuses.keys():
		var status_name: String = str(status_name_value)
		if is_visual_status(status_name):
			statuses.append(status_name)

	statuses.sort()
	return statuses


func get_status_signature() -> String:
	return ",".join(get_sorted_statuses())


func is_visual_status(status_name: String) -> bool:
	return status_name in [
		"wet",
		"oily",
		"burning",
		"frozen",
		"stunned",
		"steamed",
		"revealed",
	]


func get_debug_data() -> Dictionary:
	return {
		"status_visuals": status_signature if status_signature != "" else "none",
		"height": snapped(target_height, 0.1),
	}
