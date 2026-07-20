extends Area3D
class_name ElementVfxLabConsole

@export var lab_group: String = "single_element_vfx_lab"
@export var action_id: String = "trigger"
@export var prompt_text: String = "Trigger Effect"


func interact() -> Dictionary:
	var lab: Node = get_tree().get_first_node_in_group(lab_group)
	if lab == null or not lab.has_method("handle_vfx_lab_action"):
		return {
			"message": "The elemental laboratory console is offline.",
			"objective": "",
		}
	var result: Variant = lab.call("handle_vfx_lab_action", action_id)
	if result is Dictionary:
		return result as Dictionary
	return {
		"message": prompt_text,
		"objective": "",
	}
