extends Node
class_name QuickSpellBeltPresentation


@export_range(0.5, 5.0, 0.1) var reveal_seconds: float = 2.4
@export_range(0.5, 5.0, 0.1) var item_menu_reveal_seconds: float = 1.5
@export_range(0.65, 1.0, 0.01) var minimum_dock_scale: float = 0.76

var actor: CharacterBody3D
var hud: PlayerHUDV2
var router: Node
var quick_item_controller: PlayerQuickItemController
var divine_controller: PlayerDivineSpecialController
var divine_router: Node
var game_ui: Node

# belt_panel remains the compatibility name used by the quick-spell smoke test.
var belt_panel: PanelContainer
var dock_panel: PanelContainer
var belt_hint_label: Label
var slot_panels: Array[PanelContainer] = []
var slot_labels: Array[Label] = []

var item_tile: PanelContainer
var item_label: Label
var item_progress_bar: ProgressBar
var item_menu_panel: PanelContainer
var item_menu_rows: Array[PanelContainer] = []
var item_menu_labels: Array[Label] = []

var special_tile: PanelContainer
var special_label: Label
var special_charge_bar: ProgressBar
var special_charge_label: Label
var special_menu_panel: PanelContainer
var special_menu_rows: Array[PanelContainer] = []
var special_menu_labels: Array[Label] = []
var special_menu_hint: Label

var reveal_remaining: float = 0.0
var item_reveal_remaining: float = 0.0
var setup_complete: bool = false
var focus_assignment_visible: bool = false
var dock_scale: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	actor = get_parent() as CharacterBody3D
	call_deferred("_finish_setup")
	add_to_group("quick_spell_belt_presentation")
	add_to_group("player_command_dock")


func _finish_setup() -> void:
	_resolve_bindings()
	if hud == null or router == null:
		call_deferred("_finish_setup")
		return
	_conceal_legacy_quick_panel()
	_build_command_dock()
	_build_item_menu()
	_build_special_menu()
	_connect_runtime_signals()
	_refresh_all_slots()
	_refresh_item_presentation(0.0)
	_refresh_special_presentation()
	_align_focus_panel()
	setup_complete = true


func _process(delta: float) -> void:
	_resolve_bindings()
	if not setup_complete:
		return
	_conceal_legacy_quick_panel()
	_update_responsive_scale()
	focus_assignment_visible = (
		router != null
		and router.has_method("is_focus_open")
		and bool(router.call("is_focus_open"))
	)
	if reveal_remaining > 0.0:
		reveal_remaining = maxf(reveal_remaining - maxf(delta, 0.0), 0.0)
	if item_reveal_remaining > 0.0:
		item_reveal_remaining = maxf(
			item_reveal_remaining - maxf(delta, 0.0),
			0.0
		)
	_refresh_all_slots()
	_refresh_item_presentation(delta)
	_refresh_special_presentation()
	_refresh_focus_copy()
	_align_focus_panel()
	if dock_panel != null:
		dock_panel.visible = true
		dock_panel.modulate.a = 0.76 if focus_assignment_visible else 1.0


func _resolve_bindings() -> void:
	if actor == null or not is_instance_valid(actor):
		actor = get_parent() as CharacterBody3D
	if actor == null:
		return
	if hud == null or not is_instance_valid(hud):
		hud = actor.get_node_or_null("PlayerHUDV2") as PlayerHUDV2
	if router == null or not is_instance_valid(router):
		router = actor.get_node_or_null("PlayerControlRouter")
	if quick_item_controller == null or not is_instance_valid(quick_item_controller):
		quick_item_controller = actor.get_node_or_null(
			"PlayerQuickItemController"
		) as PlayerQuickItemController
	if divine_controller == null or not is_instance_valid(divine_controller):
		divine_controller = actor.get_node_or_null(
			"DivineSpecialController"
		) as PlayerDivineSpecialController
	if divine_router == null or not is_instance_valid(divine_router):
		divine_router = actor.get_node_or_null("DivineSpecialInputRouter")
	if game_ui == null or not is_instance_valid(game_ui):
		game_ui = get_tree().get_first_node_in_group("game_ui")


