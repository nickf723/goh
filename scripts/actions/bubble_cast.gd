extends Node3D
class_name BubbleCast

var source_actor: Node3D
var runtime_payload: DamagePayload


func set_source_actor(new_source_actor: Node) -> void:
	if new_source_actor is Node3D:
		source_actor = new_source_actor as Node3D


func set_payload(new_payload: Resource) -> void:
	if new_payload is DamagePayload:
		var duplicate_value: Resource = (new_payload as DamagePayload).duplicate(true)
		runtime_payload = (
			duplicate_value as DamagePayload
			if duplicate_value is DamagePayload
			else new_payload as DamagePayload
		)
		runtime_payload.suppress_reactions = true


func execute(player: Node3D, _cast_direction: Vector3) -> void:
	if source_actor == null:
		source_actor = player
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return

	var controller: Node = source_actor.get_node_or_null(
		"BubbleShieldController"
	)
	if controller != null and controller.has_method("activate_bubble"):
		controller.call("activate_bubble", runtime_payload)
	queue_free()
