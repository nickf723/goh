extends Node
class_name QuickSpellBeltPresentation

@export_range(0.5, 5.0, 0.1) var reveal_seconds: float = 2.4
@export_range(1.0, 12.0, 0.5) var fade_speed: float = 7.0

var actor: CharacterBody3D
var hud: PlayerHUDV2
var router: Node
var belt_panel: PanelContainer
var belt_hint_label: Label
var slot_panels: Array[PanelContainer] = []
var slot_labels: Array[Label] = []
var reveal_remaining: float = 0.0
var display_alpha: float = 0.0
var setup_complete: bool = false
var focus_assignment_visible: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	actor = get_parent() as CharacterBody3D
	call_deferred("_finish_setup")
	add_to_group("quick_spell_belt_presentation")


func _finish_setup() -> void:
	_resolve_bindings()
	if hud == null or router == null:
		call_deferred("_finish_setup")
		return
	_build_belt()
	_connect_router_signals()
	_refresh_all_slots()
	_refresh_compact_window()
	setup_complete = true


func _process(delta: float) -> void:
	_resolve_bindings()
	if not setup_complete:
		return
	_refresh_compact_window()
	_refresh_all_slots()
	focus_assignment_visible = (
		router != null
		and router.has_method("is_focus_open")
		and bool(router.call("is_focus_open"))
	)
	if reveal_remaining > 0.0 and not focus_assignment_visible:
		reveal_remaining = maxf(reveal_remaining - maxf(delta, 0.0), 0.0)
	if belt_hint_label != null:
		belt_hint_label.text = (
			"FOCUS  •  PRESS 1–0 TO ASSIGN THE SELECTED SPELL"
			if focus_assignment_visible
			else "QUICK SPELLS  •  1–0 SELECT"
		)
		belt_hint_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.74, 0.28, 1.0)
			if focus_assignment_visible
			else Color(0.64, 0.74, 0.9, 0.9)
		)
	var target_alpha: float = (
		1.0 if focus_assignment_visible or reveal_remaining > 0.0 else 0.0
	)
	display_alpha = move_toward(
		display_alpha,
		target_alpha,
		maxf(delta, 0.0) * fade_speed
	)
	belt_panel.visible = display_alpha > 0.01
	belt_panel.modulate.a = display_alpha


func _resolve_bindings() -> void:
	if actor == null or not is_instance_valid(actor):
		actor = get_parent() as CharacterBody3D
	if actor == null:
		return
	if hud == null or not is_instance_valid(hud):
		hud = actor.get_node_or_null("PlayerHUDV2") as PlayerHUDV2
	if router == null or not is_instance_valid(router):
		router = actor.get_node_or_null("PlayerControlRouter")


func _connect_router_signals() -> void:
	if router == null:
		return
	if router.has_signal("quick_spell_activity"):
		var activity_callable: Callable = Callable(self, "_on_quick_spell_activity")
		if not router.is_connected("quick_spell_activity", activity_callable):
			router.connect("quick_spell_activity", activity_callable)
	if router.has_signal("quick_spell_assigned"):
		var assigned_callable: Callable = Callable(self, "_on_quick_spell_assigned")
		if not router.is_connected("quick_spell_assigned", assigned_callable):
			router.connect("quick_spell_assigned", assigned_callable)


