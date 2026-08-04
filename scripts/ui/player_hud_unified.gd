extends "res://scripts/ui/player_hud_v2.gd"
class_name PlayerHUDUnified

const SpellIcons = preload("res://scripts/ui/spell_icon_factory.gd")

signal hud_mode_changed(mode_id: String)
signal activity_published(source_id: String, kind: String)
signal context_changed(source_id: String)

const MAX_ACTIVITY_TOASTS: int = 3
const MAX_ACTIVE_ABILITIES: int = 3
const DEFAULT_ACTIVITY_DURATION: float = 3.0

const ACTIVITY_COLORS: Dictionary = {
	"challenge": Color(1.0, 0.72, 0.2),
	"discovery": Color(0.28, 0.82, 1.0),
	"achievement": Color(0.82, 0.52, 1.0),
	"mastery": Color(0.36, 0.94, 0.58),
	"quest": Color(1.0, 0.84, 0.36),
	"creature": Color(0.4, 0.92, 0.74),
	"unlock": Color(1.0, 0.54, 0.16),
	"level": Color(1.0, 0.76, 0.22),
	"tracked": Color(0.38, 0.68, 1.0),
	"system": Color(0.58, 0.76, 1.0),
	"interaction": Color(0.34, 0.9, 1.0),
}

var status_zone: Control
var mode_zone: Control
var activity_zone: Control
var action_bar_zone: Control
var support_zone: Control
var context_zone: Control

var mode_panel: PanelContainer
var mode_eyebrow_label: Label
var mode_title_label: Label
var mode_detail_label: Label

var activity_rail: VBoxContainer
var tracked_activity_panel: PanelContainer
var tracked_activity_header: Label
var tracked_activity_title: Label
var tracked_activity_detail: Label
var tracked_activity_progress: ProgressBar
var tracked_activity_progress_label: Label
var activity_toast_stack: VBoxContainer

var context_panel: PanelContainer
var context_eyebrow_label: Label
var context_title_label: Label
var context_detail_label: Label
var context_controls_label: Label

var support_panel: PanelContainer
var support_status_label: Label
var active_ability_stack: VBoxContainer

var objective_text: String = ""
var objective_detail: String = ""
var mode_requests: Dictionary = {}
var context_requests: Dictionary = {}
var activity_entries: Array[Dictionary] = []
var tracked_activity: Dictionary = {}
var active_ability_entries: Array[Dictionary] = []
var active_ability_highlighted_id: String = ""
var current_mode_id: String = "exploration"
var last_layout_width: float = -1.0
var shell_refresh_count: int = 0


func _build_hud() -> void:
	super._build_hud()
	_build_layout_zones()
	_restyle_core_hud()
	_build_mode_banner()
	_build_activity_rail()
	_build_context_strip()
	_build_support_cluster()


func _ready() -> void:
	super._ready()
	add_to_group("unified_hud_shell")
	add_to_group("hud_layout_authority")
	call_deferred("_finish_unified_setup")


func _finish_unified_setup() -> void:
	_restyle_core_hud()
	_update_unified_shell(0.0)


func _process(delta: float) -> void:
	super._process(delta)
	_update_unified_shell(maxf(delta, 0.0))


func refresh_data(force: bool = false) -> void:
	super.refresh_data(force)
	_refresh_support_status()


func _collect_status_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = super._collect_status_rows()
	var filtered: Array[Dictionary] = []
	for row: Dictionary in rows:
		if str(row.get("id", "")) == "divine_ready":
			continue
		filtered.append(row)
	return filtered


func get_hud_zone(zone_id: String) -> Control:
	match zone_id.strip_edges().to_lower():
		"status", "status_cluster", "top_left":
			return status_zone
		"mode", "mode_banner", "top_center":
			return mode_zone
		"activity", "activity_rail", "top_right":
			return activity_zone
		"action", "action_bar", "bottom_center":
			return action_bar_zone
		"support", "support_cluster", "bottom_right":
			return support_zone
		"context", "context_strip":
			return context_zone
		_:
			return root


func get_hud_mode() -> String:
	return current_mode_id


