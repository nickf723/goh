extends Area3D
class_name LightningGalleryConsole

@export var action_id: String = "trigger"
@export var prompt_text: String = "Trigger Lightning"


func interact() -> Dictionary:
	var wing: Node = get_tree().get_first_node_in_group("lightning_gallery_wing")
	if wing == null or not wing.has_method("handle_lightning_action"):
		return {
			"message": "The Lightning exhibit is offline.",
			"objective": "",
		}
	return wing.call("handle_lightning_action", action_id)
