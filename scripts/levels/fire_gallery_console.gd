extends Area3D
class_name FireGalleryConsole

@export var action_id: String = "trigger"
@export var prompt_text: String = "Trigger Fire"


func interact() -> Dictionary:
	var wing: Node = get_tree().get_first_node_in_group("fire_gallery_wing")
	if wing == null or not wing.has_method("handle_fire_action"):
		return {
			"message": "The Fire exhibit is offline.",
			"objective": "",
		}
	return wing.call("handle_fire_action", action_id)