func _connect_runtime_signals() -> void:
	if router != null:
		_connect_signal_once(
			router,
			"quick_spell_activity",
			Callable(self, "_on_quick_spell_activity")
		)
		_connect_signal_once(
			router,
			"quick_spell_assigned",
			Callable(self, "_on_quick_spell_assigned")
		)
		_connect_signal_once(
			router,
			"quick_item_selection_changed",
			Callable(self, "_on_quick_item_selection_changed")
		)
	if quick_item_controller != null:
		_connect_signal_once(
			quick_item_controller,
			"belt_changed",
			Callable(self, "_on_quick_item_belt_changed")
		)
	if divine_controller != null:
		_connect_signal_once(
			divine_controller,
			"selected_special_changed",
			Callable(self, "_on_selected_special_changed")
		)
		_connect_signal_once(
			divine_controller,
			"charge_changed",
			Callable(self, "_on_divine_charge_changed")
		)


func _connect_signal_once(source: Object, signal_name: StringName, callback: Callable) -> void:
	if source == null or not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, callback):
		source.connect(signal_name, callback)


func _conceal_legacy_quick_panel() -> void:
	if hud == null or hud.quick_panel == null:
		return
	# Keep the node alive and visible for older compatibility checks, while removing
	# its duplicate presentation from the rendered HUD.
	hud.quick_panel.visible = true
	hud.quick_panel.modulate.a = 0.0
	hud.quick_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build_command_dock() -> void:
	if hud == null or hud.root == null or dock_panel != null:
		return
	dock_panel = PanelContainer.new()
	dock_panel.name = "PermanentDPadCommandDock"
	dock_panel.anchor_left = 0.5
	dock_panel.anchor_top = 1.0
	dock_panel.anchor_right = 0.5
	dock_panel.anchor_bottom = 1.0
	dock_panel.offset_left = -590.0
	dock_panel.offset_top = -132.0
	dock_panel.offset_right = 590.0
	dock_panel.offset_bottom = -18.0
	dock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.009, 0.015, 0.027, 0.965),
			Color(0.36, 0.54, 0.84, 0.66),
			16,
			2
		)
	)
	hud.root.add_child(dock_panel)
	belt_panel = dock_panel

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	dock_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	_build_item_tile(row)
	_build_spell_section(row)
	_build_special_tile(row)


func _build_item_tile(parent: HBoxContainer) -> void:
	item_tile = PanelContainer.new()
	item_tile.name = "DPadUpItemTile"
	item_tile.custom_minimum_size = Vector2(188.0, 86.0)
	item_tile.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.018, 0.032, 0.052, 0.94),
			Color(0.28, 0.62, 0.94, 0.7),
			11,
			1
		)
	)
	parent.add_child(item_tile)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	item_tile.add_child(margin)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 3)
	margin.add_child(stack)

	item_label = Label.new()
	item_label.text = "D↑  QUICK ITEM\nEmpty"
	item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	item_label.add_theme_font_size_override("font_size", 10)
	item_label.add_theme_color_override("font_color", Color(0.72, 0.88, 1.0))
	stack.add_child(item_label)

	item_progress_bar = ProgressBar.new()
	item_progress_bar.min_value = 0.0
	item_progress_bar.max_value = 1.0
	item_progress_bar.value = 0.0
	item_progress_bar.show_percentage = false
	item_progress_bar.custom_minimum_size = Vector2(0.0, 6.0)
	item_progress_bar.add_theme_stylebox_override(
		"background",
		_make_panel_style(
			Color(0.035, 0.055, 0.078, 0.95),
			Color(0.12, 0.18, 0.26, 0.45),
			3,
			0
		)
	)
	item_progress_bar.add_theme_stylebox_override(
		"fill",
		_make_panel_style(
			Color(0.22, 0.7, 1.0, 0.96),
			Color(0.22, 0.7, 1.0, 0.96),
			3,
			0
		)
	)
	stack.add_child(item_progress_bar)

	var hint := Label.new()
	hint.text = "TAP CYCLE  •  HOLD USE"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color(0.5, 0.62, 0.78, 0.86))
	stack.add_child(hint)


