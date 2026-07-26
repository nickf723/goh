extends "res://scripts/expedition/regional_expedition_map.gd"


func _ready() -> void:
	super._ready()
	call_deferred("focus_launch_action")


func select_node(node_id: String) -> void:
	super.select_node(node_id)
	call_deferred("focus_launch_action")


func focus_launch_action() -> void:
	if launch_button != null and is_instance_valid(launch_button) and not launch_button.disabled:
		launch_button.grab_focus()