func set_objective_summary(title: String, detail: String = "") -> void:
	objective_text = title.strip_edges()
	objective_detail = detail.strip_edges()
	_refresh_mode_banner()


func publish_mode(
	source_id: String,
	data: Dictionary,
	priority: int = 50
) -> void:
	var normalized: String = _normalize_source_id(source_id)
	if normalized == "":
		return
	var request: Dictionary = data.duplicate(true)
	request["source_id"] = normalized
	request["priority"] = priority
	request["sequence"] = Time.get_ticks_msec()
	mode_requests[normalized] = request
	_refresh_mode_banner()


func clear_mode(source_id: String) -> void:
	var normalized: String = _normalize_source_id(source_id)
	mode_requests.erase(normalized)
	_refresh_mode_banner()


func publish_context(
	source_id: String,
	data: Dictionary,
	priority: int = 50,
	duration_seconds: float = 0.0
) -> void:
	var normalized: String = _normalize_source_id(source_id)
	if normalized == "":
		return
	var request: Dictionary = data.duplicate(true)
	request["source_id"] = normalized
	request["priority"] = priority
	request["sequence"] = Time.get_ticks_msec()
	request["expires_msec"] = (
		Time.get_ticks_msec() + int(duration_seconds * 1000.0)
		if duration_seconds > 0.0
		else 0
	)
	context_requests[normalized] = request
	_refresh_context_strip()
	context_changed.emit(normalized)


func clear_context(source_id: String) -> void:
	var normalized: String = _normalize_source_id(source_id)
	context_requests.erase(normalized)
	_refresh_context_strip()
	context_changed.emit(normalized)


func publish_activity(
	kind: String,
	title: String,
	body: String = "",
	duration_seconds: float = DEFAULT_ACTIVITY_DURATION,
	source_id: String = "",
	priority: int = 50,
	major: bool = false,
	current: int = -1,
	target: int = -1
) -> void:
	var resolved_title: String = title.strip_edges()
	if resolved_title == "":
		return
	var resolved_kind: String = kind.strip_edges().to_lower()
	if resolved_kind == "":
		resolved_kind = "system"
	var resolved_source: String = _normalize_source_id(source_id)
	if resolved_source == "":
		resolved_source = (
			resolved_kind
			+ ":"
			+ resolved_title.to_lower().replace(" ", "_")
		)
	for index: int in range(activity_entries.size()):
		if str(activity_entries[index].get("source_id", "")) != resolved_source:
			continue
		activity_entries[index] = _make_activity_data(
			resolved_kind,
			resolved_title,
			body,
			duration_seconds,
			resolved_source,
			priority,
			major,
			current,
			target
		)
		_rebuild_activity_toasts()
		activity_published.emit(resolved_source, resolved_kind)
		return
	activity_entries.push_front(_make_activity_data(
		resolved_kind,
		resolved_title,
		body,
		duration_seconds,
		resolved_source,
		priority,
		major,
		current,
		target
	))
	while activity_entries.size() > MAX_ACTIVITY_TOASTS:
		activity_entries.pop_back()
	_rebuild_activity_toasts()
	activity_published.emit(resolved_source, resolved_kind)


func clear_activity(source_id: String) -> void:
	var normalized: String = _normalize_source_id(source_id)
	for index: int in range(activity_entries.size() - 1, -1, -1):
		if str(activity_entries[index].get("source_id", "")) == normalized:
			activity_entries.remove_at(index)
	_rebuild_activity_toasts()


func set_tracked_activity(data: Dictionary) -> void:
	tracked_activity = data.duplicate(true)
	_refresh_tracked_activity()


func set_active_ability_entries(
	entries: Array[Dictionary],
	highlighted_id: String = ""
) -> void:
	active_ability_entries = entries.duplicate(true)
	active_ability_highlighted_id = highlighted_id
	_rebuild_active_ability_rows()


func _build_layout_zones() -> void:
	status_zone = _make_zone("StatusClusterZone")
	mode_zone = _make_zone("ModeBannerZone")
	activity_zone = _make_zone("ActivityRailZone")
	action_bar_zone = _make_zone("ActionBarZone")
	support_zone = _make_zone("SupportClusterZone")
	context_zone = _make_zone("ContextStripZone")
	for zone: Control in [
		status_zone,
		mode_zone,
		activity_zone,
		action_bar_zone,
		support_zone,
		context_zone,
	]:
		root.add_child(zone)


