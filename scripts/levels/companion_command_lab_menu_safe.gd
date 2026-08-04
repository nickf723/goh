extends "res://scripts/levels/companion_command_lab.gd"
class_name CompanionCommandLabMenuSafe


func _ready() -> void:
	super._ready()
	_register_lab_overlay_panels()
	call_deferred("_register_lab_overlay_panels")


func _register_lab_overlay_panels() -> void:
	for layer_candidate: Node in get_children():
		if not layer_candidate is CanvasLayer:
			continue
		var layer := layer_candidate as CanvasLayer
		for panel_candidate: Node in layer.get_children():
			if not panel_candidate is PanelContainer:
				continue
			var panel := panel_candidate as PanelContainer
			panel.add_to_group("menu_suppressed_hud")
			panel.set_meta("full_menu_suppressed_lab_overlay", true)


func get_menu_suppressed_overlay_count() -> int:
	var count: int = 0
	for layer_candidate: Node in get_children():
		if not layer_candidate is CanvasLayer:
			continue
		for panel_candidate: Node in layer_candidate.get_children():
			if (
				panel_candidate is PanelContainer
				and bool(panel_candidate.get_meta(
					"full_menu_suppressed_lab_overlay",
					false
				))
				and panel_candidate.is_in_group("menu_suppressed_hud")
			):
				count += 1
	return count
