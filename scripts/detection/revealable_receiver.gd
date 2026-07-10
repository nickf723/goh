extends Node
class_name RevealableReceiver

@export var starts_hidden: bool = true
@export var reveal_duration_override: float = 0.0
@export var required_detection_tags: Array[String] = ["sound"]

@export var hide_visuals_when_hidden: bool = true
@export var disable_collision_when_hidden: bool = false
@export var reveal_message: String = "Something hidden is revealed."

var is_revealed: bool = false
var reveal_timer: float = 0.0
var last_detection_summary: String = "none"


func _ready() -> void:
	add_to_group("debuggable")
	add_to_group("detectable")

	if starts_hidden:
		hide_target()
	else:
		reveal_target(0.0, "initial")

func _process(delta: float) -> void:
	if not is_revealed:
		return

	if reveal_timer <= 0.0:
		return

	reveal_timer -= delta

	if reveal_timer <= 0.0:
		hide_target()

func receive_detection(payload: DetectionPayload) -> Dictionary:
	if payload == null:
		return {
			"message": get_target_node().name + " receives empty detection.",
			"revealed": false,
		}

	if not matches_detection(payload):
		return {
			"message": "",
			"revealed": false,
		}

	var duration: float = payload.reveal_duration

	if reveal_duration_override > 0.0:
		duration = reveal_duration_override

	last_detection_summary = (
		payload.source_name
		+ " | "
		+ payload.detection_type
		+ " | "
		+ str(payload.tags)
	)

	reveal_target(duration, payload.source_name)

	return {
		"message": reveal_message,
		"revealed": true,
	}

func matches_detection(payload: DetectionPayload) -> bool:
	if required_detection_tags.size() == 0:
		return true

	for tag: String in required_detection_tags:
		if payload.tags.has(tag):
			return true

	return false

func reveal_target(duration: float, source_name: String = "unknown") -> void:
	is_revealed = true
	reveal_timer = duration

	var target: Node = get_target_node()

	if hide_visuals_when_hidden:
		set_visuals_visible(target, true)

	if disable_collision_when_hidden:
		set_collision_enabled(target, true)

	print(target.name, " revealed by ", source_name)

func hide_target() -> void:
	is_revealed = false

	var target: Node = get_target_node()

	if hide_visuals_when_hidden:
		set_visuals_visible(target, false)

	if disable_collision_when_hidden:
		set_collision_enabled(target, false)

	print(target.name, " hidden again.")

func get_target_node() -> Node:
	var parent: Node = get_parent()

	if parent != null:
		return parent

	return self

func set_visuals_visible(node: Node, visible_value: bool) -> void:
	if node is MeshInstance3D:
		node.visible = visible_value

	for child: Node in node.get_children():
		set_visuals_visible(child, visible_value)

func set_collision_enabled(node: Node, enabled: bool) -> void:
	if node is CollisionShape3D:
		node.disabled = not enabled

	for child: Node in node.get_children():
		set_collision_enabled(child, enabled)

func get_debug_data() -> Dictionary:
	return {
		"revealed": is_revealed,
		"time": snapped(reveal_timer, 0.1),
		"needs": required_detection_tags,
		"last": last_detection_summary,
	}