func _make_zone(zone_name: String) -> Control:
	var zone := Control.new()
	zone.name = zone_name
	zone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return zone


func _restyle_core_hud() -> void:
	if stats_panel != null:
		stats_panel.offset_left = 18.0
		stats_panel.offset_top = 18.0
		stats_panel.offset_right = 374.0
		stats_panel.offset_bottom = 174.0
		stats_panel.add_theme_stylebox_override(
			"panel",
			_make_shell_style(
				Color(0.008, 0.014, 0.025, 0.93),
				Color(0.94, 0.62, 0.2, 0.68),
				14,
				2
			)
		)
	if avatar_title_label != null:
		avatar_title_label.add_theme_font_size_override("font_size", 13)
	if loadout_label != null:
		loadout_label.visible = false
	if base_stats_label != null:
		base_stats_label.visible = false
	if quick_panel != null:
		quick_panel.modulate.a = 0.0
		quick_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if status_stack != null:
		status_stack.visible = false
	var old_portrait_shell: Node = root.find_child(
		"GracePortraitShell",
		true,
		false
	)
	if old_portrait_shell is Control:
		(old_portrait_shell as Control).visible = false
	if dialogue_panel != null:
		dialogue_panel.anchor_left = 0.5
		dialogue_panel.anchor_top = 1.0
		dialogue_panel.anchor_right = 0.5
		dialogue_panel.anchor_bottom = 1.0
		dialogue_panel.offset_left = -520.0
		dialogue_panel.offset_top = -290.0
		dialogue_panel.offset_right = 520.0
		dialogue_panel.offset_bottom = -30.0


