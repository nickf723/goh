extends CanvasLayer
class_name PlayerActiveAbilityRibbon

const SpellIcons = preload("res://scripts/ui/spell_icon_factory.gd")

@export_range(0.05, 0.5, 0.01) var refresh_interval: float = 0.12
@export_range(1, 8, 1) var maximum_entries: int = 5

var actor: Node3D
var ability_caster: Node
var context_menu: Node
var shared_placement_controller: Node

var ribbon_panel: PanelContainer
var entry_row: HBoxContainer
var current_entries: Array[Dictionary] = []
var last_signature: String = ""
var current_spell_id: String = ""
var highlighted_entry_id: String = ""
var refresh_remaining: float = 0.0
var rebuild_count: int = 0
var visual_refresh_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 54
	_build_interface()
	add_to_group("active_ability_ribbon")
	add_to_group("debuggable")


func bind_actor(actor_value: Node3D) -> void:
	actor = actor_value
	_resolve_bindings()
	_connect_caster_signal()
	force_refresh()


func _process(delta: float) -> void:
	_resolve_bindings()
	refresh_remaining = maxf(refresh_remaining - maxf(delta, 0.0), 0.0)
	if refresh_remaining > 0.0:
		_update_visibility()
		return
	refresh_remaining = refresh_interval
	_refresh_entries()


func force_refresh() -> void:
	refresh_remaining = 0.0
	last_signature = ""
	_refresh_entries()


func get_entries() -> Array[Dictionary]:
	return current_entries.duplicate(true)


func get_highlighted_entry_id() -> String:
	return highlighted_entry_id


func _resolve_bindings() -> void:
	if actor == null or not is_instance_valid(actor):
		actor = get_parent() as Node3D
	if actor == null:
		return
	if ability_caster == null or not is_instance_valid(ability_caster):
		ability_caster = actor.get_node_or_null("AbilityCaster")
		_connect_caster_signal()
	if context_menu == null or not is_instance_valid(context_menu):
		context_menu = actor.get_node_or_null("AbilityContextMenu")
	if (
		shared_placement_controller == null
		or not is_instance_valid(shared_placement_controller)
	):
		shared_placement_controller = actor.get_node_or_null(
			"SharedPlacementController"
		)


func _connect_caster_signal() -> void:
	if ability_caster == null or not is_instance_valid(ability_caster):
		return
	if not ability_caster.has_signal("ability_changed"):
		return
	var callback := Callable(self, "_on_ability_changed")
	if not ability_caster.is_connected("ability_changed", callback):
		ability_caster.connect("ability_changed", callback)


func _on_ability_changed(_ability_name: String, _ability_index: int) -> void:
	last_signature = ""
	_refresh_entries()


func _refresh_entries() -> void:
	if actor == null or not is_instance_valid(actor):
		current_entries.clear()
		_update_visibility()
		return
	current_spell_id = _get_current_spell_id()
	var entries: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	for child: Node in actor.get_children():
		if child == self or not is_instance_valid(child):
			continue
		var entry: Dictionary = _entry_from_provider(child)
		if entry.is_empty():
			continue
		var entry_id: String = str(entry.get("id", child.name)).strip_edges()
		if entry_id == "":
			entry_id = str(child.name)
		if seen_ids.has(entry_id):
			continue
		seen_ids[entry_id] = true
		entry["id"] = entry_id
		entry["highlighted"] = _entry_matches_spell(entry, current_spell_id)
		entries.append(entry)
	entries.sort_custom(Callable(self, "_sort_entries"))
	if entries.size() > maximum_entries:
		entries.resize(maximum_entries)

	highlighted_entry_id = ""
	for entry: Dictionary in entries:
		if bool(entry.get("highlighted", false)):
			highlighted_entry_id = str(entry.get("id", ""))
			break
	var signature: String = _make_signature(entries, current_spell_id)
	current_entries = entries
	if signature != last_signature:
		last_signature = signature
		_rebuild_entries()
	else:
		visual_refresh_count += 1
	_update_visibility()


func _entry_from_provider(provider: Node) -> Dictionary:
	if provider.has_method("get_active_ability_ribbon_entry"):
		var explicit_value: Variant = provider.call(
			"get_active_ability_ribbon_entry"
		)
		if explicit_value is Dictionary:
			var explicit: Dictionary = (
				explicit_value as Dictionary
			).duplicate(true)
			if bool(explicit.get("active", true)):
				return _normalize_entry(provider, explicit)
			return {}
	if not provider.has_method("get_ability_context_status"):
		return {}
	var status_value: Variant = provider.call("get_ability_context_status")
	if not status_value is Dictionary:
		return {}
	var status: Dictionary = status_value as Dictionary
	if not bool(status.get("active", false)):
		return {}
	return _normalize_entry(provider, {
		"active": true,
		"label": str(status.get("title", provider.name)),
		"state": str(status.get("state", "Active")),
		"attention": bool(status.get("attention", false)),
	})


