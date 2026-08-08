extends "res://scripts/ui/game_ui_compact_focus.gd"
class_name GameUICompactFocusResolved


func show_spell_focus_menu(menu_data: Dictionary) -> void:
	super.show_spell_focus_menu(menu_data)
	for label: Label in icon_spell_equipped_labels:
		if label != null:
			label.text = "★"