func _build_mode_banner() -> void:
	mode_panel = PanelContainer.new()
	mode_panel.name = "UnifiedModeBanner"
	mode_panel.anchor_left = 0.5
	mode_panel.anchor_right = 0.5
	mode_panel.offset_left = -330.0
	mode_panel.offset_top = 18.0
	mode_panel.offset_right = 330.0
	mode_panel.offset_bottom = 91.0
	mode_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode_panel.visible = false
	mode_panel.add_to_group("menu_suppressed_hud")
	mode_panel.add_theme_stylebox_override(
		"panel",
		_make_shell_style(
			Color(0.006, 0.012, 0.023, 0.88),
			Color(0.34, 0.58, 0.9, 0.48),
			15,
			1
		)
	)
	mode_zone.add_child(mode_panel)
	var margin := _make_margin(14, 7, 14, 7)
	mode_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 0)
	margin.add_child(stack)
	mode_eyebrow_label = _make_label(9, Color(0.52, 0.72, 0.96), HORIZONTAL_ALIGNMENT_CENTER)
	stack.add_child(mode_eyebrow_label)
	mode_title_label = _make_label(17, Color(0.94, 0.97, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	mode_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack.add_child(mode_title_label)
	mode_detail_label = _make_label(9, Color(0.6, 0.7, 0.84), HORIZONTAL_ALIGNMENT_CENTER)
	mode_detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack.add_child(mode_detail_label)


func _build_activity_rail() -> void:
	activity_rail = VBoxContainer.new()
	activity_rail.name = "UnifiedActivityRail"
	activity_rail.anchor_left = 1.0
	activity_rail.anchor_right = 1.0
	activity_rail.offset_left = -382.0
	activity_rail.offset_top = 20.0
	activity_rail.offset_right = -20.0
	activity_rail.offset_bottom = 610.0
	activity_rail.add_theme_constant_override("separation", 7)
	activity_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	activity_zone.add_child(activity_rail)

	tracked_activity_panel = PanelContainer.new()
	tracked_activity_panel.name = "UnifiedTrackedActivity"
	tracked_activity_panel.visible = false
	tracked_activity_panel.add_theme_stylebox_override(
		"panel",
		_make_shell_style(
			Color(0.008, 0.018, 0.032, 0.94),
			Color(0.34, 0.68, 1.0, 0.74),
			13,
			2
		)
	)
	activity_rail.add_child(tracked_activity_panel)
	var tracked_margin := _make_margin(13, 9, 13, 9)
	tracked_activity_panel.add_child(tracked_margin)
	var tracked_stack := VBoxContainer.new()
	tracked_stack.add_theme_constant_override("separation", 2)
	tracked_margin.add_child(tracked_stack)
	tracked_activity_header = _make_label(8, Color(0.48, 0.74, 1.0))
	tracked_stack.add_child(tracked_activity_header)
	tracked_activity_title = _make_label(14, Color(0.94, 0.97, 1.0))
	tracked_activity_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tracked_stack.add_child(tracked_activity_title)
	tracked_activity_detail = _make_label(9, Color(0.64, 0.74, 0.88))
	tracked_activity_detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tracked_stack.add_child(tracked_activity_detail)
	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 8)
	tracked_stack.add_child(progress_row)
	tracked_activity_progress = ProgressBar.new()
	tracked_activity_progress.show_percentage = false
	tracked_activity_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tracked_activity_progress.custom_minimum_size = Vector2(0.0, 7.0)
	tracked_activity_progress.add_theme_stylebox_override(
		"background",
		_make_bar_style(Color(0.035, 0.05, 0.074), 4)
	)
	tracked_activity_progress.add_theme_stylebox_override(
		"fill",
		_make_bar_style(Color(0.26, 0.66, 1.0), 4)
	)
	progress_row.add_child(tracked_activity_progress)
	tracked_activity_progress_label = _make_label(9, Color(0.82, 0.9, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)
	tracked_activity_progress_label.custom_minimum_size = Vector2(52.0, 0.0)
	progress_row.add_child(tracked_activity_progress_label)

	activity_toast_stack = VBoxContainer.new()
	activity_toast_stack.name = "UnifiedActivityToasts"
	activity_toast_stack.add_theme_constant_override("separation", 7)
	activity_rail.add_child(activity_toast_stack)


func _build_context_strip() -> void:
	context_panel = PanelContainer.new()
	context_panel.name = "UnifiedContextStrip"
	context_panel.anchor_left = 0.5
	context_panel.anchor_top = 1.0
	context_panel.anchor_right = 0.5
	context_panel.anchor_bottom = 1.0
	context_panel.offset_left = -500.0
	context_panel.offset_top = -190.0
	context_panel.offset_right = 500.0
	context_panel.offset_bottom = -138.0
	context_panel.visible = false
	context_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	context_panel.add_to_group("menu_suppressed_hud")
	context_panel.add_theme_stylebox_override(
		"panel",
		_make_shell_style(
			Color(0.006, 0.014, 0.026, 0.94),
			Color(0.34, 0.76, 0.96, 0.76),
			13,
			2
		)
	)
	context_zone.add_child(context_panel)
	var margin := _make_margin(13, 5, 13, 5)
	context_panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	context_eyebrow_label = _make_label(8, Color(0.46, 0.82, 1.0))
	context_eyebrow_label.custom_minimum_size = Vector2(108.0, 0.0)
	context_eyebrow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(context_eyebrow_label)
	var copy_stack := VBoxContainer.new()
	copy_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy_stack.add_theme_constant_override("separation", 0)
	row.add_child(copy_stack)
	context_title_label = _make_label(13, Color(0.94, 0.98, 1.0))
	context_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy_stack.add_child(context_title_label)
	context_detail_label = _make_label(9, Color(0.62, 0.74, 0.86))
	context_detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy_stack.add_child(context_detail_label)
	context_controls_label = _make_label(9, Color(0.72, 0.84, 0.96), HORIZONTAL_ALIGNMENT_RIGHT)
	context_controls_label.custom_minimum_size = Vector2(310.0, 0.0)
	context_controls_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	context_controls_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(context_controls_label)


func _build_support_cluster() -> void:
	support_panel = PanelContainer.new()
	support_panel.name = "UnifiedSupportCluster"
	support_panel.anchor_left = 1.0
	support_panel.anchor_top = 1.0
	support_panel.anchor_right = 1.0
	support_panel.anchor_bottom = 1.0
	support_panel.offset_left = -300.0
	support_panel.offset_top = -218.0
	support_panel.offset_right = -18.0
	support_panel.offset_bottom = -18.0
	support_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	support_panel.add_to_group("menu_suppressed_hud")
	support_panel.add_theme_stylebox_override(
		"panel",
		_make_shell_style(
			Color(0.007, 0.014, 0.025, 0.94),
			Color(0.82, 0.58, 0.24, 0.62),
			16,
			2
		)
	)
	support_zone.add_child(support_panel)
	var margin := _make_margin(10, 9, 10, 9)
	support_panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	margin.add_child(row)

	portrait = PortraitMedallionScript.new()
	portrait.name = "UnifiedGracePortrait"
	portrait.custom_minimum_size = Vector2(92.0, 92.0)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(portrait)

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 2)
	row.add_child(stack)
	var identity_row := HBoxContainer.new()
	stack.add_child(identity_row)
	portrait_name_label = _make_label(10, Color(1.0, 0.76, 0.3))
	portrait_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_row.add_child(portrait_name_label)
	portrait_state_label = _make_label(8, Color(0.64, 0.76, 0.92), HORIZONTAL_ALIGNMENT_RIGHT)
	identity_row.add_child(portrait_state_label)
	active_ability_stack = VBoxContainer.new()
	active_ability_stack.add_theme_constant_override("separation", 3)
	active_ability_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(active_ability_stack)
	support_status_label = _make_label(8, Color(0.66, 0.76, 0.88))
	support_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack.add_child(support_status_label)
	_rebuild_active_ability_rows()


func _update_unified_shell(delta: float) -> void:
	shell_refresh_count += 1
	_expire_context_requests()
	_update_activity_entries(delta)
	_update_layout_for_viewport()
	var next_mode: String = _resolve_runtime_mode()
	if next_mode != current_mode_id:
		current_mode_id = next_mode
		hud_mode_changed.emit(current_mode_id)
	_update_zone_visibility()
	_refresh_mode_banner()
	_refresh_context_strip()
	_refresh_support_status()


func _resolve_runtime_mode() -> String:
	if dialogue_panel != null and dialogue_panel.visible:
		return "dialogue"
	if _focus_library_open():
		return "focus"
	if _ability_context_modal_open():
		return "ability_context"
	if actor != null and bool(actor.get_meta("shared_placement_active", false)):
		return "placement"
	return "exploration"


func _update_zone_visibility() -> void:
	var focus_or_modal: bool = current_mode_id in ["focus", "ability_context"]
	var dialogue: bool = current_mode_id == "dialogue"
	var placement: bool = current_mode_id == "placement"
	if stats_panel != null:
		stats_panel.visible = not dialogue
		stats_panel.modulate.a = 0.48 if focus_or_modal else 1.0
	mode_zone.visible = not dialogue and not focus_or_modal
	activity_zone.visible = not dialogue and not focus_or_modal and not placement
	context_zone.visible = not dialogue and not focus_or_modal
	support_zone.visible = not dialogue and not focus_or_modal and not placement
	action_bar_zone.visible = not dialogue
	action_bar_zone.modulate.a = 0.38 if placement else (0.58 if focus_or_modal else 1.0)


func _refresh_mode_banner() -> void:
	if mode_panel == null:
		return
	var request: Dictionary = _highest_priority_request(mode_requests)
	if request.is_empty() and objective_text != "":
		request = {
			"eyebrow": "CURRENT OBJECTIVE",
			"title": objective_text,
			"detail": objective_detail,
			"accent": Color(0.42, 0.72, 1.0),
		}
	mode_panel.visible = not request.is_empty()
	if request.is_empty():
		return
	var accent: Color = _resolve_color(request.get("accent", Color(0.42, 0.72, 1.0)))
	mode_eyebrow_label.text = str(request.get("eyebrow", "MODE")).to_upper()
	mode_eyebrow_label.add_theme_color_override("font_color", accent)
	mode_title_label.text = str(request.get("title", ""))
	mode_detail_label.text = str(request.get("detail", request.get("state", "")))
	mode_detail_label.visible = mode_detail_label.text != ""
	mode_panel.add_theme_stylebox_override(
		"panel",
		_make_shell_style(
			Color(accent.r * 0.025, accent.g * 0.025, accent.b * 0.025, 0.9),
			Color(accent.r, accent.g, accent.b, 0.64),
			15,
			2
		)
	)


func _refresh_context_strip() -> void:
	if context_panel == null:
		return
	var request: Dictionary = _highest_priority_request(context_requests)
	context_panel.visible = not request.is_empty()
	if request.is_empty():
		return
	var valid: bool = bool(request.get("valid", true))
	var accent: Color = _resolve_color(request.get(
		"accent",
		Color(0.34, 0.9, 1.0) if valid else Color(1.0, 0.42, 0.3)
	))
	context_eyebrow_label.text = str(request.get("eyebrow", "CONTEXT")).to_upper()
	context_eyebrow_label.add_theme_color_override("font_color", accent)
	context_title_label.text = str(request.get("title", ""))
	context_detail_label.text = str(request.get("detail", request.get("state", "")))
	context_controls_label.text = str(request.get("controls", request.get("hint", "")))
	context_panel.add_theme_stylebox_override(
		"panel",
		_make_shell_style(
			Color(accent.r * 0.025, accent.g * 0.025, accent.b * 0.025, 0.95),
			Color(accent.r, accent.g, accent.b, 0.78),
			13,
			2
		)
	)


func _refresh_tracked_activity() -> void:
	if tracked_activity_panel == null:
		return
	tracked_activity_panel.visible = not tracked_activity.is_empty()
	if tracked_activity.is_empty():
		return
	var kind: String = str(tracked_activity.get("kind", "tracked"))
	var current: int = int(tracked_activity.get("current", -1))
	var target: int = int(tracked_activity.get("target", -1))
	tracked_activity_header.text = (
		("COMPLETE  •  " if bool(tracked_activity.get("complete", false)) else "TRACKED  •  ")
		+ kind.replace("_", " ").to_upper()
	)
	tracked_activity_title.text = str(tracked_activity.get(
		"title",
		tracked_activity.get("name", "Tracked Progress")
	))
	tracked_activity_detail.text = str(tracked_activity.get(
		"detail",
		tracked_activity.get("objective", tracked_activity.get("requirement", ""))
	))
	var has_progress: bool = current >= 0 and target > 0
	tracked_activity_progress.visible = has_progress
	tracked_activity_progress_label.visible = has_progress
	if has_progress:
		tracked_activity_progress.max_value = maxi(target, 1)
		tracked_activity_progress.value = clampi(current, 0, maxi(target, 1))
		tracked_activity_progress_label.text = str(current) + " / " + str(target)


func _rebuild_activity_toasts() -> void:
	if activity_toast_stack == null:
		return
	_clear_children(activity_toast_stack)
	for entry: Dictionary in activity_entries:
		activity_toast_stack.add_child(_make_activity_card(entry))


func _make_activity_card(entry: Dictionary) -> PanelContainer:
	var kind: String = str(entry.get("kind", "system"))
	var color: Color = _activity_color(kind)
	var major: bool = bool(entry.get("major", false))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0.0, 64.0 if not major else 78.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override(
		"panel",
		_make_shell_style(
			Color(color.r * 0.045, color.g * 0.045, color.b * 0.045, 0.95),
			Color(color.r, color.g, color.b, 0.9 if major else 0.64),
			12,
			2 if major else 1
		)
	)
	var margin := _make_margin(12, 7, 12, 7)
	card.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 1)
	margin.add_child(stack)
	var header := _make_label(8, color)
	header.text = kind.replace("_", " ").to_upper()
	stack.add_child(header)
	var title := _make_label(13 if not major else 15, Color(0.95, 0.98, 1.0))
	title.text = str(entry.get("title", "Update"))
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack.add_child(title)
	var body := _make_label(9, Color(0.64, 0.74, 0.86))
	body.text = str(entry.get("body", ""))
	body.visible = body.text != ""
	body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack.add_child(body)
	var current: int = int(entry.get("current", -1))
	var target: int = int(entry.get("target", -1))
	if current >= 0 and target > 0:
		var progress := ProgressBar.new()
		progress.show_percentage = true
		progress.max_value = maxi(target, 1)
		progress.value = clampi(current, 0, maxi(target, 1))
		progress.custom_minimum_size = Vector2(0.0, 7.0)
		progress.add_theme_font_size_override("font_size", 8)
		progress.add_theme_stylebox_override("background", _make_bar_style(Color(0.03, 0.04, 0.06), 4))
		progress.add_theme_stylebox_override("fill", _make_bar_style(color, 4))
		stack.add_child(progress)
	card.modulate.a = float(entry.get("alpha", 1.0))
	return card


