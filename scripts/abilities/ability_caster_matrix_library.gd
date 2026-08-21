extends "res://scripts/abilities/ability_caster_focus_library.gd"
class_name AbilityCasterMatrixLibrary

# Production Grace should see the complete authored spell library without requiring
# every new AbilityDefinition to be hand-added to grace_starting_loadout.tres.
# Explicit equipped/quick slots remain authoritative; discovery expands only the
# learned Focus library exposed by AbilityLoadout.

@export_group("Elemental Matrix Library")
@export_dir var matrix_ability_root: String = "res://data/abilities"
@export var discover_authored_matrix_spells: bool = true

var matrix_library_enabled: bool = false
var matrix_library_spell_count: int = 0


func _ready() -> void:
	_configure_matrix_library()
	super._ready()
	_refresh_matrix_library_debug()


func _configure_matrix_library() -> void:
	matrix_library_enabled = false
	if loadout == null or not discover_authored_matrix_spells:
		return
	loadout.auto_discover_authored_abilities = true
	loadout.authored_ability_root = matrix_ability_root
	loadout.invalidate_authored_library_cache()
	matrix_library_enabled = true


func refresh_matrix_spell_library() -> void:
	if loadout == null:
		return
	loadout.authored_ability_root = matrix_ability_root
	loadout.invalidate_authored_library_cache()
	_refresh_matrix_library_debug()
	align_focus_menu_to_current_ability()
	if focus_spell_menu_open:
		update_focus_spell_menu_ui()


func _refresh_matrix_library_debug() -> void:
	matrix_library_spell_count = 0
	if loadout == null or not matrix_library_enabled:
		return
	matrix_library_spell_count = loadout.get_learned_abilities().size()


func get_matrix_library_debug_data() -> Dictionary:
	var loadout_data: Dictionary = (
		loadout.get_library_debug_data()
		if loadout != null
		else {}
	)
	return {
		"matrix_library": true,
		"enabled": matrix_library_enabled,
		"root": matrix_ability_root,
		"learned_spell_count": matrix_library_spell_count,
		"loadout": loadout_data,
		"equipped_slots_unchanged": true,
	}
