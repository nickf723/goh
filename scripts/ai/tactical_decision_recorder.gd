extends RefCounted
class_name TacticalDecisionRecorder


const DEFAULT_MAX_FRAMES: int = 64
const MAX_SANITIZE_DEPTH: int = 10

var max_frames: int = DEFAULT_MAX_FRAMES
var frames: Array[Dictionary] = []
var cursor: int = -1
var next_sequence: int = 1
var duplicate_count: int = 0


func configure(frame_capacity: int = DEFAULT_MAX_FRAMES) -> TacticalDecisionRecorder:
	max_frames = maxi(frame_capacity, 1)
	_trim_to_capacity()
	return self


func record_frame(
	source_id: int,
	source_name: String,
	event_name: String,
	decision: Dictionary,
	coordination: Dictionary = {},
	metadata: Dictionary = {}
) -> Dictionary:
	var sanitized_decision: Dictionary = _sanitize_dictionary(decision)
	var sanitized_coordination: Dictionary = _sanitize_dictionary(coordination)
	var sanitized_metadata: Dictionary = _sanitize_dictionary(metadata)
	var fingerprint_payload: Dictionary = {
		"source_id": source_id,
		"event": event_name,
		"decision": sanitized_decision,
		"coordination": sanitized_coordination,
		"metadata": sanitized_metadata,
	}
	var fingerprint: String = JSON.stringify(
		fingerprint_payload,
		"",
		true
	).sha256_text()
	var now_msec: int = Time.get_ticks_msec()
	if not frames.is_empty() and str(frames[-1].get("fingerprint", "")) == fingerprint:
		var repeated: Dictionary = frames[-1]
		repeated["repeat_count"] = int(repeated.get("repeat_count", 1)) + 1
		repeated["last_seen_msec"] = now_msec
		frames[-1] = repeated
		cursor = frames.size() - 1
		duplicate_count += 1
		return {
			"recorded": false,
			"deduplicated": true,
			"frame": repeated.duplicate(true),
		}

	var frame: Dictionary = {
		"sequence": next_sequence,
		"recorded_at_msec": now_msec,
		"last_seen_msec": now_msec,
		"repeat_count": 1,
		"source_id": source_id,
		"source_name": source_name,
		"event": event_name,
		"decision": sanitized_decision,
		"coordination": sanitized_coordination,
		"metadata": sanitized_metadata,
		"fingerprint": fingerprint,
	}
	next_sequence += 1
	frames.append(frame)
	_trim_to_capacity()
	cursor = frames.size() - 1
	return {
		"recorded": true,
		"deduplicated": false,
		"frame": frame.duplicate(true),
	}


func clear() -> void:
	frames.clear()
	cursor = -1
	next_sequence = 1
	duplicate_count = 0


func get_frame_count() -> int:
	return frames.size()


func get_current_frame() -> Dictionary:
	if cursor < 0 or cursor >= frames.size():
		return {}
	return frames[cursor].duplicate(true)


func get_frame(index: int) -> Dictionary:
	if index < 0 or index >= frames.size():
		return {}
	return frames[index].duplicate(true)


func step_back() -> Dictionary:
	if frames.is_empty():
		cursor = -1
		return {}
	cursor = maxi(cursor - 1, 0)
	return get_current_frame()


func step_forward() -> Dictionary:
	if frames.is_empty():
		cursor = -1
		return {}
	cursor = mini(cursor + 1, frames.size() - 1)
	return get_current_frame()


func jump_to_latest() -> Dictionary:
	cursor = frames.size() - 1
	return get_current_frame()


func get_frames() -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for frame: Dictionary in frames:
		copy.append(frame.duplicate(true))
	return copy


func to_dictionary() -> Dictionary:
	return {
		"schema_version": 1,
		"frame_count": frames.size(),
		"max_frames": max_frames,
		"cursor": cursor,
		"duplicate_count": duplicate_count,
		"frames": get_frames(),
	}


func to_json(indent: String = "  ") -> String:
	return JSON.stringify(to_dictionary(), indent, false)


func has_live_object_references() -> bool:
	return _contains_object(frames)


func get_debug_data() -> Dictionary:
	return {
		"frame_count": frames.size(),
		"max_frames": max_frames,
		"cursor": cursor,
		"duplicate_count": duplicate_count,
		"has_live_objects": has_live_object_references(),
	}


func _trim_to_capacity() -> void:
	while frames.size() > max_frames:
		frames.pop_front()
	cursor = mini(cursor, frames.size() - 1)


func _sanitize_dictionary(value: Dictionary) -> Dictionary:
	var sanitized: Variant = _sanitize(value, 0)
	return sanitized as Dictionary if sanitized is Dictionary else {}


func _sanitize(value: Variant, depth: int) -> Variant:
	if depth > MAX_SANITIZE_DEPTH:
		return "<depth-limit>"
	if value == null or value is bool or value is int or value is float or value is String:
		return value
	if value is StringName or value is NodePath:
		return str(value)
	if value is Vector2:
		var vector2_value: Vector2 = value
		return {"x": vector2_value.x, "y": vector2_value.y}
	if value is Vector3:
		var vector3_value: Vector3 = value
		return {"x": vector3_value.x, "y": vector3_value.y, "z": vector3_value.z}
	if value is Color:
		var color_value: Color = value
		return {
			"r": color_value.r,
			"g": color_value.g,
			"b": color_value.b,
			"a": color_value.a,
		}
	if value is Dictionary:
		var source_dictionary: Dictionary = value
		var result_dictionary: Dictionary = {}
		for raw_key: Variant in source_dictionary.keys():
			var key: String = str(raw_key)
			if key in ["selected_candidate", "source_ref"]:
				continue
			result_dictionary[key] = _sanitize(
				source_dictionary.get(raw_key),
				depth + 1
			)
		return result_dictionary
	if value is Array:
		var source_array: Array = value
		var result_array: Array = []
		for item: Variant in source_array:
			result_array.append(_sanitize(item, depth + 1))
		return result_array
	if value is Node:
		var node: Node = value as Node
		return {
			"object_type": node.get_class(),
			"name": node.name,
			"instance_id": node.get_instance_id(),
		}
	if value is Resource:
		var resource: Resource = value as Resource
		return {
			"object_type": resource.get_class(),
			"resource_path": resource.resource_path,
		}
	if value is Object:
		var object: Object = value as Object
		return {
			"object_type": object.get_class(),
			"instance_id": object.get_instance_id(),
		}
	return str(value)


func _contains_object(value: Variant) -> bool:
	if value is Object:
		return true
	if value is Dictionary:
		var dictionary: Dictionary = value
		for item: Variant in dictionary.values():
			if _contains_object(item):
				return true
	if value is Array:
		var array: Array = value
		for item: Variant in array:
			if _contains_object(item):
				return true
	return false