func _update_activity_entries(delta: float) -> void:
	var changed: bool = false
	for index: int in range(activity_entries.size() - 1, -1, -1):
		var entry: Dictionary = activity_entries[index]
		var remaining: float = float(entry.get("remaining", DEFAULT_ACTIVITY_DURATION)) - delta
		entry["remaining"] = remaining
		var duration: float = maxf(float(entry.get("duration", DEFAULT_ACTIVITY_DURATION)), 0.1)
		entry["alpha"] = clampf(remaining / minf(duration, 0.45), 0.0, 1.0) if remaining < 0.45 else 1.0
		activity_entries[index] = entry
		if remaining <= 0.0:
			activity_entries.remove_at(index)
			changed = true
		elif remaining < 0.45:
			changed = true
	if changed:
		_rebuild_activity_toasts()


func _rebuild_active_ability_rows() -> void:
	if active_ability_stack == null:
		return
	_clear_children(active_ability_stack)
	if active_ability_entries.is_empty():
		var empty := _make_label(8, Color(0.52, 0.62, 0.76))
		empty.text = "No persistent abilities active"
		active_ability_stack.add_child(empty)
		return
	for index: int in range(mini(active_ability_entries.size(), MAX_ACTIVE_ABILITIES)):
		active_ability_stack.add_child(_make_active_ability_row(active_ability_entries[index]))


