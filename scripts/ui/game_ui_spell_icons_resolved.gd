extends "res://scripts/ui/game_ui_spell_icons.gd"
class_name GameUISpellIconsResolved

# Production levels register Grace in the player group. Standalone player scenes,
# smoke fixtures, and future avatar previews may not have a level script available
# to do that yet, so the icon layer keeps one narrow scene-tree fallback.


func _get_player_ability_caster() -> Node:
	var grouped: Node = super._get_player_ability_caster()
	if grouped != null:
		return grouped
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	return scene.find_child("AbilityCaster", true, false)


func _get_player_router() -> Node:
	var grouped: Node = super._get_player_router()
	if grouped != null:
		return grouped
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	return scene.find_child("PlayerControlRouter", true, false)


# The icon-rich Focus presenter historically interpreted the caster's element
# indices as positions in equipped_abilities. Focus now owns learned_abilities,
# while equipped_abilities is only runtime casting storage. Resolve the authored
# AbilityDefinition resources directly so replacing a quick slot cannot corrupt
# the rows, icons, ordering, or equipped marker in Focus.
func _get_focus_spell_entries(element: String) -> Array[Dictionary]:
	var caster: Node = _get_player_ability_caster()
	if (
		caster == null
		or not caster.has_method("get_focus_abilities_for_element")
	):
		return super._get_focus_spell_entries(element)

	var abilities_value: Variant = caster.call(
		"get_focus_abilities_for_element",
		element
	)
	if not abilities_value is Array:
		return super._get_focus_spell_entries(element)

	var current_ability: AbilityDefinition = null
	if caster.has_method("get_current_ability"):
		var current_value: Variant = caster.call("get_current_ability")
		if current_value is AbilityDefinition:
			current_ability = current_value as AbilityDefinition
	var current_spell_id: String = (
		current_ability.get_spell_id()
		if current_ability != null
		else ""
	)

	var learned: Array[AbilityDefinition] = []
	if caster.has_method("get_focus_library_abilities"):
		var learned_value: Variant = caster.call("get_focus_library_abilities")
		if learned_value is Array:
			for raw_learned: Variant in learned_value as Array:
				if raw_learned is AbilityDefinition:
					learned.append(raw_learned as AbilityDefinition)

	var entries: Array[Dictionary] = []
	for raw_ability: Variant in abilities_value as Array:
		if not raw_ability is AbilityDefinition:
			continue
		var ability: AbilityDefinition = raw_ability as AbilityDefinition
		var spell_id: String = ability.get_spell_id()
		entries.append(SpellIcons.entry_from_ability(
			ability,
			learned.find(ability),
			spell_id != "" and spell_id == current_spell_id
		))
	return entries


func get_focus_library_icon_debug_data(element: String) -> Dictionary:
	var entries: Array[Dictionary] = _get_focus_spell_entries(element)
	var spell_ids: Array[String] = []
	for entry: Dictionary in entries:
		spell_ids.append(str(entry.get("spell_id", "")))
	return {
		"source": "learned_abilities",
		"element": element,
		"entry_count": entries.size(),
		"spell_ids": spell_ids,
		"quickbar_independent": true,
	}
