extends Node

@export var max_debug_objects: int = 1
@export var detection_radius: float = 6.0
@export var max_value_length: int = 38
@export var include_player: bool = false

var is_enabled: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_dev_vision"):
		is_enabled = not is_enabled
		update_dev_vision()

func _process(_delta: float) -> void:
	if is_enabled:
		update_dev_vision()

func update_dev_vision() -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui == null:
		return

	if not is_enabled:
		if ui.has_method("hide_dev_vision"):
			ui.hide_dev_vision()
		return

	if ui.has_method("show_dev_vision"):
		ui.show_dev_vision(build_debug_text())

func build_debug_text() -> String:
	var player: Node3D = get_tree().get_first_node_in_group("player")

	if player == null:
		return "DEV VISION\nNo player found."

	var debug_components: Array[Node] = get_tree().get_nodes_in_group("debuggable")
	var grouped_objects: Dictionary = {}

	for component: Node in debug_components:
		if not component.has_method("get_debug_data"):
			continue

		var owner_node: Node = get_debug_owner(component)

		if owner_node == null:
			continue

		if not include_player and owner_node.is_in_group("player"):
			continue

		var owner_position: Vector3 = get_debug_position(owner_node)
		var distance: float = player.global_position.distance_to(owner_position)

		if distance > detection_radius:
			continue

		var owner_id: int = owner_node.get_instance_id()

		if not grouped_objects.has(owner_id):
			grouped_objects[owner_id] = {
				"owner": owner_node,
				"distance": distance,
				"components": [],
			}

		grouped_objects[owner_id]["components"].append(component)

	var entries: Array[Dictionary] = []

	for owner_id in grouped_objects.keys():
		entries.append(grouped_objects[owner_id])

	entries.sort_custom(sort_by_distance)

	var text: String = "DEV VISION"
	var count: int = 0

	for entry: Dictionary in entries:
		if count >= max_debug_objects:
			break

		var owner: Node = entry["owner"]
		var distance: float = entry["distance"]
		var components: Array = entry["components"]

		components.sort_custom(sort_components_by_priority)

		text += "\n\n" + owner.name + " [" + str(snapped(distance, 0.1)) + "m]"

		var tag_text: String = get_tags_from_components(components)

		if tag_text != "":
			text += "\n  Tags: " + tag_text

		for component: Node in components:
			if component.name == "TagComponent":
				continue

			var data: Dictionary = component.get_debug_data()
			text += "\n  " + get_component_label(component.name) + ": " + format_inline_data(data)

		count += 1

	if count == 0:
		text += "\n\nNo nearby debuggable objects."

	return text

func get_debug_owner(component: Node) -> Node:
	var parent: Node = component.get_parent()

	if parent != null:
		return parent

	return component

func get_debug_position(node: Node) -> Vector3:
	if node is Node3D:
		return node.global_position

	var parent: Node = node.get_parent()

	if parent is Node3D:
		return parent.global_position

	return Vector3.ZERO

func get_tags_from_components(components: Array) -> String:
	for component: Node in components:
		if component.name != "TagComponent":
			continue

		var data: Dictionary = component.get_debug_data()

		if data.has("tags"):
			return trim_value(data["tags"])

	return ""

func format_inline_data(data: Dictionary) -> String:
	var parts: Array[String] = []

	for key in data.keys():
		if key == "type":
			continue

		parts.append(str(key) + "=" + trim_value(data[key]))

	return "; ".join(parts)

func get_component_label(component_name: String) -> String:
	match component_name:
		"HitReceiver":
			return "Hit"
		"StatusReceiver":
			return "Status"
		"AbilityCaster":
			return "Ability"
		"TagComponent":
			return "Tags"
		"ForceReceiver":
			return "Force"
		"RevealableReceiver":
			return "Reveal"
		"PlayerActionState":
			return "Action"
		"EnemyBrain":
			return "Brain"
		"EnemyTelegraph":
			return "Telegraph"
		"PlayerDodgeController":
			return "Dodge"
	return component_name

func trim_value(value) -> String:
	var text: String = str(value)

	if text.length() > max_value_length:
		text = text.substr(0, max_value_length) + "..."

	return text

func get_component_priority(component: Node) -> int:
	match component.name:
		"TagComponent":
			return 0
		"EnemyBrain":
			return 1
		"RevealableReceiver":
			return 2
		"EnemyTelegraph":
			return 2
		"PayloadReceiver":
			return 3
		"HitReceiver":
			return 4
		"StatusReceiver":
			return 5
		"ForceReceiver":
			return 6
		"AbilityCaster":
			return 7
		"WeaponController":
			return 8
		"PlayerActionState":
			return 9
		"PlayerDodgeController":
			return 2

	return 99
	match component.name:
		"TagComponent":
			return 0
		"RevealableReceiver":
			return 1
		"PlayerActionState":
			return 1
		"PayloadReceiver":
			return 2
		"HitReceiver":
			return 3
		"StatusReceiver":
			return 4
		"ForceReceiver":
			return 5
		"AbilityCaster":
			return 6
		"WeaponController":
			return 7

	return 99

func sort_components_by_priority(a: Node, b: Node) -> bool:
	return get_component_priority(a) < get_component_priority(b)

func sort_by_distance(a: Dictionary, b: Dictionary) -> bool:
	return a["distance"] < b["distance"]
