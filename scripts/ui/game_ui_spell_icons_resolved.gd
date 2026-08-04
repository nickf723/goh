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
