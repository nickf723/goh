extends "res://scripts/player/player_spell_aim_pointer.gd"
class_name PlayerSpellAimPointerSafe

# CanvasLayer does not participate in CanvasItem visibility. Keep the reusable
# pointer's presentation switch on the full-screen Control root instead.


func _set_ui_visible(value: bool) -> void:
	if ui_root != null:
		ui_root.visible = value