func _normalize_entry(provider: Node, raw: Dictionary) -> Dictionary:
	var entry: Dictionary = raw.duplicate(true)
	var provider_name: String = str(provider.name)
	var normalized_name: String = provider_name.to_lower()
	var spell_ids: Array[String] = _string_array(entry.get("spell_ids", []))
	if spell_ids.is_empty() and str(entry.get("spell_id", "")) != "":
		spell_ids.append(str(entry.get("spell_id", "")))
	for property_name: String in [
		"handled_spell_id",
		"assembly_spell_id",
		"deploy_spell_id",
	]:
		var property_value: Variant = _read_property(provider, property_name, null)
		if property_value != null:
			var spell_id: String = str(property_value).strip_edges()
			if spell_id != "" and not spell_ids.has(spell_id):
				spell_ids.append(spell_id)

	var entry_id: String = str(entry.get("id", ""))
	var icon_text: String = str(entry.get("icon_text", ""))
	var element: String = str(entry.get("element", "neutral"))
	var priority: int = int(entry.get("priority", 50))
	if entry_id == "":
		if normalized_name.contains("summon") or spell_ids.has("spectral_familiar"):
			entry_id = "familiar"
			icon_text = "♢" if icon_text == "" else icon_text
			priority = mini(priority, 10)
		elif normalized_name.contains("recorded") or spell_ids.has("recorded_object_summon"):
			entry_id = "recorded_objects"
			icon_text = "▣" if icon_text == "" else icon_text
			priority = mini(priority, 20)
		elif normalized_name.contains("artificer") or spell_ids.has("artificer_assembly"):
			entry_id = "artificer"
			icon_text = "⚙" if icon_text == "" else icon_text
			element = "metal" if element == "neutral" else element
			priority = mini(priority, 30)
		else:
			entry_id = normalized_name

	entry["id"] = entry_id
	entry["label"] = str(entry.get("label", entry.get("title", provider_name)))
	entry["state"] = str(entry.get("state", "Active"))
	entry["spell_ids"] = spell_ids
	entry["spell_id"] = spell_ids[0] if not spell_ids.is_empty() else ""
	entry["icon_text"] = icon_text
	entry["element"] = element
	entry["priority"] = priority
	entry["attention"] = bool(entry.get("attention", false))
	entry["provider_name"] = provider_name
	return entry


func _entry_matches_spell(entry: Dictionary, spell_id: String) -> bool:
	if spell_id == "":
		return false
	for candidate: String in _string_array(entry.get("spell_ids", [])):
		if candidate == spell_id:
			return true
	return str(entry.get("spell_id", "")) == spell_id


func _read_property(
	node: Object,
	property_name: String,
	fallback: Variant
) -> Variant:
	if node == null:
		return fallback
	for property_info: Dictionary in node.get_property_list():
		if str(property_info.get("name", "")) == property_name:
			return node.get(property_name)
	return fallback


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw).strip_edges()
			if text != "" and not result.has(text):
				result.append(text)
	elif value != null:
		var text: String = str(value).strip_edges()
		if text != "":
			result.append(text)
	return result


func _sort_entries(a: Dictionary, b: Dictionary) -> bool:
	var priority_a: int = int(a.get("priority", 50))
	var priority_b: int = int(b.get("priority", 50))
	if priority_a == priority_b:
		return str(a.get("label", "")) < str(b.get("label", ""))
	return priority_a < priority_b


func _make_signature(entries: Array[Dictionary], spell_id: String) -> String:
	var parts: Array[String] = [spell_id]
	for entry: Dictionary in entries:
		parts.append(
			str(entry.get("id", ""))
			+ "|"
			+ str(entry.get("label", ""))
			+ "|"
			+ str(entry.get("state", ""))
			+ "|"
			+ str(entry.get("highlighted", false))
			+ "|"
			+ str(entry.get("attention", false))
		)
	return "::".join(parts)


func _rebuild_entries() -> void:
	if entry_row == null:
		return
	for child: Node in entry_row.get_children():
		entry_row.remove_child(child)
		child.queue_free()
	for entry: Dictionary in current_entries:
		entry_row.add_child(_make_entry_card(entry))
	rebuild_count += 1


