extends Area3D
class_name LabReactionTarget

@export var prompt_text: String = "Inspect reaction target"
@export var target_label: String = "Reaction Target"

var initial_transform: Transform3D


func _ready() -> void:
	initial_transform = transform
	add_to_group("enemy")
	add_to_group("lab_resettable")
	add_to_group("debuggable")


func interact() -> Dictionary:
	return {
		"message": get_inspection_message(),
		"objective": "Test the station sequence, then use the reset console."
	}


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	var payload_receiver: Node = get_node_or_null("PayloadReceiver")

	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		return payload_receiver.receive_payload(payload)

	return {
		"message": payload.source_name + " reaches " + target_label + ", but its receiver is missing.",
		"objective": ""
	}


func reset_target() -> void:
	transform = initial_transform
	visible = true
	set_collision_enabled(self, true)

	var hit_receiver: Node = get_node_or_null("HitReceiver")
	if hit_receiver != null:
		if hit_receiver.has_method("reset_health"):
			hit_receiver.reset_health()
		if hit_receiver.has_method("reset_stance"):
			hit_receiver.reset_stance()

	var status_receiver: Node = get_node_or_null("StatusReceiver")
	if status_receiver != null and status_receiver.has_method("clear_all_statuses"):
		status_receiver.clear_all_statuses()

	var payload_receiver: Node = get_node_or_null("PayloadReceiver")
	if payload_receiver != null:
		payload_receiver.set("last_payload_summary", "none")
		payload_receiver.set("last_reaction_summary", "none")
		payload_receiver.set("last_reaction_data", {})


func get_inspection_message() -> String:
	var statuses: String = "none"
	var status_receiver: Node = get_node_or_null("StatusReceiver")

	if status_receiver != null and status_receiver.has_method("get_debug_data"):
		statuses = str(status_receiver.get_debug_data().get("statuses", "none"))

	var reaction: String = "none"
	var payload_receiver: Node = get_node_or_null("PayloadReceiver")

	if payload_receiver != null:
		reaction = str(payload_receiver.get("last_reaction_summary"))

	return target_label + " | statuses: " + statuses + " | last reaction: " + reaction


func set_collision_enabled(node: Node, enabled: bool) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = not enabled

	for child: Node in node.get_children():
		set_collision_enabled(child, enabled)


func get_debug_data() -> Dictionary:
	var statuses: String = "none"
	var status_receiver: Node = get_node_or_null("StatusReceiver")

	if status_receiver != null and status_receiver.has_method("get_debug_data"):
		statuses = str(status_receiver.get_debug_data().get("statuses", "none"))

	var reaction: String = "none"
	var payload_receiver: Node = get_node_or_null("PayloadReceiver")

	if payload_receiver != null:
		reaction = str(payload_receiver.get("last_reaction_summary"))

	return {
		"lab_target": target_label,
		"statuses": statuses,
		"reaction": reaction,
	}