func _build_belt() -> void:
	if hud == null or hud.root == null or belt_panel != null:
		return
	belt_panel = PanelContainer.new()
	belt_panel.name = "TenSlotQuickSpellBelt"
	belt_panel.anchor_left = 0.5
	belt_panel.anchor_top = 1.0
	belt_panel.anchor_right = 0.5
	belt_panel.anchor_bottom = 1.0
	belt_panel.offset_left = -445.0
	belt_panel.offset_top = -142.0
	belt_panel.offset_right = 445.0
	belt_panel.offset_bottom = -34.0
	belt_panel.visible = false
	belt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	belt_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.01, 0.016, 0.028, 0.96),
			Color(0.42, 0.62, 0.94, 0.68),
			15,
			2
		)
	)
	hud.root.add_child(belt_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 11)
	margin.add_theme_constant_override("margin_right", 11)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 9)
	belt_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)

	belt_hint_label = Label.new()
	belt_hint_label.text = "QUICK SPELLS  •  1–0 SELECT"
	belt_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	belt_hint_label.add_theme_font_size_override("font_size", 10)
	belt_hint_label.add_theme_color_override(
		"font_color",
		Color(0.64, 0.74, 0.9, 0.9)
	)
	stack.add_child(belt_hint_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	stack.add_child(row)

	for slot_index: int in range(10):
		var slot_panel := PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(80.0, 62.0)
		slot_panel.add_theme_stylebox_override(
			"panel",
			_make_slot_style(false, false)
		)
		row.add_child(slot_panel)
		slot_panels.append(slot_panel)

		var label := Label.new()
		label.text = str(slot_index + 1)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override(
			"font_color",
			Color(0.72, 0.8, 0.94, 0.92)
		)
		slot_panel.add_child(label)
		slot_labels.append(label)


func _refresh_compact_window() -> void:
	if hud == null or router == null:
		return
	if not router.has_method("get_quick_spell_window_rows"):
		return
	var rows_value: Variant = router.call("get_quick_spell_window_rows")
	if not rows_value is Array:
		return
	var rows: Array = rows_value as Array
	for index: int in range(mini(3, hud.quick_spell_labels.size())):
		if index >= rows.size() or not rows[index] is Dictionary:
			continue
		var row: Dictionary = rows[index] as Dictionary
		var name: String = str(row.get("name", "Empty"))
		var key_label: String = str(row.get("key_label", ""))
		hud.quick_spell_labels[index].text = key_label + "  " + name
		var selected: bool = bool(row.get("selected", false))
		hud.quick_spell_panels[index].add_theme_stylebox_override(
			"panel",
			_make_slot_style(selected, name == "Empty")
		)
		hud.quick_spell_labels[index].add_theme_color_override(
			"font_color",
			Color(1.0, 0.75, 0.28, 1.0)
			if selected
			else Color(0.74, 0.82, 0.94, 0.9)
		)


func _refresh_all_slots() -> void:
	if router == null or not router.has_method("get_quick_spell_slot_rows"):
		return
	var rows_value: Variant = router.call("get_quick_spell_slot_rows")
	if not rows_value is Array:
		return
	var rows: Array = rows_value as Array
	for slot_index: int in range(slot_labels.size()):
		if slot_index >= rows.size() or not rows[slot_index] is Dictionary:
			continue
		var row: Dictionary = rows[slot_index] as Dictionary
		var key_label: String = str(row.get("key_label", str(slot_index + 1)))
		var name: String = str(row.get("name", "Empty"))
		var selected: bool = bool(row.get("selected", false))
		var empty: bool = name == "Empty"
		slot_labels[slot_index].text = key_label + "\n" + _compact_name(name)
		slot_panels[slot_index].add_theme_stylebox_override(
			"panel",
			_make_slot_style(selected, empty)
		)
		slot_labels[slot_index].add_theme_color_override(
			"font_color",
			Color(1.0, 0.75, 0.28, 1.0)
			if selected
			else (
				Color(0.42, 0.48, 0.58, 0.72)
				if empty
				else Color(0.76, 0.84, 0.96, 0.94)
			)
		)


func _on_quick_spell_activity(source: String, _slot_index: int) -> void:
	if source in ["keyboard", "assignment"]:
		reveal_remaining = reveal_seconds
		_refresh_all_slots()


func _on_quick_spell_assigned(_slot_index: int, _spell_id: String) -> void:
	reveal_remaining = reveal_seconds
	_refresh_all_slots()


func reveal_belt(duration: float = -1.0) -> void:
	reveal_remaining = reveal_seconds if duration < 0.0 else maxf(duration, 0.0)


func _compact_name(name: String) -> String:
	if name == "Empty":
		return "—"
	if name.length() <= 13:
		return name
	return name.left(12).strip_edges() + "…"


func _make_slot_style(selected: bool, empty: bool) -> StyleBoxFlat:
	if selected:
		return _make_panel_style(
			Color(0.09, 0.045, 0.018, 0.98),
			Color(1.0, 0.55, 0.12, 0.96),
			9,
			2
		)
	if empty:
		return _make_panel_style(
			Color(0.02, 0.025, 0.038, 0.82),
			Color(0.2, 0.25, 0.34, 0.5),
			9,
			1
		)
	return _make_panel_style(
		Color(0.028, 0.038, 0.058, 0.94),
		Color(0.3, 0.43, 0.66, 0.7),
		9,
		1
	)


func _make_panel_style(
	fill: Color,
	border: Color,
	radius: int,
	border_width: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func get_debug_data() -> Dictionary:
	return {
		"setup_complete": setup_complete,
		"slot_count": slot_labels.size(),
		"visible": belt_panel != null and belt_panel.visible,
		"focus_assignment_visible": focus_assignment_visible,
		"reveal_remaining": snappedf(reveal_remaining, 0.01),
	}
