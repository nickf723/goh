extends "res://scripts/ui/player_active_ability_ribbon.gd"
class_name PlayerActiveAbilityRibbonUnified

var unified_hud: Node
var unified_sync_count: int = 0


func bind_actor(actor_value: Node3D) -> void:
	super.bind_actor(actor_value)
	_resolve_unified_hud()
	_sync_unified_entries()


func _process(delta: float) -> void:
	super._process(delta)
	_resolve_unified_hud()
	_sync_unified_entries()


func _rebuild_entries() -> void:
	super._rebuild_entries()
	_sync_unified_entries()


func _update_visibility() -> void:
	_resolve_unified_hud()
	if unified_hud == null:
		super._update_visibility()
		return
	_sync_unified_entries()
	if ribbon_panel != null:
		ribbon_panel.visible = false
		ribbon_panel.modulate.a = 0.0


func _resolve_unified_hud() -> void:
	if unified_hud != null and is_instance_valid(unified_hud):
		return
	unified_hud = get_tree().get_first_node_in_group("unified_hud_shell")
	if unified_hud != null:
		return
	if actor == null or not is_instance_valid(actor):
		return
	unified_hud = actor.get_node_or_null("PlayerHUDV2")
	if unified_hud != null and not unified_hud.has_method("set_active_ability_entries"):
		unified_hud = null


func _sync_unified_entries() -> void:
	if unified_hud == null or not is_instance_valid(unified_hud):
		return
	if not unified_hud.has_method("set_active_ability_entries"):
		return
	unified_hud.call(
		"set_active_ability_entries",
		current_entries,
		highlighted_entry_id
	)
	unified_sync_count += 1


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["unified_sink"] = unified_hud != null and is_instance_valid(unified_hud)
	data["unified_sync_count"] = unified_sync_count
	data["legacy_ribbon_hidden"] = (
		ribbon_panel != null
		and not ribbon_panel.visible
	)
	return data
