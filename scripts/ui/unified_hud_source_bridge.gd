extends Node
class_name UnifiedHUDSourceBridge

var unified_hud: Node
var progression_hud: Node
var mirrored_activity_signatures: Dictionary = {}
var mirrored_sources: Array[String] = []
var sync_count: int = 0
var last_layout_width: float = -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Run after player-owned HUD presenters so this bridge is the final authority
	# on cross-surface geometry for the current frame.
	process_priority = 1000
	add_to_group("unified_hud_source_bridge")
	add_to_group("debuggable")


func _process(_delta: float) -> void:
	_resolve_unified_hud()
	if unified_hud == null:
		return
	_apply_responsive_layout()
	_suppress_duplicate_special_surface()
	_sync_progression_feedback()


func _resolve_unified_hud() -> void:
	if unified_hud != null and is_instance_valid(unified_hud):
		return
	unified_hud = get_tree().get_first_node_in_group("unified_hud_shell")
	# A newly resolved HUD needs one guaranteed geometry pass even when the
	# viewport width matches the previous scene.
	last_layout_width = -1.0


func _apply_responsive_layout() -> void:
	if get_viewport() == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var width: float = viewport_size.x
	var compact: bool = width < 900.0
	var narrow: bool = width < 1500.0
	var width_changed: bool = not is_equal_approx(width, last_layout_width)
	last_layout_width = width

	var stats_value: Variant = unified_hud.get("stats_panel")
	if stats_value is Control:
		var stats_panel: Control = stats_value as Control
		stats_panel.scale = Vector2.ONE
		stats_panel.pivot_offset = Vector2.ZERO
		stats_panel.offset_left = 12.0 if compact else 18.0
		stats_panel.offset_top = 12.0 if compact else 18.0
		stats_panel.offset_right = (
			minf(272.0, width * 0.43)
			if compact
			else (340.0 if narrow else 374.0)
		)
		stats_panel.offset_bottom = 166.0 if compact else 174.0

	var mode_value: Variant = unified_hud.get("mode_panel")
	if mode_value is Control:
		var mode_panel: Control = mode_value as Control
		mode_panel.scale = Vector2.ONE
		mode_panel.pivot_offset = Vector2.ZERO
		var half_width: float = (
			minf(180.0, maxf(width * 0.5 - 24.0, 120.0))
			if compact
			else (150.0 if narrow else 250.0)
		)
		mode_panel.offset_left = -half_width
		mode_panel.offset_right = half_width
		mode_panel.offset_top = 178.0 if compact else 18.0
		mode_panel.offset_bottom = 251.0 if compact else 91.0

	var activity_value: Variant = unified_hud.get("activity_rail")
	if activity_value is Control:
		var activity_rail: Control = activity_value as Control
		activity_rail.scale = Vector2.ONE
		activity_rail.pivot_offset = Vector2.ZERO
		activity_rail.offset_left = (
			-maxf(minf(252.0, width * 0.39), 180.0)
			if compact
			else (-340.0 if narrow else -382.0)
		)
		activity_rail.offset_right = -12.0 if compact else -20.0
		activity_rail.offset_top = 12.0 if compact else 20.0
		activity_rail.offset_bottom = 166.0 if compact else (300.0 if narrow else 610.0)

	var context_value: Variant = unified_hud.get("context_panel")
	if context_value is Control:
		var context_panel: Control = context_value as Control
		context_panel.scale = Vector2.ONE
		context_panel.pivot_offset = Vector2.ZERO
		var context_half_width: float = minf(500.0, maxf(width * 0.5 - 24.0, 280.0))
		context_panel.offset_left = -context_half_width
		context_panel.offset_right = context_half_width

	var support_value: Variant = unified_hud.get("support_panel")
	if support_value is Control:
		var support_panel: Control = support_value as Control
		support_panel.scale = Vector2.ONE
		support_panel.pivot_offset = Vector2.ZERO
		support_panel.offset_left = (
			-maxf(minf(272.0, width * 0.43), 210.0)
			if compact
			else (-282.0 if narrow else -300.0)
		)
		support_panel.offset_right = -12.0 if compact else -18.0
		if compact:
			support_panel.offset_top = -330.0
			support_panel.offset_bottom = -210.0
		elif narrow:
			support_panel.offset_top = -338.0
			support_panel.offset_bottom = -218.0
		else:
			support_panel.offset_top = -218.0
			support_panel.offset_bottom = -18.0

	if width_changed and unified_hud.has_method("_refresh_mode_banner"):
		unified_hud.call("_refresh_mode_banner")


