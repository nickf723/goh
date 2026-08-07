extends Control
class_name RuntimePerformanceMonitor

signal performance_snapshot_updated(snapshot: Dictionary)
signal performance_budget_state_changed(state: String, snapshot: Dictionary)

@export_group("Sampling")
@export_range(0.1, 2.0, 0.05) var sample_interval_seconds: float = 0.5
@export_range(15.0, 240.0, 1.0) var target_fps: float = 60.0
@export_range(5.0, 100.0, 0.5) var spike_threshold_ms: float = 25.0
@export_range(60, 2400, 30) var maximum_history_samples: int = 600

@export_group("Overlay")
@export var show_on_start: bool = false
@export var toggle_key: Key = KEY_F7
@export var collect_tree_counts_when_visible: bool = true
@export_range(16, 2048, 16) var tree_census_nodes_per_frame: int = 192
@export_range(0.25, 10.0, 0.25) var tree_census_refresh_seconds: float = 2.0

var sample_remaining: float = 0.0
var pending_frame_ms: Array[float] = []
var frame_history_ms: Array[float] = []
var frame_history_cursor: int = 0
var frame_history_overwrite_count: int = 0
var latest_snapshot: Dictionary = {}
var latest_budget_state: String = "unknown"
var lifetime_spike_count: int = 0
var sample_count: int = 0
var overlay_panel: PanelContainer
var overlay_label: Label

var latest_tree_counts: Dictionary = {}
var tree_census_working_counts: Dictionary = {}
var tree_census_stack: Array[Node] = []
var tree_census_active: bool = false
var tree_census_refresh_remaining: float = 0.0
var tree_census_scanned_nodes: int = 0
var tree_census_completed_count: int = 0
var tree_census_cancel_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_to_group("runtime_performance_monitors")
	add_to_group("debuggable")
	_build_overlay()
	set_overlay_visible(show_on_start)
	sample_remaining = 0.0


func _process(delta: float) -> void:
	record_frame_sample(delta)
	_update_tree_census(delta)
	sample_remaining -= maxf(delta, 0.0)
	if sample_remaining > 0.0:
		return
	sample_remaining = maxf(sample_interval_seconds, 0.1)
	sample_performance()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.keycode == toggle_key:
		set_overlay_visible(not is_overlay_visible())
		get_viewport().set_input_as_handled()


func record_frame_sample(delta_seconds: float) -> void:
	var frame_ms: float = maxf(delta_seconds, 0.0) * 1000.0
	if frame_ms <= 0.0:
		return
	pending_frame_ms.append(frame_ms)
	_record_history_sample(frame_ms)
	if frame_ms >= spike_threshold_ms:
		lifetime_spike_count += 1


func _record_history_sample(frame_ms: float) -> void:
	var capacity: int = maxi(maximum_history_samples, 1)
	if frame_history_ms.size() > capacity:
		frame_history_ms.resize(capacity)
		frame_history_cursor = 0
	if frame_history_ms.size() < capacity:
		frame_history_ms.append(frame_ms)
		if frame_history_ms.size() == capacity:
			frame_history_cursor = 0
		return

	# A fixed ring overwrites one float in O(1). Profiling the game must never
	# become a steadily growing source of work itself.
	frame_history_ms[frame_history_cursor] = frame_ms
	frame_history_cursor = (frame_history_cursor + 1) % capacity
	frame_history_overwrite_count += 1


