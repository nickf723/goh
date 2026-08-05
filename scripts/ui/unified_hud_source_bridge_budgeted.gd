extends "res://scripts/ui/unified_hud_source_bridge.gd"
class_name UnifiedHUDSourceBridgeBudgeted

@export_range(0.05, 1.0, 0.05) var progression_sync_seconds: float = 0.2
@export_range(0.1, 2.0, 0.1) var duplicate_suppression_seconds: float = 0.8

var progression_sync_remaining: float = 0.0
var duplicate_suppression_remaining: float = 0.0
var layout_dirty: bool = true
var layout_pass_count: int = 0
var throttled_progression_pass_count: int = 0
var throttled_suppression_pass_count: int = 0
var observed_viewport: Viewport


func _ready() -> void:
	super._ready()
	observed_viewport = get_viewport()
	if observed_viewport != null:
		var callback := Callable(self, "_on_viewport_size_changed")
		if not observed_viewport.size_changed.is_connected(callback):
			observed_viewport.size_changed.connect(callback)
	if get_tree() != null:
		var node_callback := Callable(self, "_on_tree_node_added")
		if not get_tree().node_added.is_connected(node_callback):
			get_tree().node_added.connect(node_callback)
	progression_sync_remaining = 0.0
	duplicate_suppression_remaining = 0.0
	layout_dirty = true


func _exit_tree() -> void:
	if observed_viewport != null and is_instance_valid(observed_viewport):
		var callback := Callable(self, "_on_viewport_size_changed")
		if observed_viewport.size_changed.is_connected(callback):
			observed_viewport.size_changed.disconnect(callback)
	if get_tree() != null:
		var node_callback := Callable(self, "_on_tree_node_added")
		if get_tree().node_added.is_connected(node_callback):
			get_tree().node_added.disconnect(node_callback)


func _process(delta: float) -> void:
	var previous_hud: Node = unified_hud
	_resolve_unified_hud()
	if unified_hud == null:
		return
	if previous_hud != unified_hud:
		layout_dirty = true
		progression_sync_remaining = 0.0
		duplicate_suppression_remaining = 0.0

	if layout_dirty:
		_apply_responsive_layout()
		layout_dirty = false
		layout_pass_count += 1

	progression_sync_remaining -= maxf(delta, 0.0)
	if progression_sync_remaining <= 0.0:
		progression_sync_remaining = maxf(progression_sync_seconds, 0.05)
		_sync_progression_feedback()
		throttled_progression_pass_count += 1

	duplicate_suppression_remaining -= maxf(delta, 0.0)
	if duplicate_suppression_remaining <= 0.0:
		duplicate_suppression_remaining = maxf(duplicate_suppression_seconds, 0.1)
		_suppress_duplicate_special_surface()
		throttled_suppression_pass_count += 1


func mark_layout_dirty() -> void:
	layout_dirty = true


func request_immediate_source_sync() -> void:
	progression_sync_remaining = 0.0
	duplicate_suppression_remaining = 0.0


func _on_viewport_size_changed() -> void:
	layout_dirty = true


func _on_tree_node_added(node: Node) -> void:
	if node == null:
		return
	if (
		node.is_in_group("unified_hud_shell")
		or node.is_in_group("progression_feedback_hud")
		or node.is_in_group("divine_special_hud")
	):
		request_immediate_source_sync()
		if node.is_in_group("unified_hud_shell"):
			layout_dirty = true


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["budgeted_sync"] = true
	data["layout_dirty"] = layout_dirty
	data["layout_passes"] = layout_pass_count
	data["progression_sync_seconds"] = progression_sync_seconds
	data["progression_passes"] = throttled_progression_pass_count
	data["suppression_sync_seconds"] = duplicate_suppression_seconds
	data["suppression_passes"] = throttled_suppression_pass_count
	return data
