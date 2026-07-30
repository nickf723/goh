extends "res://scripts/ui/quick_spell_belt_presentation.gd"
class_name QuickSpellBeltPerformance


@export_range(0.05, 0.3, 0.01) var static_refresh_interval: float = 0.1
@export_range(0.25, 2.0, 0.05) var fallback_poll_interval: float = 0.55

var static_refresh_remaining: float = 0.0
var fallback_poll_remaining: float = 0.0
var slots_dirty: bool = false
var items_dirty: bool = false
var special_dirty: bool = false
var last_focus_state: bool = false
var last_radial_state: bool = false
var last_viewport_width: float = -1.0
var style_cache: Dictionary = {}
var process_frames: int = 0
var heavy_refreshes: int = 0


func _finish_setup() -> void:
	super._finish_setup()
	if not setup_complete:
		return
	_update_responsive_scale()
	_align_focus_panel()
	last_focus_state = focus_assignment_visible
	last_radial_state = _is_special_radial_open()
	last_viewport_width = _get_viewport_width()
	static_refresh_remaining = static_refresh_interval
	fallback_poll_remaining = fallback_poll_interval
	slots_dirty = false
	items_dirty = false
	special_dirty = false


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

	fallback_poll_remaining -= step
	if fallback_poll_remaining <= 0.0:
		fallback_poll_remaining = fallback_poll_interval
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
		dock_panel.visible = true
		dock_panel.modulate.a = 0.84 if focus_assignment_visible else 1.0


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
	item_progress_bar.value = clampf(progress, 0.0, 1.0)
	if item_menu_panel != null:
		item_menu_panel.visible = (
			(button_down or item_reveal_remaining > 0.0)
			and not focus_assignment_visible
		)


func _update_fast_special_visibility() -> void:
	var radial_now: bool = _is_special_radial_open()
	if radial_now != last_radial_state:
		last_radial_state = radial_now
		special_dirty = true
		static_refresh_remaining = 0.0
		_suppress_fullscreen_special_radial(radial_now)
	if special_menu_panel != null:
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


func _on_selected_special_changed(_definition: DivineSpecialDefinition) -> void:
	_mark_special_dirty()


func _on_divine_charge_changed(
	_current: float,
	_maximum: float,
	_reason: String
) -> void:
	# Passive charge can emit every frame. Mark the snapshot dirty, but let the
	# throttled refresh cadence coalesce those emissions into one UI update.
	_mark_special_dirty(false)


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
	data["optimized"] = true
	data["process_frames"] = process_frames
	data["heavy_refreshes"] = heavy_refreshes
	data["style_cache_size"] = style_cache.size()
	data["static_refresh_interval"] = static_refresh_interval
	return data
