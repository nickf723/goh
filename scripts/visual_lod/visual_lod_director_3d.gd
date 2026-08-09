extends Node3D
class_name VisualLODDirector3D

signal visual_lod_quality_changed(quality: int)

@export var profile: VisualLODProfile
@export var enabled: bool = true

var lighting_director: LightingDirector3D = null
var targets: Dictionary = {}
var category_counts: Dictionary = {}
var active_quality: int = -1
var applied_count: int = 0
var restored_count: int = 0


func _ready() -> void:
	add_to_group("visual_lod_director")
	add_to_group("debuggable")
	_resolve_lighting_director()
	_apply_quality(_current_quality())
	set_meta("visual_lod_initialized", profile != null)


func _process(_delta: float) -> void:
	if not enabled or profile == null:
		return
	if lighting_director == null or not is_instance_valid(lighting_director):
		_resolve_lighting_director()
	var requested_quality: int = _current_quality()
	if requested_quality != active_quality:
		_apply_quality(requested_quality)


func register_geometry(
	target: GeometryInstance3D,
	category: String
) -> bool:
	if profile == null or target == null or not is_instance_valid(target):
		return false
	var normalized: String = category.strip_edges().to_lower()
	if profile.get_distance(normalized, 2) <= 0.0:
		return false
	var target_id: int = target.get_instance_id()
	if targets.has(target_id):
		return true
	targets[target_id] = {
		"ref": weakref(target),
		"category": normalized,
		"original_end": target.visibility_range_end,
		"original_end_margin": target.visibility_range_end_margin,
		"original_fade_mode": target.visibility_range_fade_mode,
		"original_begin": target.visibility_range_begin,
		"original_begin_margin": target.visibility_range_begin_margin,
	}
	category_counts[normalized] = int(category_counts.get(normalized, 0)) + 1
	target.add_to_group("visual_lod_target")
	target.set_meta("visual_lod_category", normalized)
	_apply_target(target, targets[target_id] as Dictionary, _current_quality())
	return true


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		_restore_all()
		return
	active_quality = -1
	_apply_quality(_current_quality())


func _resolve_lighting_director() -> void:
	lighting_director = null
	if get_tree() == null:
		return
	var candidate: Node = get_tree().get_first_node_in_group("lighting_director")
	if candidate is LightingDirector3D:
		lighting_director = candidate as LightingDirector3D


func _current_quality() -> int:
	if lighting_director == null:
		return 2
	return clampi(lighting_director.quality, 0, 2)


func _apply_quality(quality: int) -> void:
	if profile == null:
		return
	active_quality = clampi(quality, 0, 2)
	applied_count = 0
	var invalid_ids: Array[int] = []
	for raw_id: Variant in targets.keys():
		var target_id: int = int(raw_id)
		var record: Dictionary = targets[target_id] as Dictionary
		var weak_value: Variant = record.get("ref", null)
		if not weak_value is WeakRef:
			invalid_ids.append(target_id)
			continue
		var target_value: Variant = (weak_value as WeakRef).get_ref()
		if not target_value is GeometryInstance3D:
			invalid_ids.append(target_id)
			continue
		_apply_target(
			target_value as GeometryInstance3D,
			record,
			active_quality
		)
		applied_count += 1
	for target_id: int in invalid_ids:
		targets.erase(target_id)
	visual_lod_quality_changed.emit(active_quality)


func _apply_target(
	target: GeometryInstance3D,
	record: Dictionary,
	quality: int
) -> void:
	if target == null or profile == null:
		return
	if not enabled:
		_restore_target(target, record)
		return
	var category: String = str(record.get("category", ""))
	var distance: float = profile.get_distance(category, quality)
	if distance <= 0.0:
		_restore_target(target, record)
		return
	target.visibility_range_begin = 0.0
	target.visibility_range_begin_margin = 0.0
	target.visibility_range_end = distance
	target.visibility_range_end_margin = minf(
		profile.get_margin(quality),
		maxf(distance * 0.25, 0.0)
	)
	# Hysteresis is intentionally cheaper than self-fading because it avoids
	# moving opaque materials into the transparent rendering pipeline.
	target.visibility_range_fade_mode = (
		GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	)


func _restore_all() -> void:
	restored_count = 0
	for raw_id: Variant in targets.keys():
		var record: Dictionary = targets[int(raw_id)] as Dictionary
		var weak_value: Variant = record.get("ref", null)
		if not weak_value is WeakRef:
			continue
		var target_value: Variant = (weak_value as WeakRef).get_ref()
		if target_value is GeometryInstance3D:
			_restore_target(target_value as GeometryInstance3D, record)
			restored_count += 1


func _restore_target(
	target: GeometryInstance3D,
	record: Dictionary
) -> void:
	target.visibility_range_begin = float(record.get("original_begin", 0.0))
	target.visibility_range_begin_margin = float(
		record.get("original_begin_margin", 0.0)
	)
	target.visibility_range_end = float(record.get("original_end", 0.0))
	target.visibility_range_end_margin = float(
		record.get("original_end_margin", 0.0)
	)
	target.visibility_range_fade_mode = int(record.get(
		"original_fade_mode",
		GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	))


func get_debug_data() -> Dictionary:
	var live_targets: int = 0
	for raw_id: Variant in targets.keys():
		var record: Dictionary = targets[int(raw_id)] as Dictionary
		var weak_value: Variant = record.get("ref", null)
		if weak_value is WeakRef:
			var value: Variant = (weak_value as WeakRef).get_ref()
			if value is GeometryInstance3D:
				live_targets += 1
	return {
		"visual_lod_director": true,
		"initialized": profile != null,
		"profile_id": profile.profile_id if profile != null else "",
		"enabled": enabled,
		"quality": active_quality,
		"target_count": live_targets,
		"category_counts": category_counts.duplicate(true),
		"applied_count": applied_count,
		"restored_count": restored_count,
		"uses_renderer_visibility_ranges": true,
		"fade_mode": "hysteresis",
		"per_frame_distance_checks": false,
		"collision_unchanged": true,
		"gameplay_authority": false,
	}
