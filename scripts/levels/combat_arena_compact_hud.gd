extends Node
class_name CombatArenaCompactHud

const WeaponMasteryCatalogScript = preload("res://scripts/weapons/weapon_mastery_catalog.gd")
const WeaponTechniqueCatalogScript = preload("res://scripts/weapons/weapon_technique_catalog.gd")

@export var collapsed_size: Vector2 = Vector2(650.0, 118.0)
@export var expanded_size: Vector2 = Vector2(790.0, 430.0)
@export var refresh_interval: float = 0.08

var director: Node
var weapon_controller: Node
var panel: PanelContainer
var vbox: VBoxContainer
var compact_label: Label
var expanded_label: Label
var guide_expanded: bool = false
var refresh_timer: float = 0.0


func _ready() -> void:
	director = get_parent()
	call_deferred("bind_hud")


func bind_hud() -> void:
	if director == null:
		return
	weapon_controller = director.get_node_or_null("Player/WeaponController")
	panel = director.get_node_or_null("CombatHUD/Panel") as PanelContainer
	vbox = director.get_node_or_null("CombatHUD/Panel/Margin/VBox") as VBoxContainer
	if panel == null or vbox == null:
		return

	for label_name: String in [
		"WeaponLabel",
		"AttackLabel",
		"QueueLabel",
		"CancelLabel",
		"SandboxLabel",
		"ComboGuideLabel",
		"TechniqueGuideLabel",
	]:
		var old_label: Label = vbox.get_node_or_null(label_name) as Label
		if old_label != null:
			old_label.visible = false

	compact_label = vbox.get_node_or_null("CompactSummaryLabel") as Label
	if compact_label == null:
		compact_label = Label.new()
		compact_label.name = "CompactSummaryLabel"
		compact_label.add_theme_font_size_override("font_size", 15)
		compact_label.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0, 1.0))
		compact_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		compact_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(compact_label)

	expanded_label = vbox.get_node_or_null("ExpandedGuideLabel") as Label
	if expanded_label == null:
		expanded_label = Label.new()
		expanded_label.name = "ExpandedGuideLabel"
		expanded_label.add_theme_font_size_override("font_size", 13)
		expanded_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0, 1.0))
		expanded_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		expanded_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(expanded_label)

	apply_panel_mode()
	refresh_hud()


func _process(delta: float) -> void:
	if compact_label == null or not is_instance_valid(compact_label):
		bind_hud()
		return
	refresh_timer -= delta
	if refresh_timer > 0.0:
		return
	refresh_timer = maxf(refresh_interval, 0.03)
	refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.physical_keycode != KEY_F7:
		return
	guide_expanded = not guide_expanded
	apply_panel_mode()
	refresh_hud()
	get_viewport().set_input_as_handled()


func apply_panel_mode() -> void:
	if panel == null:
		return
	var target_size: Vector2 = expanded_size if guide_expanded else collapsed_size
	panel.offset_right = panel.offset_left + target_size.x
	panel.offset_bottom = panel.offset_top + target_size.y
	if expanded_label != null:
		expanded_label.visible = guide_expanded


func refresh_hud() -> void:
	if weapon_controller == null or not weapon_controller.has_method("get_debug_data"):
		return
	var data: Dictionary = weapon_controller.call("get_debug_data")
	var weapon_class: String = str(data.get("class", "none"))
	var mastery_rank: int = GameState.get_weapon_mastery_rank(weapon_class)
	var rank_name: String = WeaponMasteryCatalogScript.get_rank_name(mastery_rank).to_upper()
	var route_progress: Vector2i = get_route_progress()
	var technique_progress: Vector2i = get_technique_progress(weapon_class)
	var chain_text: String = abbreviate_chain(data.get("chain", []))
	var attack_text: String = abbreviate_text(str(data.get("attack", "none")), 24)
	var phase_text: String = str(data.get("phase", "idle")).to_upper()
	var technique_text: String = abbreviate_technique(str(data.get("technique", "none")))
	var cast_open: String = "C✓" if bool(data.get("cast_cancel", false)) else "C·"
	var dodge_open: String = "D✓" if bool(data.get("dodge_cancel", false)) else "D·"

	compact_label.text = (
		weapon_class.to_upper()
		+ " • "
		+ rank_name
		+ "  |  "
		+ attack_text
		+ " ["
		+ phase_text
		+ "]  |  T:"
		+ technique_text
		+ "\n"
		+ "Chain "
		+ chain_text
		+ "  |  Routes "
		+ str(route_progress.x)
		+ "/"
		+ str(route_progress.y)
		+ "  |  Tech "
		+ str(technique_progress.x)
		+ "/"
		+ str(technique_progress.y)
		+ "  |  "
		+ cast_open
		+ " "
		+ dodge_open
		+ "\nF7 Guide  •  F8 Reset  •  Sandbox + refill ON"
	)

	if guide_expanded and expanded_label != null:
		expanded_label.text = build_expanded_guide(weapon_class)


