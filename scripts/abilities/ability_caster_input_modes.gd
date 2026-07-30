extends "res://scripts/abilities/ability_caster_player_channels.gd"
class_name AbilityCasterInputModes


# Ground targeting still uses the caster's modal input path, but it is not the
# visible spell library. Keeping those ideas separate prevents the right stick
# from moving a target and browsing Focus at the same time.
func begin_ground_targeting(
	player: Node3D,
	ability: AbilityDefinition,
	ground_spell: Dictionary
) -> bool:
	var started: bool = super.begin_ground_targeting(player, ability, ground_spell)
	if started:
		_hide_focus_library_ui()
	return started


func is_focus_library_open() -> bool:
	return focus_spell_menu_open and not is_ground_targeting()


func open_focus_spell_menu() -> void:
	if is_ground_targeting():
		return
	super.open_focus_spell_menu()


func update_focus_spell_menu_ui() -> void:
	if is_ground_targeting():
		_hide_focus_library_ui()
		return
	super.update_focus_spell_menu_ui()


func _hide_focus_library_ui() -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("hide_spell_focus_menu"):
		ui.call("hide_spell_focus_menu")
	elif ui != null and ui.has_method("hide_spell_menu"):
		ui.call("hide_spell_menu")


func get_input_mode_debug_data() -> Dictionary:
	return {
		"ground_targeting": is_ground_targeting(),
		"focus_modal": focus_spell_menu_open,
		"focus_library_visible": is_focus_library_open(),
	}
