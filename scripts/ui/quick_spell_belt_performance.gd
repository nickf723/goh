extends "res://scripts/ui/quick_spell_belt_presentation.gd"
class_name QuickSpellBeltPerformance

const SpellIcons = preload("res://scripts/ui/spell_icon_factory.gd")

@export_range(0.05, 0.3, 0.01) var static_refresh_interval: float = 0.1
@export var fallback_polling_enabled: bool = false
@export_range(1.0, 30.0, 0.5) var fallback_poll_interval: float = 5.0

var equipped_ability_caster: Node
var observed_loadout: AbilityLoadout
var equipped_slot_indices: Array[int] = []
var cursor_slot_indices: Array[int] = []
var slot_icon_badges: Array[PanelContainer] = []
var slot_icon_entries: Array[Dictionary] = []
var equipped_spell_name: String = "None"
var equipped_spell_glyph: String = "·"
var cached_selected_special: DivineSpecialDefinition
var static_refresh_remaining: float = 0.0
var fallback_poll_remaining: float = 0.0
var slots_dirty: bool = false
var items_dirty: bool = false
var special_dirty: bool = false
var last_focus_state: bool = false
var last_radial_state: bool = false
var last_viewport_width: float = -1.0
var last_item_progress: float = -1.0
var last_item_menu_visible: bool = false
var last_special_percent: int = -1
var last_special_maximum: float = -1.0
var last_dock_alpha: float = -1.0
var style_cache: Dictionary = {}
var process_frames: int = 0
var heavy_refreshes: int = 0
var fallback_poll_count: int = 0
var fast_item_writes: int = 0
var fast_special_writes: int = 0
var loadout_signal_connected: bool = false
var game_state_signals_connected: bool = false


func _resolve_bindings() -> void:
	super._resolve_bindings()
	if actor == null:
		return
	if (
		equipped_ability_caster == null
		or not is_instance_valid(equipped_ability_caster)
	):
		equipped_ability_caster = actor.get_node_or_null("AbilityCaster")
		_connect_equipped_spell_signal()
	_connect_loadout_signal()


func _finish_setup() -> void:
	super._finish_setup()
	if not setup_complete:
		return
	_resolve_bindings()
	_ensure_slot_icon_badges()
	_connect_equipped_spell_signal()
	_connect_loadout_signal()
	_connect_game_state_signals()
	_update_responsive_scale()
	_align_focus_panel()
	last_focus_state = focus_assignment_visible
	last_radial_state = _is_special_radial_open()
	last_viewport_width = _get_viewport_width()
	static_refresh_remaining = static_refresh_interval
	fallback_poll_remaining = fallback_poll_interval
	slots_dirty = true
	items_dirty = false
	special_dirty = false
	_refresh_all_slots()
	_capture_fast_special_state()


func _exit_tree() -> void:
	_disconnect_loadout_signal()
	_disconnect_game_state_signals()


func _process(delta: float) -> void:
	_resolve_bindings()
	if not setup_complete:
		return
	process_frames += 1
	var step: float = maxf(delta, 0.0)

	if reveal_remaining > 0.0:
		reveal_remaining = maxf(reveal_remaining - step, 0.0)
	if item_reveal_remaining > 0.0:
		item_reveal_remaining = maxf(item_reveal_remaining - step, 0.0)

	var focus_now: bool = (
		router != null
		and router.has_method("is_focus_open")
		and bool(router.call("is_focus_open"))
	)
	if focus_now != last_focus_state:
		last_focus_state = focus_now
		focus_assignment_visible = focus_now
		_refresh_focus_copy()
		_align_focus_panel()
		items_dirty = true
		special_dirty = true

	var viewport_width: float = _get_viewport_width()
	if not is_equal_approx(viewport_width, last_viewport_width):
		last_viewport_width = viewport_width
		_update_responsive_scale()
		_align_focus_panel()

	_update_fast_item_progress()
	_update_fast_special_visibility()

	if fallback_polling_enabled:
		fallback_poll_remaining -= step
		if fallback_poll_remaining <= 0.0:
			fallback_poll_remaining = fallback_poll_interval
			fallback_poll_count += 1
			slots_dirty = true
			items_dirty = true
			special_dirty = true

	if slots_dirty or items_dirty or special_dirty:
		static_refresh_remaining -= step
		if static_refresh_remaining <= 0.0:
			static_refresh_remaining = static_refresh_interval
			heavy_refreshes += 1
			if slots_dirty:
				_refresh_all_slots()
				slots_dirty = false
			if items_dirty:
				_refresh_item_presentation(0.0)
				items_dirty = false
			if special_dirty:
				_refresh_special_presentation()
				special_dirty = false
	else:
		static_refresh_remaining = static_refresh_interval

	if dock_panel != null:
		if not dock_panel.visible:
			dock_panel.visible = true
		var target_alpha: float = 0.84 if focus_assignment_visible else 1.0
		if not is_equal_approx(target_alpha, last_dock_alpha):
			last_dock_alpha = target_alpha
			dock_panel.modulate.a = target_alpha