func _make_entry_card(entry: Dictionary) -> PanelContainer:
	var highlighted: bool = bool(entry.get("highlighted", false))
	var attention: bool = bool(entry.get("attention", false))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(172.0, 42.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = (
		Color(0.085, 0.045, 0.014, 0.98)
		if highlighted
		else Color(0.014, 0.026, 0.044, 0.95)
	)
	style.border_color = (
		Color(1.0, 0.58, 0.12, 0.98)
		if highlighted
		else (
			Color(1.0, 0.32, 0.18, 0.92)
			if attention
			else Color(0.28, 0.48, 0.72, 0.66)
		)
	)
	style.set_border_width_all(2 if highlighted or attention else 1)
	style.set_corner_radius_all(11)
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_bottom", 4)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	margin.add_child(row)

	var icon_entry: Dictionary = {
		"name": str(entry.get("label", "Active ability")),
		"spell_id": str(entry.get("spell_id", "")),
		"element": str(entry.get("element", "neutral")),
		"icon_text": str(entry.get("icon_text", "")),
		"icon_path": str(entry.get("icon_path", "")),
	}
	row.add_child(SpellIcons.create_badge(
		icon_entry,
		31.0,
		highlighted,
		highlighted
	))

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 0)
	row.add_child(stack)
	var label := Label.new()
	label.text = str(entry.get("label", "Active"))
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.78, 0.32, 1.0)
		if highlighted
		else Color(0.9, 0.95, 1.0, 0.96)
	)
	stack.add_child(label)
	var state_label := Label.new()
	state_label.text = str(entry.get("state", "Active"))
	state_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	state_label.add_theme_font_size_override("font_size", 8)
	state_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.48, 0.34, 0.96)
		if attention
		else Color(0.58, 0.7, 0.84, 0.9)
	)
	stack.add_child(state_label)
	card.tooltip_text = str(entry.get("label", "Active")) + " • " + str(entry.get("state", ""))
	card.set_meta("ribbon_entry", entry.duplicate(true))
	return card


func _build_interface() -> void:
	ribbon_panel = PanelContainer.new()
	ribbon_panel.name = "ActiveAbilityRibbonPanel"
	ribbon_panel.anchor_left = 0.5
	ribbon_panel.anchor_top = 1.0
	ribbon_panel.anchor_right = 0.5
	ribbon_panel.anchor_bottom = 1.0
	ribbon_panel.offset_left = -560.0
	ribbon_panel.offset_top = -184.0
	ribbon_panel.offset_right = 560.0
	ribbon_panel.offset_bottom = -138.0
	ribbon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon_panel.visible = false
	ribbon_panel.add_to_group("menu_suppressed_hud")
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.006, 0.012, 0.022, 0.82)
	style.border_color = Color(0.24, 0.38, 0.58, 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(13)
	ribbon_panel.add_theme_stylebox_override("panel", style)
	add_child(ribbon_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 2)
	ribbon_panel.add_child(margin)
	entry_row = HBoxContainer.new()
	entry_row.alignment = BoxContainer.ALIGNMENT_CENTER
	entry_row.add_theme_constant_override("separation", 6)
	margin.add_child(entry_row)


func _update_visibility() -> void:
	if ribbon_panel == null:
		return
	ribbon_panel.visible = (
		not current_entries.is_empty()
		and not _focus_library_open()
		and not _shared_placement_active()
	)


func _focus_library_open() -> bool:
	return (
		ability_caster != null
		and is_instance_valid(ability_caster)
		and ability_caster.has_method("is_focus_library_open")
		and bool(ability_caster.call("is_focus_library_open"))
	)


func _shared_placement_active() -> bool:
	return (
		shared_placement_controller != null
		and is_instance_valid(shared_placement_controller)
		and shared_placement_controller.has_method("is_placement_active")
		and bool(shared_placement_controller.call("is_placement_active"))
	)


func _get_current_spell_id() -> String:
	if ability_caster == null or not is_instance_valid(ability_caster):
		return ""
	if not ability_caster.has_method("get_current_ability"):
		return ""
	var value: Variant = ability_caster.call("get_current_ability")
	if value is AbilityDefinition:
		return (value as AbilityDefinition).get_spell_id()
	return ""


func get_debug_data() -> Dictionary:
	return {
		"installed": true,
		"visible": ribbon_panel != null and ribbon_panel.visible,
		"entry_count": current_entries.size(),
		"entries": current_entries.duplicate(true),
		"current_spell_id": current_spell_id,
		"highlighted_entry_id": highlighted_entry_id,
		"rebuild_count": rebuild_count,
		"visual_refresh_count": visual_refresh_count,
		"maximum_entries": maximum_entries,
	}
