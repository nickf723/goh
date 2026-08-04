extends "res://scripts/ui/gameplay_context_hud.gd"
class_name GameplayContextHUDUnified

var unified_hud: Node
var unified_context_source: String = "gameplay_context"
var unified_publish_count: int = 0


func _ready() -> void:
	super._ready()
	_resolve_unified_hud()


func _process(delta: float) -> void:
	super._process(delta)
	_resolve_unified_hud()
	if unified_hud != null and panel != null:
		panel.modulate.a = 0.0
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _refresh() -> void:
	super._refresh()
	_resolve_unified_hud()
	if unified_hud == null:
		return
	if panel == null or not panel.visible:
		if unified_hud.has_method("clear_context"):
			unified_hud.call("clear_context", unified_context_source)


func _apply_context(data: Dictionary) -> void:
	super._apply_context(data)
	_resolve_unified_hud()
	if unified_hud == null:
		if panel != null:
			panel.modulate.a = 1.0
		return
	if panel != null:
		panel.modulate.a = 0.0
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not unified_hud.has_method("publish_context"):
		return
	unified_hud.call(
		"publish_context",
		unified_context_source,
		{
			"eyebrow": str(data.get("eyebrow", "CONTEXT")),
			"title": str(data.get("title", "")),
			"detail": str(data.get("state", data.get("detail", ""))),
			"controls": str(data.get("controls", "")),
			"valid": bool(data.get("valid", true)),
			"accent": (
				Color(0.36, 1.0, 0.66)
				if bool(data.get("valid", true))
				else Color(1.0, 0.42, 0.3)
			),
		},
		60,
		0.0
	)
	unified_publish_count += 1


func _resolve_unified_hud() -> void:
	if unified_hud != null and is_instance_valid(unified_hud):
		return
	unified_hud = get_tree().get_first_node_in_group("unified_hud_shell")
	if unified_hud != null:
		return
	if player == null or not is_instance_valid(player):
		return
	unified_hud = player.get_node_or_null("PlayerHUDV2")
	if unified_hud != null and not unified_hud.has_method("publish_context"):
		unified_hud = null


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["unified_hud"] = unified_hud != null and is_instance_valid(unified_hud)
	data["unified_publish_count"] = unified_publish_count
	data["legacy_panel_visually_retired"] = panel != null and is_zero_approx(panel.modulate.a)
	return data
