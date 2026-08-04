extends "res://scripts/ui/persistent_ability_context_menu.gd"
class_name PersistentAbilityContextMenuUnified

var unified_hud: Node


func bind_actor(actor_value: Node3D) -> void:
	super.bind_actor(actor_value)
	_resolve_unified_hud()
	_refresh_compact_status()


func _process(delta: float) -> void:
	super._process(delta)
	_resolve_unified_hud()
	if unified_hud != null and compact_panel != null:
		compact_panel.visible = false
		compact_panel.modulate.a = 0.0


func _refresh_compact_status() -> void:
	_resolve_unified_hud()
	if unified_hud == null:
		super._refresh_compact_status()
		return
	if compact_panel != null:
		compact_panel.visible = false
		compact_panel.modulate.a = 0.0


func _resolve_unified_hud() -> void:
	if unified_hud != null and is_instance_valid(unified_hud):
		return
	unified_hud = get_tree().get_first_node_in_group("unified_hud_shell")
	if unified_hud != null:
		return
	if actor == null or not is_instance_valid(actor):
		return
	unified_hud = actor.get_node_or_null("PlayerHUDV2")
	if unified_hud != null and not unified_hud.has_method("get_hud_zone"):
		unified_hud = null


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["unified_hud"] = unified_hud != null and is_instance_valid(unified_hud)
	data["compact_status_retired"] = (
		compact_panel != null
		and not compact_panel.visible
	)
	return data