func get_route_progress() -> Vector2i:
	if director == null:
		return Vector2i.ZERO
	var routes_value: Variant = director.get("current_combo_routes")
	var completed_value: Variant = director.get("completed_route_keys")
	if not routes_value is Array or not completed_value is Dictionary:
		return Vector2i.ZERO
	var completed_keys: Dictionary = completed_value as Dictionary
	var completed_count: int = 0
	for route_value: Variant in routes_value as Array:
		if not route_value is Dictionary:
			continue
		var key: String = str((route_value as Dictionary).get("key", ""))
		if bool(completed_keys.get(key, false)):
			completed_count += 1
	return Vector2i(completed_count, (routes_value as Array).size())


func get_technique_progress(weapon_class: String) -> Vector2i:
	if director == null:
		return Vector2i.ZERO
	var completed_value: Variant = director.get("completed_technique_keys")
	if not completed_value is Dictionary:
		return Vector2i.ZERO
	var completed_keys: Dictionary = completed_value as Dictionary
	var completed_count: int = 0
	for technique_id: String in get_technique_ids():
		if bool(completed_keys.get(weapon_class + ":" + technique_id, false)):
			completed_count += 1
	return Vector2i(completed_count, get_technique_ids().size())


func build_expanded_guide(weapon_class: String) -> String:
	var lines: Array[String] = ["ROUTES"]
	var routes_value: Variant = director.get("current_combo_routes")
	var completed_value: Variant = director.get("completed_route_keys")
	var completed_keys: Dictionary = completed_value as Dictionary if completed_value is Dictionary else {}
	if routes_value is Array:
		for route_value: Variant in routes_value as Array:
			if not route_value is Dictionary:
				continue
			var route: Dictionary = route_value as Dictionary
			var token_value: Variant = route.get("tokens", [])
			var tokens: Array[String] = []
			if token_value is Array:
				for token: Variant in token_value as Array:
					tokens.append(str(token))
			var key: String = str(route.get("key", ""))
			var suffix: String = " ↻" if bool(route.get("loops", false)) else ""
			lines.append(
				("✓ " if bool(completed_keys.get(key, false)) else "□ ")
				+ "-".join(tokens)
				+ "  "
				+ str(route.get("final_name", "Finisher"))
				+ suffix
			)
	else:
		lines.append("No authored routes")

	lines.append("\nTECHNIQUES")
	var technique_completed_value: Variant = director.get("completed_technique_keys")
	var technique_completed: Dictionary = technique_completed_value as Dictionary if technique_completed_value is Dictionary else {}
	for technique_id: String in get_technique_ids():
		var instruction: String = technique_id
		if director.has_method("get_technique_instruction"):
			instruction = str(director.call("get_technique_instruction", weapon_class, technique_id))
		lines.append(
			("✓ " if bool(technique_completed.get(weapon_class + ":" + technique_id, false)) else "□ ")
			+ instruction
		)
	return "\n".join(lines)


func abbreviate_chain(chain_value: Variant) -> String:
	if not chain_value is Array or (chain_value as Array).is_empty():
		return "·"
	var tokens: Array[String] = []
	for entry: Variant in chain_value as Array:
		var attack_id: String = str(entry).to_lower()
		tokens.append("H" if "_h" in attack_id or "heavy" in attack_id else "L")
	return "-".join(tokens)


func abbreviate_technique(technique_id: String) -> String:
	match technique_id:
		WeaponTechniqueCatalogScript.CONTEXT_DASH:
			return "DASH"
		WeaponTechniqueCatalogScript.CONTEXT_AERIAL_NEUTRAL:
			return "N-AIR"
		WeaponTechniqueCatalogScript.CONTEXT_AERIAL_FORWARD:
			return "F-AIR"
		WeaponTechniqueCatalogScript.CONTEXT_AERIAL_DOWN:
			return "PLUNGE"
		_:
			return "·"


func abbreviate_text(text: String, max_length: int) -> String:
	if text.length() <= max_length:
		return text
	return text.left(maxi(max_length - 1, 1)) + "…"


func get_technique_ids() -> Array[String]:
	return [
		WeaponTechniqueCatalogScript.CONTEXT_DASH,
		WeaponTechniqueCatalogScript.CONTEXT_AERIAL_NEUTRAL,
		WeaponTechniqueCatalogScript.CONTEXT_AERIAL_FORWARD,
		WeaponTechniqueCatalogScript.CONTEXT_AERIAL_DOWN,
	]
