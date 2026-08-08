extends Node
class_name VineGrappleMarkerArbiter

var player: Node3D = null


func _ready() -> void:
	# CombatTargetingAssist uses the default process priority. Running late makes
	# marker ownership deterministic even when the GameUI appears before Player
	# in the scene tree.
	process_priority = 1000
	add_to_group("vine_grapple_marker_arbiters")
	add_to_group("debuggable")


func _process(_delta: float) -> void:
	if not _resolve_player():
		return
	if not _vine_grapple_is_selected():
		return

	# Vine Grapple owns a stronger, spell-specific pre-cast marker. Hide the
	# generic blue soft-aim ring while it is selected so the screen never claims
	# that two different objects are the current grapple target.
	var assist: Node = player.get_node_or_null("CombatTargetingAssist")
	if assist == null:
		return
	var marker_value: Variant = assist.get("soft_marker")
	if marker_value is Node3D:
		(marker_value as Node3D).visible = false


func _resolve_player() -> bool:
	if player != null and is_instance_valid(player) and player.is_inside_tree():
		return true
	player = null
	if get_tree() == null:
		return false
	var grouped: Node = get_tree().get_first_node_in_group("player")
	if grouped is Node3D:
		player = grouped as Node3D
		return true
	var scene: Node = get_tree().current_scene
	if scene != null:
		var fallback: Node = scene.find_child("Player", true, false)
		if fallback is Node3D:
			player = fallback as Node3D
	return player != null


func _vine_grapple_is_selected() -> bool:
	if player == null:
		return false
	var caster: Node = player.get_node_or_null("AbilityCaster")
	if caster == null or not caster.has_method("get_current_ability"):
		return false
	var ability_value: Variant = caster.call("get_current_ability")
	if not ability_value is AbilityDefinition:
		return false
	return (ability_value as AbilityDefinition).get_spell_id() == "vine_grapple"


func get_debug_data() -> Dictionary:
	var assist: Node = player.get_node_or_null("CombatTargetingAssist") if player != null else null
	var generic_visible: bool = false
	if assist != null:
		var marker_value: Variant = assist.get("soft_marker")
		if marker_value is Node3D:
			generic_visible = (marker_value as Node3D).visible
	return {
		"vine_marker_arbiter": true,
		"vine_selected": _vine_grapple_is_selected(),
		"generic_soft_marker_visible": generic_visible,
		"process_priority": process_priority,
	}