func sample_performance() -> Dictionary:
	# Move the pending buffer instead of duplicating it, then replace it with a
	# fresh short array. The sampled batch remains valid without an extra copy.
	var batch: Array[float] = pending_frame_ms
	pending_frame_ms = []
	if batch.is_empty():
		batch = [1000.0 / maxf(target_fps, 1.0)]
	var average_frame_ms: float = _average(batch)
	var p95_frame_ms: float = _percentile(batch, 0.95)
	var p99_frame_ms: float = _percentile(batch, 0.99)
	var recent_spikes: int = 0
	for frame_ms: float in batch:
		if frame_ms >= spike_threshold_ms:
			recent_spikes += 1

	# The previous overlay recursively walked the complete scene tree inside this
	# sampling call. Large scenes therefore produced a profiler-authored frame
	# spike every half second. The census is now amortized across ordinary frames,
	# and sampling only copies the last completed result.
	var tree_counts: Dictionary = latest_tree_counts.duplicate(true)
	latest_snapshot = {
		"fps": _monitor(Performance.TIME_FPS),
		"average_frame_ms": snappedf(average_frame_ms, 0.01),
		"p95_frame_ms": snappedf(p95_frame_ms, 0.01),
		"p99_frame_ms": snappedf(p99_frame_ms, 0.01),
		"one_percent_low_fps": snappedf(1000.0 / maxf(p99_frame_ms, 0.001), 0.1),
		"process_ms": snappedf(_monitor(Performance.TIME_PROCESS) * 1000.0, 0.01),
		"physics_ms": snappedf(_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.01),
		"nodes": int(_monitor(Performance.OBJECT_NODE_COUNT)),
		"objects": int(_monitor(Performance.OBJECT_COUNT)),
		"orphan_nodes": int(_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"draw_calls": int(_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"rendered_objects": int(_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"static_memory_mb": snappedf(_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"recent_spikes": recent_spikes,
		"lifetime_spikes": lifetime_spike_count,
		"sample_frames": batch.size(),
		"history_samples": frame_history_ms.size(),
		"history_overwrites": frame_history_overwrite_count,
		"tree_counts": tree_counts,
		"tree_census_active": tree_census_active,
		"tree_census_scanned_nodes": tree_census_scanned_nodes,
		"tree_census_completed": tree_census_completed_count,
	}
	var next_state: String = _resolve_budget_state(p95_frame_ms)
	latest_snapshot["budget_state"] = next_state
	sample_count += 1
	if next_state != latest_budget_state:
		latest_budget_state = next_state
		performance_budget_state_changed.emit(next_state, latest_snapshot.duplicate(true))
	performance_snapshot_updated.emit(latest_snapshot.duplicate(true))
	_refresh_overlay()
	return latest_snapshot.duplicate(true)


func set_overlay_visible(value: bool) -> void:
	if overlay_panel != null:
		overlay_panel.visible = value
	if value:
		sample_remaining = 0.0
		tree_census_refresh_remaining = 0.0
		if collect_tree_counts_when_visible and not tree_census_active:
			_begin_tree_census()
	else:
		_cancel_tree_census()


func is_overlay_visible() -> bool:
	return overlay_panel != null and overlay_panel.visible


func get_performance_snapshot() -> Dictionary:
	return latest_snapshot.duplicate(true)


func reset_history() -> void:
	pending_frame_ms.clear()
	frame_history_ms.clear()
	frame_history_cursor = 0
	frame_history_overwrite_count = 0
	lifetime_spike_count = 0
	sample_count = 0
	latest_snapshot.clear()
	latest_budget_state = "unknown"
	latest_tree_counts.clear()
	tree_census_completed_count = 0
	tree_census_cancel_count = 0
	_cancel_tree_census(false)
	_refresh_overlay()


func _resolve_budget_state(p95_frame_ms: float) -> String:
	var target_frame_ms: float = 1000.0 / maxf(target_fps, 1.0)
	if p95_frame_ms <= target_frame_ms * 1.15:
		return "green"
	if p95_frame_ms <= target_frame_ms * 1.6:
		return "amber"
	return "red"


func _monitor(monitor: Performance.Monitor) -> float:
	return float(Performance.get_monitor(monitor))


func _average(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / float(values.size())


func _percentile(values: Array[float], percentile: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values: Array[float] = values.duplicate()
	sorted_values.sort()
	var index: int = clampi(
		int(ceil(clampf(percentile, 0.0, 1.0) * float(sorted_values.size()))) - 1,
		0,
		sorted_values.size() - 1
	)
	return sorted_values[index]


func _update_tree_census(delta: float) -> void:
	if not is_overlay_visible() or not collect_tree_counts_when_visible:
		return
	if tree_census_active:
		_step_tree_census(tree_census_nodes_per_frame)
		return

	tree_census_refresh_remaining = maxf(
		tree_census_refresh_remaining - maxf(delta, 0.0),
		0.0
	)
	if tree_census_refresh_remaining > 0.0:
		return
	_begin_tree_census()
	_step_tree_census(tree_census_nodes_per_frame)


func _begin_tree_census() -> void:
	var scene: Node = get_tree().current_scene if get_tree() != null else null
	if scene == null:
		latest_tree_counts.clear()
		tree_census_active = false
		return
	tree_census_stack.clear()
	tree_census_stack.append(scene)
	tree_census_working_counts = {
		"processing_nodes": 0,
		"physics_processing_nodes": 0,
		"visible_labels_3d": 0,
		"visible_geometry": 0,
	}
	tree_census_scanned_nodes = 0
	tree_census_active = true


func _step_tree_census(node_budget: int) -> bool:
	if not tree_census_active:
		return false
	var remaining_budget: int = maxi(node_budget, 1)
	while remaining_budget > 0 and not tree_census_stack.is_empty():
		var node: Node = tree_census_stack.pop_back()
		remaining_budget -= 1
		if node == null or not is_instance_valid(node):
			continue
		tree_census_scanned_nodes += 1
		if node.is_processing():
			tree_census_working_counts["processing_nodes"] = int(
				tree_census_working_counts.get("processing_nodes", 0)
			) + 1
		if node.is_physics_processing():
			tree_census_working_counts["physics_processing_nodes"] = int(
				tree_census_working_counts.get("physics_processing_nodes", 0)
			) + 1
		if node is Label3D and (node as Label3D).visible:
			tree_census_working_counts["visible_labels_3d"] = int(
				tree_census_working_counts.get("visible_labels_3d", 0)
			) + 1
		elif node is GeometryInstance3D and (node as GeometryInstance3D).visible:
			tree_census_working_counts["visible_geometry"] = int(
				tree_census_working_counts.get("visible_geometry", 0)
			) + 1

		# Index-based traversal avoids allocating a temporary child Array for every
		# node in the census.
		for child_index: int in range(node.get_child_count()):
			tree_census_stack.append(node.get_child(child_index))

	if tree_census_stack.is_empty():
		_finish_tree_census()
		return true
	return false


func _finish_tree_census() -> void:
	var tree: SceneTree = get_tree()
	if tree != null:
		tree_census_working_counts["spell_effects"] = tree.get_node_count_in_group(
			"spell_effects"
		)
		tree_census_working_counts["persistent_spell_effects"] = tree.get_node_count_in_group(
			"persistent_spell_effects"
		)
		tree_census_working_counts["spell_projectiles"] = tree.get_node_count_in_group(
			"spell_projectiles"
		)
		tree_census_working_counts["spell_fields"] = tree.get_node_count_in_group(
			"spell_fields"
		)
	tree_census_working_counts["scanned_nodes"] = tree_census_scanned_nodes
	latest_tree_counts = tree_census_working_counts.duplicate(true)
	tree_census_working_counts.clear()
	tree_census_stack.clear()
	tree_census_active = false
	tree_census_completed_count += 1
	tree_census_refresh_remaining = maxf(
		tree_census_refresh_seconds,
		0.25
	)
	_refresh_overlay()


func _cancel_tree_census(count_cancel: bool = true) -> void:
	if tree_census_active and count_cancel:
		tree_census_cancel_count += 1
	tree_census_active = false
	tree_census_stack.clear()
	tree_census_working_counts.clear()
	tree_census_scanned_nodes = 0


# Compatibility accessor for debug callers. It returns the last complete census
# and never performs a synchronous recursive walk.
func _collect_tree_counts() -> Dictionary:
	return latest_tree_counts.duplicate(true)


func _build_overlay() -> void:
	overlay_panel = PanelContainer.new()
	overlay_panel.name = "PerformanceOverlay"
	overlay_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	overlay_panel.offset_left = -310.0
	overlay_panel.offset_top = 18.0
	overlay_panel.offset_right = -18.0
	overlay_panel.offset_bottom = 274.0
	overlay_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.022, 0.038, 0.92)
	style.border_color = Color(0.3, 0.78, 1.0, 0.72)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12.0)
	overlay_panel.add_theme_stylebox_override("panel", style)
	overlay_label = Label.new()
	overlay_label.name = "PerformanceReadout"
	overlay_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_label.add_theme_font_size_override("font_size", 14)
	overlay_label.add_theme_color_override("font_color", Color(0.84, 0.94, 1.0))
	overlay_panel.add_child(overlay_label)
	add_child(overlay_panel)
	_refresh_overlay()


func _refresh_overlay() -> void:
	if overlay_label == null:
		return
	if latest_snapshot.is_empty():
		overlay_label.text = "PERFORMANCE • F7\nCollecting frame samples…"
		return
	var tree_counts: Dictionary = latest_snapshot.get("tree_counts", {}) as Dictionary
	var census_label: String = (
		"SCANNING " + str(tree_census_scanned_nodes)
		if tree_census_active
		else "READY " + str(tree_census_completed_count)
	)
	overlay_label.text = (
		"PERFORMANCE • " + str(latest_snapshot.get("budget_state", "unknown")).to_upper() + " • F7\n"
		+ "FPS " + str(snappedf(float(latest_snapshot.get("fps", 0.0)), 0.1))
		+ "   AVG " + str(latest_snapshot.get("average_frame_ms", 0.0)) + " ms\n"
		+ "P95 " + str(latest_snapshot.get("p95_frame_ms", 0.0)) + " ms"
		+ "   1% LOW " + str(latest_snapshot.get("one_percent_low_fps", 0.0)) + "\n"
		+ "PROCESS " + str(latest_snapshot.get("process_ms", 0.0)) + " ms"
		+ "   PHYSICS " + str(latest_snapshot.get("physics_ms", 0.0)) + " ms\n"
		+ "DRAWS " + str(latest_snapshot.get("draw_calls", 0))
		+ "   RENDERED " + str(latest_snapshot.get("rendered_objects", 0)) + "\n"
		+ "NODES " + str(latest_snapshot.get("nodes", 0))
		+ "   PROCESSING " + str(tree_counts.get("processing_nodes", "—")) + "\n"
		+ "SPELL FX " + str(tree_counts.get("spell_effects", "—"))
		+ "   PERSISTENT " + str(tree_counts.get("persistent_spell_effects", "—")) + "\n"
		+ "LABELS 3D " + str(tree_counts.get("visible_labels_3d", "—"))
		+ "   CENSUS " + census_label + "\n"
		+ "SPIKES " + str(latest_snapshot.get("recent_spikes", 0))
		+ "   HISTORY " + str(frame_history_ms.size())
	)


func get_debug_data() -> Dictionary:
	return {
		"runtime_performance_monitor": true,
		"overlay_visible": is_overlay_visible(),
		"target_fps": target_fps,
		"spike_threshold_ms": spike_threshold_ms,
		"sample_count": sample_count,
		"history_samples": frame_history_ms.size(),
		"history_capacity": maximum_history_samples,
		"history_cursor": frame_history_cursor,
		"history_overwrites": frame_history_overwrite_count,
		"tree_census_active": tree_census_active,
		"tree_census_nodes_per_frame": tree_census_nodes_per_frame,
		"tree_census_scanned_nodes": tree_census_scanned_nodes,
		"tree_census_completed": tree_census_completed_count,
		"tree_census_cancelled": tree_census_cancel_count,
		"tree_counts": latest_tree_counts.duplicate(true),
		"latest": latest_snapshot.duplicate(true),
	}