func _ensure_slot_icon_badges() -> void:
	if slot_panels.is_empty() or slot_labels.size() != slot_panels.size():
		return
	var complete: bool = slot_icon_badges.size() == slot_panels.size()
	if complete:
		for badge: PanelContainer in slot_icon_badges:
			if badge == null or not is_instance_valid(badge):
				complete = false
				break
	if complete:
		return

	slot_icon_badges.clear()
	for slot_index: int in range(slot_panels.size()):
		var panel: PanelContainer = slot_panels[slot_index]
		var label: Label = slot_labels[slot_index]
		var stack: VBoxContainer = panel.get_node_or_null(
			"SpellSlotStack"
		) as VBoxContainer
		if stack == null:
			var previous_parent: Node = label.get_parent()
			if previous_parent != null:
				previous_parent.remove_child(label)
			stack = VBoxContainer.new()
			stack.name = "SpellSlotStack"
			stack.alignment = BoxContainer.ALIGNMENT_CENTER
			stack.add_theme_constant_override("separation", 0)
			stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(stack)
			stack.add_child(label)

		label.custom_minimum_size = Vector2(0.0, 12.0)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 7)

		var badge: PanelContainer = stack.get_node_or_null(
			"SpellSlotBadge"
		) as PanelContainer
		if badge == null:
			badge = SpellIcons.create_badge(
				{
					"name": "Empty",
					"spell_id": "",
					"element": "neutral",
					"icon_text": "·",
				},
				31.0,
				false,
				false
			)
			badge.name = "SpellSlotBadge"
			badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			stack.add_child(badge)
		slot_icon_badges.append(badge)


func _refresh_all_slots() -> void:
	_ensure_slot_icon_badges()
	if router == null or not router.has_method("get_quick_spell_slot_rows"):
		return
	var rows_value: Variant = router.call("get_quick_spell_slot_rows")
	if not rows_value is Array:
		return
	var rows: Array = rows_value as Array
	var current_ability_index: int = -1
	var loadout: AbilityLoadout = null
	var equipped_entry: Dictionary = {
		"name": "None",
		"spell_id": "",
		"element": "neutral",
	}
	if equipped_ability_caster != null and is_instance_valid(equipped_ability_caster):
		current_ability_index = int(
			equipped_ability_caster.get("current_ability_index")
		)
		var loadout_value: Variant = equipped_ability_caster.get("loadout")
		if loadout_value is AbilityLoadout:
			loadout = loadout_value as AbilityLoadout
			var current_ability: AbilityDefinition = loadout.get_equipped_ability(
				current_ability_index
			)
			if current_ability != null:
				equipped_entry = SpellIcons.entry_from_ability(
					current_ability,
					current_ability_index,
					true
				)
	equipped_spell_name = str(equipped_entry.get("name", "None"))
	equipped_spell_glyph = SpellIcons.get_glyph(equipped_entry)
	if belt_hint_label != null:
		belt_hint_label.text = (
			"EQUIPPED  "
			+ equipped_spell_glyph
			+ " "
			+ _compact_name(equipped_spell_name, 24)
			+ "   •   D← / D→ QUICK SPELLS   •   1–0 SELECT"
		)
		belt_hint_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.72, 0.24, 0.98)
		)
	equipped_slot_indices.clear()
	cursor_slot_indices.clear()
	slot_icon_entries.clear()
	for slot_index: int in range(slot_labels.size()):
		if slot_index >= rows.size() or not rows[slot_index] is Dictionary:
			slot_icon_entries.append({})
			continue
		var row: Dictionary = rows[slot_index] as Dictionary
		var key_label: String = str(
			row.get("key_label", str(slot_index + 1))
		)
		var name: String = str(row.get("name", "Empty"))
		var ability_index: int = int(row.get("ability_index", -1))
		var cursor_selected: bool = bool(row.get("selected", false))
		var equipped: bool = (
			ability_index >= 0
			and ability_index == current_ability_index
		)
		var empty: bool = name == "Empty" or ability_index < 0
		if cursor_selected:
			cursor_slot_indices.append(slot_index)
		if equipped:
			equipped_slot_indices.append(slot_index)
		var icon_entry: Dictionary = {
			"name": name,
			"spell_id": str(row.get("spell_id", "")),
			"element": "neutral",
			"icon_text": "·" if empty else "",
		}
		if loadout != null and ability_index >= 0:
			var ability: AbilityDefinition = loadout.get_equipped_ability(
				ability_index
			)
			if ability != null:
				icon_entry = SpellIcons.entry_from_ability(
					ability,
					ability_index,
					equipped
				)
		slot_icon_entries.append(icon_entry.duplicate(false))
		var marker: String = ""
		if equipped:
			marker = " ★"
		elif cursor_selected:
			marker = " ◇"
		slot_labels[slot_index].text = key_label + marker
		if slot_index < slot_icon_badges.size():
			var badge: PanelContainer = slot_icon_badges[slot_index]
			SpellIcons.update_badge(
				badge,
				icon_entry,
				cursor_selected,
				equipped
			)
			badge.modulate.a = 0.34 if empty else 1.0
			badge.tooltip_text = key_label + " • " + name
		slot_panels[slot_index].tooltip_text = key_label + " • " + name
		slot_panels[slot_index].add_theme_stylebox_override(
			"panel",
			_make_equipped_slot_style(
				equipped,
				cursor_selected,
				empty
			)
		)
		slot_labels[slot_index].add_theme_color_override(
			"font_color",
			Color(1.0, 0.78, 0.26, 1.0)
			if equipped
			else (
				Color(0.58, 0.82, 1.0, 1.0)
				if cursor_selected
				else (
					Color(0.42, 0.48, 0.58, 0.72)
					if empty
					else Color(0.76, 0.84, 0.96, 0.94)
				)
			)
		)


