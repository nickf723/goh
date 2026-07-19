extends Area3D
class_name VfxGalleryConsole

@export var prompt_text: String = "Trigger exhibit"
@export var action_id: String = ""

var gallery: Node


func _ready() -> void:
	add_to_group("debuggable")


func configure(next_gallery: Node, next_action_id: String, next_prompt_text: String) -> void:
	gallery = next_gallery
	action_id = next_action_id
	prompt_text = next_prompt_text


func interact() -> Dictionary:
	if gallery == null or not is_instance_valid(gallery) or not gallery.has_method("handle_gallery_action"):
		return {
			"message": "The exhibit console is offline.",
			"objective": "",
		}
	var result: Variant = gallery.call("handle_gallery_action", action_id)
	if result is Dictionary:
		return result as Dictionary
	return {
		"message": str(result),
		"objective": "",
	}


func get_debug_data() -> Dictionary:
	return {
		"vfx_gallery_console": true,
		"action_id": action_id,
		"prompt_text": prompt_text,
		"gallery_connected": gallery != null and is_instance_valid(gallery),
	}