func _build_spell_section(parent: HBoxContainer) -> void:
	var spell_stack := VBoxContainer.new()
	spell_stack.name = "TenSpellSection"
	spell_stack.custom_minimum_size = Vector2(764.0, 86.0)
	spell_stack.add_theme_constant_override("separation", 4)
	parent.add_child(spell_stack)

	belt_hint_label = Label.new()
	belt_hint_label.text = "D← / D→  QUICK SPELLS   •   1–0 SELECT"
	belt_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	belt_hint_label.add_theme_font_size_override("font_size", 9)
	belt_hint_label.add_theme_color_override(
		"font_color",
		Color(0.64, 0.74, 0.9, 0.9)
	)
	spell_stack.add_child(belt_hint_label)

	var slot_row := HBoxContainer.new()
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_row.add_theme_constant_override("separation", 4)
	spell_stack.add_child(slot_row)

	for slot_index: int in range(10):
		var slot_panel := PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(72.0, 59.0)
		slot_panel.add_theme_stylebox_override(
			"panel",
			_make_slot_style(false, false)
		)
		slot_row.add_child(slot_panel)
		slot_panels.append(slot_panel)

		var label := Label.new()
		label.text = str(slot_index + 1)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.add_theme_font_size_override("font_size", 9)
		label.add_theme_color_override(
			"font_color",
			Color(0.72, 0.8, 0.94, 0.92)
		)
		slot_panel.add_child(label)
		slot_labels.append(label)


func _build_special_tile(parent: HBoxContainer) -> void:
	special_tile = PanelContainer.new()
	special_tile.name = "DPadDownSpecialTile"
	special_tile.custom_minimum_size = Vector2(188.0, 86.0)
	special_tile.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.052, 0.025, 0.014, 0.94),
			Color(1.0, 0.43, 0.08, 0.74),
			11,
			1
		)
	)
	parent.add_child(special_tile)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	special_tile.add_child(margin)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 2)
	margin.add_child(stack)

	special_label = Label.new()
	special_label.text = "D↓  DIVINE SPECIAL\nNone"
	special_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	special_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	special_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	special_label.add_theme_font_size_override("font_size", 9)
	special_label.add_theme_color_override("font_color", Color(1.0, 0.68, 0.24))
	stack.add_child(special_label)

	special_charge_bar = ProgressBar.new()
	special_charge_bar.min_value = 0.0
	special_charge_bar.max_value = 100.0
	special_charge_bar.value = 0.0
	special_charge_bar.show_percentage = false
	special_charge_bar.custom_minimum_size = Vector2(0.0, 6.0)
	special_charge_bar.add_theme_stylebox_override(
		"background",
		_make_panel_style(
			Color(0.12, 0.05, 0.022, 0.94),
			Color(0.3, 0.12, 0.04, 0.5),
			3,
			0
		)
	)
	special_charge_bar.add_theme_stylebox_override(
		"fill",
		_make_panel_style(
			Color(1.0, 0.45, 0.07, 0.98),
			Color(1.0, 0.45, 0.07, 0.98),
			3,
			0
		)
	)
	stack.add_child(special_charge_bar)

	special_charge_label = Label.new()
	special_charge_label.text = "0%  •  HOLD SELECT"
	special_charge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	special_charge_label.add_theme_font_size_override("font_size", 8)
	special_charge_label.add_theme_color_override(
		"font_color",
		Color(0.86, 0.7, 0.55, 0.9)
	)
	stack.add_child(special_charge_label)


