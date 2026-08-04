extends "res://scripts/levels/companion_command_lab.gd"
class_name CompanionCommandLabMenuSafe


func _ready() -> void:
	super._ready()
	_register_lab_overlay_panels()


func _register_lab_overlay_panels() -> void:
	for candidate: Node in find_children("*", "PanelContainer", true, false):
		if not candidate is PanelContainer:
			continue
		var panel := candidate as PanelContainer
		if not panel.get_parent() is CanvasLayer:
			continue
		panel.add_to_group("menu_suppressed_hud")
		panel.set_meta("full_menu_suppressed_lab_overlay", true)


func get_menu_suppressed_overlay_count() -> int:
	var count: int = 0
	for candidate: Node in find_children("*", "PanelContainer", true, false):
		if (
			candidate is PanelContainer
			and candidate.get_parent() is CanvasLayer
			and candidate.is_in_group("menu_suppressed_hud")
		):
			count += 1
	return count