func _suppress_duplicate_special_surface() -> void:
	for node: Node in get_tree().get_nodes_in_group("divine_special_hud"):
		var panel_value: Variant = node.get("panel")
		if panel_value is Control:
			var panel: Control = panel_value as Control
			panel.modulate.a = 0.0
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _sync_progression_feedback() -> void:
	if progression_hud == null or not is_instance_valid(progression_hud):
		progression_hud = get_tree().get_first_node_in_group("progression_feedback_hud")
	if progression_hud == null:
		return
	var root_value: Variant = progression_hud.get("root")
	if root_value is Control:
		var legacy_root: Control = root_value as Control
		legacy_root.modulate.a = 0.0
		legacy_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sync_tracked_progress()
	_sync_progression_toasts()


func _sync_tracked_progress() -> void:
	if not unified_hud.has_method("set_tracked_activity"):
		return
	var tracker_value: Variant = progression_hud.get("tracker")
	var tracked: Dictionary = {}
	if tracker_value is Node:
		var tracker: Node = tracker_value as Node
		if tracker.has_method("get_tracked_progress_row"):
			var row_value: Variant = tracker.call("get_tracked_progress_row")
			if row_value is Dictionary:
				tracked = (row_value as Dictionary).duplicate(true)
	unified_hud.call("set_tracked_activity", tracked)


func _sync_progression_toasts() -> void:
	if not unified_hud.has_method("publish_activity"):
		return
	var entries_value: Variant = progression_hud.get("toast_entries")
	if not entries_value is Array:
		return
	var active_sources: Array[String] = []
	for entry_value: Variant in entries_value as Array:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value as Dictionary
		var data_value: Variant = entry.get("data", {})
		if not data_value is Dictionary:
			continue
		var data: Dictionary = data_value as Dictionary
		var kind: String = str(data.get("kind", "tracked"))
		var title: String = str(data.get("title", "Update"))
		var body: String = str(data.get("body", ""))
		var source_id: String = str(data.get(
			"dedupe_key",
			kind + ":" + title.to_lower().replace(" ", "_")
		))
		active_sources.append(source_id)
		var signature: String = (
			kind + "|" + title + "|" + body + "|"
			+ str(data.get("current", -1)) + "|"
			+ str(data.get("target", -1)) + "|"
			+ str(data.get("major", false))
		)
		if str(mirrored_activity_signatures.get(source_id, "")) == signature:
			continue
		mirrored_activity_signatures[source_id] = signature
		if not mirrored_sources.has(source_id):
			mirrored_sources.append(source_id)
		var elapsed: float = float(entry.get("elapsed", 0.0))
		var duration: float = float(data.get("duration", 2.8))
		var remaining: float = maxf(duration - elapsed, 0.3)
		unified_hud.call(
			"publish_activity",
			kind,
			title,
			body,
			remaining,
			source_id,
			80 if bool(data.get("major", false)) else 50,
			bool(data.get("major", false)),
			int(data.get("current", -1)),
			int(data.get("target", -1))
		)
		sync_count += 1
	for index: int in range(mirrored_sources.size() - 1, -1, -1):
		var source_id: String = mirrored_sources[index]
		if active_sources.has(source_id):
			continue
		if unified_hud.has_method("clear_activity"):
			unified_hud.call("clear_activity", source_id)
		mirrored_activity_signatures.erase(source_id)
		mirrored_sources.remove_at(index)


func _rect_snapshot(control: Control) -> Dictionary:
	if control == null:
		return {}
	var rect: Rect2 = control.get_global_rect()
	return {
		"position": rect.position,
		"size": rect.size,
		"end": rect.end,
	}


func get_debug_data() -> Dictionary:
	var stats: Control = unified_hud.get("stats_panel") as Control if unified_hud != null else null
	var mode: Control = unified_hud.get("mode_panel") as Control if unified_hud != null else null
	var activity: Control = unified_hud.get("activity_rail") as Control if unified_hud != null else null
	var support: Control = unified_hud.get("support_panel") as Control if unified_hud != null else null
	return {
		"unified_hud": unified_hud != null and is_instance_valid(unified_hud),
		"progression_hud": progression_hud != null and is_instance_valid(progression_hud),
		"mirrored_sources": mirrored_sources.duplicate(),
		"sync_count": sync_count,
		"layout_width": last_layout_width,
		"compact_layout": last_layout_width > 0.0 and last_layout_width < 900.0,
		"narrow_layout": last_layout_width > 0.0 and last_layout_width < 1500.0,
		"rects": {
			"status": _rect_snapshot(stats),
			"mode": _rect_snapshot(mode),
			"activity": _rect_snapshot(activity),
			"support": _rect_snapshot(support),
		},
	}