func _build_item_menu() -> void:
	if hud == null or hud.root == null or item_menu_panel != null:
		return
	item_menu_panel = PanelContainer.new()
	item_menu_panel.name = "DPadUpItemMenu"
	item_menu_panel.anchor_left = 0.5
	item_menu_panel.anchor_top = 1.0
	item_menu_panel.anchor_right = 0.5
	item_menu_panel.anchor_bottom = 1.0
	item_menu_panel.offset_left = -590.0
	item_menu_panel.offset_top = -352.0
	item_menu_panel.offset_right = -392.0
	item_menu_panel.offset_bottom = -142.0
	item_menu_panel.visible = false
	item_menu_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_menu_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.012, 0.025, 0.043, 0.965),
			Color(0.3, 0.68, 1.0, 0.72),
			13,
			2
		)
	)
	hud.root.add_child(item_menu_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	item_menu_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	margin.add_child(stack)

	var title := Label.new()
	title.text = "D↑  ITEM BELT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(0.58, 0.82, 1.0))
	stack.add_child(title)

	for slot_index: int in range(4):
		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(0.0, 34.0)
		row.add_theme_stylebox_override("panel", _make_item_row_style(false, true))
		stack.add_child(row)
		item_menu_rows.append(row)

		var label := Label.new()
		label.text = str(slot_index + 1) + "  Empty"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.add_theme_font_size_override("font_size", 9)
		row.add_child(label)
		item_menu_labels.append(label)


func _build_special_menu() -> void:
	if hud == null or hud.root == null or special_menu_panel != null:
		return
	special_menu_panel = PanelContainer.new()
	special_menu_panel.name = "DPadDownSpecialMenu"
	special_menu_panel.anchor_left = 0.5
	special_menu_panel.anchor_top = 1.0
	special_menu_panel.anchor_right = 0.5
	special_menu_panel.anchor_bottom = 1.0
	special_menu_panel.offset_left = 392.0
	special_menu_panel.offset_top = -352.0
	special_menu_panel.offset_right = 590.0
	special_menu_panel.offset_bottom = -142.0
	special_menu_panel.visible = false
	special_menu_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	special_menu_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.045, 0.02, 0.012, 0.97),
			Color(1.0, 0.42, 0.07, 0.78),
			13,
			2
		)
	)
	hud.root.add_child(special_menu_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	special_menu_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	margin.add_child(stack)

	var title := Label.new()
	title.text = "D↓  DIVINE SPECIALS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(1.0, 0.68, 0.24))
	stack.add_child(title)

	for _slot_index: int in range(4):
		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(0.0, 34.0)
		row.visible = false
		row.add_theme_stylebox_override("panel", _make_special_row_style(false, false))
		stack.add_child(row)
		special_menu_rows.append(row)

		var label := Label.new()
		label.text = "Special"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.add_theme_font_size_override("font_size", 9)
		row.add_child(label)
		special_menu_labels.append(label)

	special_menu_hint = Label.new()
	special_menu_hint.text = "RIGHT STICK SELECT\nRELEASE DOWN TO KEEP"
	special_menu_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	special_menu_hint.add_theme_font_size_override("font_size", 8)
	special_menu_hint.add_theme_color_override(
		"font_color",
		Color(0.86, 0.68, 0.5, 0.9)
	)
	stack.add_child(special_menu_hint)


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
		slot_labels[slot_index].text = key_label + "\n" + _compact_name(name, 11)
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


func _refresh_item_presentation(_delta: float) -> void:
	if item_label == null or item_progress_bar == null:
		return
	var selected_slot: int = 0
	if router != null and router.has_method("get_selected_quick_item_slot"):
		selected_slot = int(router.call("get_selected_quick_item_slot"))
	selected_slot = clampi(selected_slot, 0, 3)

	var item: QuickItemDefinition = null
	var charges: int = 0
	if quick_item_controller != null:
		item = quick_item_controller.get_slot_item(selected_slot)
		charges = quick_item_controller.get_slot_charges(selected_slot)
	var item_name: String = item.display_name if item != null else "Empty"
	item_label.text = "D↑  QUICK ITEM\n" + item_name + " ×" + str(charges)

	var button_down: bool = false
	var hold_elapsed: float = 0.0
	var hold_seconds: float = 0.28
	var hold_consumed: bool = false
	if router != null:
		button_down = bool(router.get("quick_item_button_down"))
		hold_elapsed = float(router.get("quick_item_hold_elapsed"))
		hold_seconds = maxf(float(router.get("quick_item_hold_seconds")), 0.01)
		hold_consumed = bool(router.get("quick_item_hold_consumed"))
	var progress: float = 0.0
	if button_down and not hold_consumed:
		progress = clampf(hold_elapsed / hold_seconds, 0.0, 1.0)
	elif quick_item_controller != null and quick_item_controller.is_using_item():
		progress = 1.0 - (
			quick_item_controller.use_timer
			/ maxf(quick_item_controller.use_total_duration, 0.01)
		)
	item_progress_bar.value = clampf(progress, 0.0, 1.0)

	var menu_visible: bool = (
		(button_down or item_reveal_remaining > 0.0)
		and not focus_assignment_visible
	)
	if item_menu_panel != null:
		item_menu_panel.visible = menu_visible
	_refresh_item_menu_rows(selected_slot)


func _refresh_item_menu_rows(selected_slot: int) -> void:
	if quick_item_controller == null:
		return
	for slot_index: int in range(item_menu_rows.size()):
		var item: QuickItemDefinition = quick_item_controller.get_slot_item(slot_index)
		var charges: int = quick_item_controller.get_slot_charges(slot_index)
		var empty: bool = item == null
		var selected: bool = slot_index == selected_slot
		var name: String = item.display_name if item != null else "Empty"
		item_menu_labels[slot_index].text = (
			("◆ " if selected else "  ")
			+ str(slot_index + 1)
			+ "  "
			+ name
			+ (" ×" + str(charges) if not empty else "")
		)
		item_menu_labels[slot_index].add_theme_color_override(
			"font_color",
			Color(0.72, 0.9, 1.0)
			if selected
			else Color(0.64, 0.72, 0.84, 0.86)
		)
		item_menu_rows[slot_index].add_theme_stylebox_override(
			"panel",
			_make_item_row_style(selected, empty)
		)


func _refresh_special_presentation() -> void:
	if special_label == null or special_charge_bar == null:
		return
	var selected: DivineSpecialDefinition = null
	var charge: float = 0.0
	var maximum: float = 100.0
	var ready: bool = false
	if divine_controller != null:
		selected = divine_controller.get_selected_special(OS.is_debug_build())
		charge = divine_controller.divine_charge
		maximum = maxf(divine_controller.maximum_charge, 1.0)
		ready = selected != null and charge + 0.001 >= selected.required_charge
	var selected_name: String = selected.display_name if selected != null else "None"
	special_label.text = "D↓  DIVINE SPECIAL\n" + selected_name
	special_charge_bar.max_value = maximum
	special_charge_bar.value = charge
	var percent: int = roundi(charge / maximum * 100.0)
	special_charge_label.text = (
		str(percent)
		+ "%  •  "
		+ ("TAP ACTIVATE" if ready else "RECHARGING")
	)

	var radial_open: bool = (
		divine_router != null and bool(divine_router.get("radial_open"))
	)
	if special_menu_panel != null:
		special_menu_panel.visible = radial_open and not focus_assignment_visible
	_refresh_special_menu_rows(selected, charge)
	_suppress_fullscreen_special_radial(radial_open)


func _refresh_special_menu_rows(
	selected: DivineSpecialDefinition,
	charge: float
) -> void:
	var definitions: Array[DivineSpecialDefinition] = []
	if divine_controller != null:
		definitions = divine_controller.get_available_specials(OS.is_debug_build())
	for row_index: int in range(special_menu_rows.size()):
		var has_definition: bool = row_index < definitions.size()
		special_menu_rows[row_index].visible = has_definition
		if not has_definition:
			continue
		var definition: DivineSpecialDefinition = definitions[row_index]
		var is_selected: bool = (
			selected != null and selected.special_id == definition.special_id
		)
		var ready: bool = charge + 0.001 >= definition.required_charge
		special_menu_labels[row_index].text = (
			("◆ " if is_selected else "  ")
			+ _compact_name(definition.display_name, 19)
			+ ("  READY" if ready else "  " + str(roundi(charge)) + "%")
		)
		special_menu_labels[row_index].add_theme_color_override(
			"font_color",
			Color(1.0, 0.73, 0.28)
			if is_selected
			else Color(0.84, 0.68, 0.56, 0.88)
		)
		special_menu_rows[row_index].add_theme_stylebox_override(
			"panel",
			_make_special_row_style(is_selected, ready)
		)


func _suppress_fullscreen_special_radial(radial_open: bool) -> void:
	if actor == null:
		return
	var radial_menu: Node = actor.get_node_or_null("DivineSpecialRadialMenu")
	if radial_menu == null:
		return
	var root_value: Variant = radial_menu.get("root")
	if root_value is Control and radial_open:
		(root_value as Control).visible = false


func _refresh_focus_copy() -> void:
	if belt_hint_label == null:
		return
	belt_hint_label.text = (
		"FOCUS  •  D-PAD BROWSE LIBRARY  •  1–0 ASSIGN"
		if focus_assignment_visible
		else "D← / D→  QUICK SPELLS   •   1–0 SELECT"
	)
	belt_hint_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.74, 0.28, 1.0)
		if focus_assignment_visible
		else Color(0.64, 0.74, 0.9, 0.9)
	)
	if game_ui == null:
		return
	var help_value: Variant = game_ui.get("focus_spell_help_label")
	if help_value is Label:
		(help_value as Label).text = (
			"D-pad: browse library   •   1–0: assign selected spell   •   Release L: close"
		)


