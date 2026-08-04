extends "res://scripts/player/player_shared_placement_controller.gd"
class_name PlayerSharedPlacementControllerUnified

var unified_hud: Node
var unified_publish_count: int = 0


func bind_actor(actor_value: Node3D) -> void:
	super.bind_actor(actor_value)
	_resolve_unified_hud()


func _process(delta: float) -> void:
	super._process(delta)
	_resolve_unified_hud()
	if placement_active:
		_publish_placement_state()


func _update_interface() -> void:
	super._update_interface()
	_resolve_unified_hud()
	if unified_hud == null:
		if panel != null:
			panel.modulate.a = 1.0
		return
	if panel != null:
		panel.modulate.a = 0.0
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_publish_placement_state()


func _finish_session(committed: bool, notify_provider: bool) -> void:
	var had_session: bool = placement_active
	super._finish_session(committed, notify_provider)
	if had_session:
		_clear_unified_placement()


func _publish_placement_state() -> void:
	if unified_hud == null or not is_instance_valid(unified_hud):
		return
	if placement_state.is_empty():
		return
	var eyebrow: String = str(placement_state.get("eyebrow", "PLACEMENT"))
	var title: String = str(placement_state.get("title", "Placement"))
	var valid: bool = bool(placement_state.get("valid", false))
	var status: String = (
		"VALID POSITION"
		if valid
		else str(placement_state.get(
			"reason",
			"That placement cannot fit there."
		))
	)
	var details: String = _placement_details()
	var controls: String = str(placement_state.get(
		"controls",
		"Right stick aim  •  D-pad ↑/↓ depth  •  D-pad ←/→ variant  •  L/R rotate  •  Cast/A confirm  •  B cancel"
	))
	if unified_hud.has_method("publish_mode"):
		unified_hud.call(
			"publish_mode",
			"shared_placement",
			{
				"eyebrow": eyebrow,
				"title": title,
				"detail": details,
				"accent": Color(0.3, 0.86, 1.0),
			},
			100
		)
	if unified_hud.has_method("publish_context"):
		unified_hud.call(
			"publish_context",
			"shared_placement",
			{
				"eyebrow": "PLACEMENT",
				"title": status,
				"detail": details,
				"controls": controls,
				"valid": valid,
				"accent": (
					Color(0.36, 1.0, 0.66)
					if valid
					else Color(1.0, 0.42, 0.3)
				),
			},
			110,
			0.0
		)
	unified_publish_count += 1


func _placement_details() -> String:
	var parts: Array[String] = []
	if placement_state.has("mana_cost"):
		parts.append(str(int(placement_state.get("mana_cost", 0))) + " MANA")
	if placement_state.has("depth"):
		parts.append("DEPTH " + str(snappedf(float(placement_state.get("depth", 0.0)), 0.25)))
	if placement_state.has("rotation"):
		parts.append("ROTATION " + str(int(round(float(placement_state.get("rotation", 0.0))))) + "°")
	if placement_state.has("active_count"):
		var count: int = int(placement_state.get("active_count", 0))
		var limit: int = int(placement_state.get("active_limit", 0))
		parts.append(
			str(count) + "/" + str(limit) + " ACTIVE"
			if limit > 0
			else str(count) + " ACTIVE"
		)
	if placement_state.has("draft_count"):
		parts.append(str(int(placement_state.get("draft_count", 0))) + " DRAFT PARTS")
	if placement_state.has("part_count"):
		parts.append(str(int(placement_state.get("part_count", 0))) + " PARTS")
	return "  •  ".join(parts)


func _clear_unified_placement() -> void:
	_resolve_unified_hud()
	if unified_hud == null:
		return
	if unified_hud.has_method("clear_mode"):
		unified_hud.call("clear_mode", "shared_placement")
	if unified_hud.has_method("clear_context"):
		unified_hud.call("clear_context", "shared_placement")


func _resolve_unified_hud() -> void:
	if unified_hud != null and is_instance_valid(unified_hud):
		return
	unified_hud = get_tree().get_first_node_in_group("unified_hud_shell")
	if unified_hud != null:
		return
	if actor == null or not is_instance_valid(actor):
		return
	unified_hud = actor.get_node_or_null("PlayerHUDV2")
	if unified_hud != null and not unified_hud.has_method("publish_mode"):
		unified_hud = null


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["unified_hud"] = unified_hud != null and is_instance_valid(unified_hud)
	data["unified_publish_count"] = unified_publish_count
	data["legacy_panel_visually_retired"] = panel != null and is_zero_approx(panel.modulate.a)
	return data