func _make_active_ability_row(entry: Dictionary) -> PanelContainer:
	var entry_id: String = str(entry.get("id", ""))
	var highlighted: bool = entry_id == active_ability_highlighted_id or bool(entry.get("highlighted", false))
	var attention: bool = bool(entry.get("attention", false))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0.0, 30.0)
	card.add_theme_stylebox_override(
		"panel",
		_make_shell_style(
			Color(0.075, 0.04, 0.012, 0.96) if highlighted else Color(0.012, 0.024, 0.042, 0.88),
			Color(1.0, 0.58, 0.12, 0.96) if highlighted else (Color(1.0, 0.34, 0.22, 0.88) if attention else Color(0.26, 0.46, 0.7, 0.56)),
			8,
			2 if highlighted or attention else 1
		)
	)
	var margin := _make_margin(5, 2, 6, 2)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	margin.add_child(row)
	var icon_entry: Dictionary = {
		"name": str(entry.get("label", "Active")),
		"spell_id": str(entry.get("spell_id", "")),
		"element": str(entry.get("element", "neutral")),
		"icon_text": str(entry.get("icon_text", "")),
		"icon_path": str(entry.get("icon_path", "")),
	}
	row.add_child(SpellIcons.create_badge(icon_entry, 23.0, highlighted, highlighted))
	var label := _make_label(9, Color(1.0, 0.78, 0.3) if highlighted else Color(0.88, 0.94, 1.0))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = str(entry.get("label", "Active"))
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(label)
	var state := _make_label(8, Color(1.0, 0.46, 0.32) if attention else Color(0.56, 0.7, 0.84), HORIZONTAL_ALIGNMENT_RIGHT)
	state.text = str(entry.get("state", "Active"))
	state.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	state.custom_minimum_size = Vector2(76.0, 0.0)
	row.add_child(state)
	return card