func _align_focus_panel() -> void:
	if game_ui == null:
		return
	var panel_value: Variant = game_ui.get("focus_spell_panel")
	if not panel_value is Control:
		return
	var panel: Control = panel_value as Control
	var half_width: float = 430.0 * dock_scale
	panel.anchor_left = 0.5
	panel.anchor_top = 1.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -half_width
	panel.offset_top = -438.0
	panel.offset_right = half_width
	panel.offset_bottom = -148.0


func _update_responsive_scale() -> void:
	if actor == null or dock_panel == null:
		return
	var viewport_width: float = actor.get_viewport().get_visible_rect().size.x
	dock_scale = clampf(
		(viewport_width - 300.0) / 1180.0,
		minimum_dock_scale,
		1.0
	)
	for panel: PanelContainer in [dock_panel, item_menu_panel, special_menu_panel]:
		if panel == null:
			continue
		panel.scale = Vector2.ONE * dock_scale
		panel.pivot_offset = panel.size * 0.5


func _on_quick_spell_activity(source: String, _slot_index: int) -> void:
	if source in ["keyboard", "assignment"]:
		reveal_remaining = reveal_seconds
	_refresh_all_slots()


func _on_quick_spell_assigned(_slot_index: int, _spell_id: String) -> void:
	reveal_remaining = reveal_seconds
	_refresh_all_slots()


