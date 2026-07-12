extends StaticBody3D

signal target_activated(target: Node)

@export var display_name: String = "Element Lock Target"
@export var required_element: String = "fire"
@export var activation_message: String = "The lock target activates."
@export var wrong_element_message: String = "This target wants a different element."
@export var already_active_message: String = "This target is already active."
@export var activated_marker_path: NodePath = NodePath("ActivatedMarker")

var is_activated: bool = false


func _ready() -> void:
	add_to_group("element_lock_target")
	set_activated_marker_visible(false)


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if is_activated:
		return make_result(already_active_message)

	if payload == null:
		return make_result(display_name + " waits for " + required_element.capitalize() + ".")

	if required_element != "" and payload.element != required_element:
		var message: String = wrong_element_message

		if message == "":
			message = display_name + " wants " + required_element.capitalize() + ", not " + payload.element.capitalize() + "."

		return make_result(message)

	activate()
	return make_result(activation_message)


func activate() -> void:
	if is_activated:
		return

	is_activated = true
	set_activated_marker_visible(true)
	target_activated.emit(self)
	show_message(activation_message)


func set_activated_marker_visible(value: bool) -> void:
	var marker: Node = get_node_or_null(activated_marker_path)

	if marker is Node3D:
		(marker as Node3D).visible = value
	elif marker is CanvasItem:
		(marker as CanvasItem).visible = value


func make_result(message: String) -> Dictionary:
	return {
		"message": message,
		"objective": "Solve the element lock.",
	}


func is_active() -> bool:
	return is_activated


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)


func get_debug_data() -> Dictionary:
	return {
		"target": display_name,
		"required": required_element,
		"active": is_activated,
	}
