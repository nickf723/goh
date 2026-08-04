extends "res://scripts/progression/progression_feedback_hud.gd"
class_name ProgressionFeedbackHUDUnified

var unified_hud: Node
var forwarded_activity_sources: Array[String] = []
var unified_publish_count: int = 0


func _ready() -> void:
	super._ready()
	_resolve_unified_hud()
	_apply_unified_visibility()


func _process(delta: float) -> void:
	super._process(delta)
	_resolve_unified_hud()
	_apply_unified_visibility()


func bind_tracker(value: Node) -> void:
	super.bind_tracker(value)
	_resolve_unified_hud()
	_sync_tracked_activity()


func push_feedback(
	kind: String,
	title: String,
	body: String,
	dedupe_key: String = "",
	current: int = -1,
	target: int = -1,
	major: bool = false
) -> void:
	super.push_feedback(
		kind,
		title,
		body,
		dedupe_key,
		current,
		target,
		major
	)
	_resolve_unified_hud()
	if unified_hud == null or not unified_hud.has_method("publish_activity"):
		return
	var resolved_kind: String = kind.strip_edges().to_lower()
	if resolved_kind == "":
		resolved_kind = "tracked"
	var resolved_source: String = dedupe_key.strip_edges()
	if resolved_source == "":
		resolved_source = (
			resolved_kind
			+ ":"
			+ title.to_lower().replace(" ", "_")
		)
	if not forwarded_activity_sources.has(resolved_source):
		forwarded_activity_sources.append(resolved_source)
	unified_hud.call(
		"publish_activity",
		resolved_kind,
		title,
		body,
		MAJOR_TOAST_DURATION if major else DEFAULT_TOAST_DURATION,
		resolved_source,
		80 if major else 50,
		major,
		current,
		target
	)
	unified_publish_count += 1


func clear_feedback() -> void:
	super.clear_feedback()
	_resolve_unified_hud()
	if unified_hud != null and unified_hud.has_method("clear_activity"):
		for source_id: String in forwarded_activity_sources:
			unified_hud.call("clear_activity", source_id)
	forwarded_activity_sources.clear()


func refresh_tracked_progress() -> void:
	super.refresh_tracked_progress()
	_resolve_unified_hud()
	_sync_tracked_activity()


func _sync_tracked_activity() -> void:
	if unified_hud == null or not unified_hud.has_method("set_tracked_activity"):
		return
	var row: Dictionary = {}
	if tracker != null and is_instance_valid(tracker) and tracker.has_method("get_tracked_progress_row"):
		var row_value: Variant = tracker.call("get_tracked_progress_row")
		if row_value is Dictionary:
			row = (row_value as Dictionary).duplicate(true)
	unified_hud.call("set_tracked_activity", row)


func _resolve_unified_hud() -> void:
	if unified_hud != null and is_instance_valid(unified_hud):
		return
	unified_hud = get_tree().get_first_node_in_group("unified_hud_shell")


func _apply_unified_visibility() -> void:
	if root == null:
		return
	if unified_hud == null:
		root.modulate.a = 1.0
		return
	root.modulate.a = 0.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["unified_hud"] = unified_hud != null and is_instance_valid(unified_hud)
	data["unified_publish_count"] = unified_publish_count
	data["legacy_surface_visually_retired"] = root != null and is_zero_approx(root.modulate.a)
	return data