func _connect_equipped_spell_signal() -> void:
	if (
		equipped_ability_caster == null
		or not is_instance_valid(equipped_ability_caster)
		or not equipped_ability_caster.has_signal("ability_changed")
	):
		return
	var callback := Callable(self, "_on_equipped_spell_changed")
	if not equipped_ability_caster.is_connected("ability_changed", callback):
		equipped_ability_caster.connect("ability_changed", callback)


func _connect_loadout_signal() -> void:
	var next_loadout: AbilityLoadout = null
	if equipped_ability_caster != null and is_instance_valid(equipped_ability_caster):
		var loadout_value: Variant = equipped_ability_caster.get("loadout")
		if loadout_value is AbilityLoadout:
			next_loadout = loadout_value as AbilityLoadout
	if next_loadout == observed_loadout and loadout_signal_connected:
		return
	_disconnect_loadout_signal()
	observed_loadout = next_loadout
	if observed_loadout == null or not observed_loadout.has_signal(
		"equipped_ability_changed"
	):
		return
	var callback := Callable(self, "_on_loadout_equipped_ability_changed")
	if not observed_loadout.is_connected("equipped_ability_changed", callback):
		observed_loadout.connect("equipped_ability_changed", callback)
	loadout_signal_connected = true


func _disconnect_loadout_signal() -> void:
	if observed_loadout != null and is_instance_valid(observed_loadout):
		var callback := Callable(self, "_on_loadout_equipped_ability_changed")
		if observed_loadout.is_connected("equipped_ability_changed", callback):
			observed_loadout.disconnect("equipped_ability_changed", callback)
	loadout_signal_connected = false
	observed_loadout = null


func _connect_game_state_signals() -> void:
	if game_state_signals_connected:
		return
	var slot_callback := Callable(self, "_on_persistent_quick_spell_slot_changed")
	var selection_callback := Callable(
		self,
		"_on_persistent_quick_spell_selection_changed"
	)
	if (
		GameState.has_signal("quick_spell_slot_changed")
		and not GameState.is_connected("quick_spell_slot_changed", slot_callback)
	):
		GameState.connect("quick_spell_slot_changed", slot_callback)
	if (
		GameState.has_signal("quick_spell_selection_changed")
		and not GameState.is_connected(
			"quick_spell_selection_changed",
			selection_callback
		)
	):
		GameState.connect("quick_spell_selection_changed", selection_callback)
	game_state_signals_connected = true