func _on_quick_item_selection_changed(_slot_index: int) -> void:
	item_reveal_remaining = item_menu_reveal_seconds


func _on_quick_item_belt_changed() -> void:
	item_reveal_remaining = maxf(item_reveal_remaining, 0.45)


func _on_selected_special_changed(_definition: DivineSpecialDefinition) -> void:
	_refresh_special_presentation()


func _on_divine_charge_changed(
	_current: float,
	_maximum: float,
	_reason: String
) -> void:
	_refresh_special_presentation()


func reveal_belt(duration: float = -1.0) -> void:
	reveal_remaining = reveal_seconds if duration < 0.0 else maxf(duration, 0.0)


func _compact_name(name: String, limit: int = 13) -> String:
	if name == "Empty":
		return "—"
	if name.length() <= limit:
		return name
	return name.left(maxi(limit - 1, 1)).strip_edges() + "…"


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


func _make_item_row_style(selected: bool, empty: bool) -> StyleBoxFlat:
	if selected:
		return _make_panel_style(
			Color(0.025, 0.09, 0.14, 0.96),
			Color(0.3, 0.76, 1.0, 0.92),
			8,
			2
		)
	return _make_panel_style(
		Color(0.022, 0.034, 0.052, 0.86),
		Color(0.16, 0.28, 0.42, 0.44),
		8,
		1 if not empty else 0
	)


func _make_special_row_style(selected: bool, ready: bool) -> StyleBoxFlat:
	if selected:
		return _make_panel_style(
			Color(0.11, 0.043, 0.015, 0.98),
			Color(1.0, 0.5, 0.08, 0.96),
			8,
			2
		)
	return _make_panel_style(
		Color(0.052, 0.025, 0.018, 0.9),
		Color(0.46, 0.2, 0.08, 0.58 if ready else 0.36),
		8,
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
		"visible": dock_panel != null and dock_panel.visible,
		"permanent": true,
		"focus_assignment_visible": focus_assignment_visible,
		"reveal_remaining": snappedf(reveal_remaining, 0.01),
		"item_menu_visible": item_menu_panel != null and item_menu_panel.visible,
		"special_menu_visible": special_menu_panel != null and special_menu_panel.visible,
		"item_tile": item_tile != null,
		"special_tile": special_tile != null,
		"legacy_quick_concealed": (
			hud != null
			and hud.quick_panel != null
			and is_zero_approx(hud.quick_panel.modulate.a)
		),
		"focus_aligned": (
			game_ui != null
			and game_ui.get("focus_spell_panel") is Control
			and is_equal_approx(
				(game_ui.get("focus_spell_panel") as Control).offset_bottom,
				-148.0
			)
		),
		"dock_scale": snappedf(dock_scale, 0.01),
	}