func _refresh_support_status() -> void:
	if support_status_label == null:
		return
	var rows: Array[Dictionary] = _collect_status_rows()
	if rows.is_empty():
		support_status_label.text = "READY"
		return
	var copy: Array[String] = []
	for index: int in range(mini(rows.size(), 2)):
		var row: Dictionary = rows[index]
		copy.append(
			_status_icon(str(row.get("id", "effect")))
			+ " "
			+ str(row.get("name", "Effect"))
		)
	support_status_label.text = "  •  ".join(copy)


func _update_layout_for_viewport() -> void:
	if get_viewport() == null:
		return
	var width: float = get_viewport().get_visible_rect().size.x
	if is_equal_approx(width, last_layout_width):
		return
	last_layout_width = width
	var scale_value: float = clampf((width - 260.0) / 1400.0, 0.72, 1.0)
	for panel: Control in [mode_panel, context_panel, support_panel]:
		if panel != null:
			panel.scale = Vector2.ONE * scale_value
			panel.pivot_offset = panel.size * 0.5
	if activity_rail != null:
		activity_rail.scale = Vector2.ONE * scale_value
		activity_rail.pivot_offset = Vector2(activity_rail.size.x, 0.0)


func _focus_library_open() -> bool:
	return (
		ability_caster != null
		and is_instance_valid(ability_caster)
		and ability_caster.has_method("is_focus_library_open")
		and bool(ability_caster.call("is_focus_library_open"))
	)