func _disconnect_game_state_signals() -> void:
	var slot_callback := Callable(self, "_on_persistent_quick_spell_slot_changed")
	var selection_callback := Callable(
		self,
		"_on_persistent_quick_spell_selection_changed"
	)
	if GameState.is_connected("quick_spell_slot_changed", slot_callback):
		GameState.disconnect("quick_spell_slot_changed", slot_callback)
	if GameState.is_connected("quick_spell_selection_changed", selection_callback):
		GameState.disconnect("quick_spell_selection_changed", selection_callback)
	game_state_signals_connected = false


func _current_quickbar_loadout_id() -> String:
	if router != null:
		var router_id: String = str(router.get("current_quickbar_loadout_id"))
		if router_id != "":
			return router_id
	if observed_loadout != null and observed_loadout.has_method(
		"get_quickbar_loadout_id"
	):
		return str(observed_loadout.call("get_quickbar_loadout_id"))
	return ""


func _on_equipped_spell_changed(
	_ability_name: String,
	_ability_index: int
) -> void:
	_mark_slots_dirty()


func _on_loadout_equipped_ability_changed(
	_slot_index: int,
	_ability: AbilityDefinition
) -> void:
	_mark_slots_dirty()


func _on_persistent_quick_spell_slot_changed(
	loadout_id: String,
	_slot_index: int,
	_spell_id: String
) -> void:
	if loadout_id == _current_quickbar_loadout_id():
		_mark_slots_dirty()


func _on_persistent_quick_spell_selection_changed(
	loadout_id: String,
	_slot_index: int
) -> void:
	if loadout_id == _current_quickbar_loadout_id():
		_mark_slots_dirty()


func _make_equipped_slot_style(
	equipped: bool,
	cursor_selected: bool,
	empty: bool
) -> StyleBoxFlat:
	if equipped:
		return _make_panel_style(
			Color(0.1, 0.052, 0.015, 0.99),
			Color(1.0, 0.62, 0.12, 1.0),
			9,
			3
		)
	if cursor_selected:
		return _make_panel_style(
			Color(0.018, 0.058, 0.1, 0.98),
			Color(0.32, 0.72, 1.0, 0.98),
			9,
			2
		)
	return _make_slot_style(false, empty)


func _update_fast_item_progress() -> void:
	if item_progress_bar == null:
		return
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
	progress = clampf(progress, 0.0, 1.0)
	if not is_equal_approx(progress, last_item_progress):
		last_item_progress = progress
		item_progress_bar.value = progress
		fast_item_writes += 1
	var menu_visible: bool = (
		(button_down or item_reveal_remaining > 0.0)
		and not focus_assignment_visible
	)
	if item_menu_panel != null and menu_visible != last_item_menu_visible:
		last_item_menu_visible = menu_visible
		item_menu_panel.visible = menu_visible


func _update_fast_special_visibility() -> void:
	var radial_now: bool = _is_special_radial_open()
	if radial_now != last_radial_state:
		last_radial_state = radial_now
		special_dirty = true
		static_refresh_remaining = 0.0
		_suppress_fullscreen_special_radial(radial_now)
	if special_menu_panel != null and special_menu_panel.visible != (
		radial_now and not focus_assignment_visible
	):
		special_menu_panel.visible = radial_now and not focus_assignment_visible


func _is_special_radial_open() -> bool:
	return divine_router != null and bool(divine_router.get("radial_open"))


func _get_viewport_width() -> float:
	if actor == null or actor.get_viewport() == null:
		return 0.0
	return actor.get_viewport().get_visible_rect().size.x


func _mark_slots_dirty(force_next_frame: bool = true) -> void:
	slots_dirty = true
	if force_next_frame:
		static_refresh_remaining = 0.0


func _mark_items_dirty(force_next_frame: bool = true) -> void:
	items_dirty = true
	if force_next_frame:
		static_refresh_remaining = 0.0


func _mark_special_dirty(force_next_frame: bool = true) -> void:
	special_dirty = true
	if force_next_frame:
		static_refresh_remaining = 0.0


func _on_quick_spell_activity(source: String, _slot_index: int) -> void:
	if source in ["keyboard", "assignment"]:
		reveal_remaining = reveal_seconds
	_mark_slots_dirty()


func _on_quick_spell_assigned(_slot_index: int, _spell_id: String) -> void:
	reveal_remaining = reveal_seconds
	_mark_slots_dirty()