func _ability_context_modal_open() -> bool:
	if actor == null:
		return false
	var menu: Node = actor.get_node_or_null("AbilityContextMenu")
	return (
		menu != null
		and menu.has_method("is_modal_active")
		and bool(menu.call("is_modal_active"))
	)


func _expire_context_requests() -> void:
	var now: int = Time.get_ticks_msec()
	var expired: Array[String] = []
	for source_value: Variant in context_requests.keys():
		var source_id: String = str(source_value)
		var request: Dictionary = context_requests[source_id] as Dictionary
		var expires: int = int(request.get("expires_msec", 0))
		if expires > 0 and now > expires:
			expired.append(source_id)
	for source_id: String in expired:
		context_requests.erase(source_id)


func _highest_priority_request(requests: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_priority: int = -2147483648
	var best_sequence: int = -1
	for raw: Variant in requests.values():
		if not raw is Dictionary:
			continue
		var request: Dictionary = raw as Dictionary
		var priority: int = int(request.get("priority", 0))
		var sequence: int = int(request.get("sequence", 0))
		if priority > best_priority or (priority == best_priority and sequence > best_sequence):
			best = request
			best_priority = priority
			best_sequence = sequence
	return best


func _make_activity_data(
	kind: String,
	title: String,
	body: String,
	duration_seconds: float,
	source_id: String,
	priority: int,
	major: bool,
	current: int,
	target: int
) -> Dictionary:
	var duration: float = maxf(duration_seconds, 0.25)
	return {
		"kind": kind,
		"title": title,
		"body": body.strip_edges(),
		"duration": duration,
		"remaining": duration,
		"alpha": 1.0,
		"source_id": source_id,
		"priority": priority,
		"major": major,
		"current": current,
		"target": target,
	}


func _activity_color(kind: String) -> Color:
	return ACTIVITY_COLORS.get(kind, ACTIVITY_COLORS["system"]) as Color


func _resolve_color(value: Variant) -> Color:
	if value is Color:
		return value as Color
	var kind: String = str(value).to_lower()
	return _activity_color(kind)


func _normalize_source_id(source_id: String) -> String:
	return source_id.strip_edges().to_lower().replace(" ", "_")


func _make_margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _make_label(
	font_size: int,
	color: Color,
	alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	var label := Label.new()
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_shell_style(
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


func _clear_children(parent: Node) -> void:
	if parent == null:
		return
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func get_unified_hud_debug_data() -> Dictionary:
	return {
		"mode": current_mode_id,
		"mode_requests": mode_requests.size(),
		"context_requests": context_requests.size(),
		"activity_count": activity_entries.size(),
		"tracked_activity": not tracked_activity.is_empty(),
		"active_ability_count": active_ability_entries.size(),
		"highlighted_ability": active_ability_highlighted_id,
		"zones": {
			"status": status_zone != null,
			"mode": mode_zone != null,
			"activity": activity_zone != null,
			"action": action_bar_zone != null,
			"support": support_zone != null,
			"context": context_zone != null,
		},
		"shell_refresh_count": shell_refresh_count,
	}


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["unified_shell"] = get_unified_hud_debug_data()
	return data