func _on_quick_item_selection_changed(_slot_index: int) -> void:
	item_reveal_remaining = item_menu_reveal_seconds
	_mark_items_dirty()


func _on_quick_item_belt_changed() -> void:
	item_reveal_remaining = maxf(item_reveal_remaining, 0.45)
	_mark_items_dirty()


func _on_selected_special_changed(definition: DivineSpecialDefinition) -> void:
	cached_selected_special = definition
	_mark_special_dirty()


func _on_divine_charge_changed(
	current: float,
	maximum: float,
	_reason: String
) -> void:
	_apply_fast_special_charge(current, maximum)
	# The closed command tile only needs its numeric charge state. The four-row
	# radial menu is rebuilt at the throttled cadence only while it is open.
	if _is_special_radial_open():
		_mark_special_dirty(false)


func _refresh_special_presentation() -> void:
	if divine_controller != null:
		cached_selected_special = divine_controller.get_selected_special(
			OS.is_debug_build()
		)
	super._refresh_special_presentation()
	_capture_fast_special_state()


func _capture_fast_special_state() -> void:
	if special_charge_bar == null:
		return
	last_special_maximum = float(special_charge_bar.max_value)
	last_special_percent = roundi(
		float(special_charge_bar.value)
		/ maxf(last_special_maximum, 1.0)
		* 100.0
	)


func _apply_fast_special_charge(current: float, maximum: float) -> void:
	if special_charge_bar == null or special_charge_label == null:
		return
	var resolved_maximum: float = maxf(maximum, 1.0)
	var percent: int = roundi(clampf(current / resolved_maximum, 0.0, 1.0) * 100.0)
	if (
		percent == last_special_percent
		and is_equal_approx(resolved_maximum, last_special_maximum)
	):
		return
	last_special_percent = percent
	last_special_maximum = resolved_maximum
	special_charge_bar.max_value = resolved_maximum
	special_charge_bar.value = clampf(current, 0.0, resolved_maximum)
	var ready: bool = (
		cached_selected_special != null
		and current + 0.001 >= cached_selected_special.required_charge
	)
	special_charge_label.text = (
		str(percent)
		+ "%  •  "
		+ ("TAP ACTIVATE" if ready else "RECHARGING")
	)
	fast_special_writes += 1


func _make_panel_style(
	fill: Color,
	border: Color,
	radius: int,
	border_width: int
) -> StyleBoxFlat:
	var key: String = (
		fill.to_html(true)
		+ "|"
		+ border.to_html(true)
		+ "|"
		+ str(radius)
		+ "|"
		+ str(border_width)
	)
	if style_cache.has(key):
		return style_cache[key] as StyleBoxFlat
	var style: StyleBoxFlat = super._make_panel_style(
		fill,
		border,
		radius,
		border_width
	)
	style_cache[key] = style
	return style


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	var slot_glyphs: Array[String] = []
	for entry: Dictionary in slot_icon_entries:
		slot_glyphs.append(SpellIcons.get_glyph(entry))
	data["optimized"] = true
	data["process_frames"] = process_frames
	data["heavy_refreshes"] = heavy_refreshes
	data["style_cache_size"] = style_cache.size()
	data["static_refresh_interval"] = static_refresh_interval
	data["fallback_polling_enabled"] = fallback_polling_enabled
	data["fallback_poll_interval"] = fallback_poll_interval
	data["fallback_polls"] = fallback_poll_count
	data["event_driven_slots"] = loadout_signal_connected and game_state_signals_connected
	data["fast_item_writes"] = fast_item_writes
	data["fast_special_writes"] = fast_special_writes
	data["equipped_slot_indices"] = equipped_slot_indices.duplicate()
	data["cursor_slot_indices"] = cursor_slot_indices.duplicate()
	data["slot_icon_badge_count"] = slot_icon_badges.size()
	data["slot_icon_entries"] = slot_icon_entries.duplicate(true)
	data["slot_icon_glyphs"] = slot_glyphs
	data["focus_symbol_parity"] = true
	data["equipped_spell_name"] = equipped_spell_name
	data["equipped_spell_glyph"] = equipped_spell_glyph
	data["equipped_ability_index"] = (
		int(equipped_ability_caster.get("current_ability_index"))
		if equipped_ability_caster != null
		and is_instance_valid(equipped_ability_caster)
		else -1
	)
	data["authoritative_equipped_spell"] = true
	data["spell_icon_cache"] = SpellIcons.get_cache_debug_data()
	return data
