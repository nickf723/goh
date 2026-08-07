extends Node
class_name ControllerHapticPattern

signal pattern_started(pattern_id: String, device_count: int)
signal pattern_step_started(
	pattern_id: String,
	step_index: int,
	weak_strength: float,
	strong_strength: float,
	duration_seconds: float
)
signal pattern_finished(pattern_id: String)

@export var native_output_enabled: bool = true
@export_range(1, 4, 1) var maximum_devices: int = 1
@export_range(0.0, 1.0, 0.05) var fallback_intensity_scale: float = 1.0

var source_actor: Node
var active_pattern_id: String = ""
var pattern_steps: Array[Dictionary] = []
var active_devices: Array[int] = []
var step_index: int = -1
var step_remaining: float = 0.0
var intensity_scale: float = 1.0
var active: bool = false
var finish_reason: String = "not_started"

var started_step_count: int = 0
var vibration_start_count: int = 0
var vibration_stop_count: int = 0
var completed_pattern_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("controller_haptic_patterns")
	add_to_group("debuggable")
	set_process(false)


func _process(delta: float) -> void:
	if not active:
		return
	step_remaining -= maxf(delta, 0.0)
	var safety: int = 0
	while active and step_remaining <= 0.0 and safety < 16:
		var overshoot: float = -step_remaining
		_advance_step()
		if active:
			step_remaining -= overshoot
		safety += 1


func _exit_tree() -> void:
	_stop_all_devices()


func play_pattern(
	pattern_id: String,
	raw_steps: Array,
	new_source_actor: Node = null,
	intensity_multiplier: float = 1.0,
	override_devices: Array[int] = []
) -> bool:
	cancel_pattern(false, "replaced")
	source_actor = new_source_actor
	active_pattern_id = pattern_id
	pattern_steps = _normalize_steps(raw_steps)
	intensity_scale = clampf(
		_resolve_preference_scale() * intensity_multiplier,
		0.0,
		1.0
	)
	active_devices = _resolve_devices(override_devices)
	step_index = -1
	step_remaining = 0.0
	finish_reason = "starting"

	if pattern_steps.is_empty():
		finish_reason = "empty_pattern"
		call_deferred("queue_free")
		return false
	if intensity_scale <= 0.001:
		finish_reason = "disabled"
		call_deferred("queue_free")
		return false
	if active_devices.is_empty():
		finish_reason = "no_controller"
		call_deferred("queue_free")
		return false

	active = true
	set_process(true)
	pattern_started.emit(active_pattern_id, active_devices.size())
	_advance_step()
	return active


func cancel_pattern(
	free_after_cancel: bool = true,
	reason: String = "cancelled"
) -> void:
	if active:
		_stop_all_devices()
	active = false
	set_process(false)
	finish_reason = reason
	step_remaining = 0.0
	if free_after_cancel and is_inside_tree():
		queue_free()


func belongs_to_source(candidate: Node) -> bool:
	return source_actor != null and source_actor == candidate


func _advance_step() -> void:
	step_index += 1
	if step_index >= pattern_steps.size():
		_finish_pattern("complete")
		return

	var step: Dictionary = pattern_steps[step_index]
	var duration: float = maxf(float(step.get("duration", 0.01)), 0.001)
	var weak: float = clampf(
		float(step.get("weak", 0.0)) * intensity_scale,
		0.0,
		1.0
	)
	var strong: float = clampf(
		float(step.get("strong", 0.0)) * intensity_scale,
		0.0,
		1.0
	)
	step_remaining = duration
	started_step_count += 1

	if weak <= 0.001 and strong <= 0.001:
		_stop_all_devices()
	else:
		_start_devices(weak, strong, duration)

	pattern_step_started.emit(
		active_pattern_id,
		step_index,
		weak,
		strong,
		duration
	)


func _finish_pattern(reason: String) -> void:
	if not active:
		return
	_stop_all_devices()
	active = false
	set_process(false)
	finish_reason = reason
	completed_pattern_count += 1
	pattern_finished.emit(active_pattern_id)
	queue_free()


func _start_devices(
	weak_strength: float,
	strong_strength: float,
	duration_seconds: float
) -> void:
	for device_id: int in active_devices:
		vibration_start_count += 1
		if native_output_enabled:
			Input.start_joy_vibration(
				device_id,
				weak_strength,
				strong_strength,
				duration_seconds
			)


func _stop_all_devices() -> void:
	for device_id: int in active_devices:
		vibration_stop_count += 1
		if native_output_enabled:
			Input.stop_joy_vibration(device_id)


func _normalize_steps(raw_steps: Array) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	for raw_step: Variant in raw_steps:
		if not raw_step is Dictionary:
			continue
		var step: Dictionary = raw_step as Dictionary
		var duration: float = maxf(float(step.get("duration", 0.0)), 0.0)
		if duration <= 0.0:
			continue
		normalized.append({
			"weak": clampf(float(step.get("weak", 0.0)), 0.0, 1.0),
			"strong": clampf(float(step.get("strong", 0.0)), 0.0, 1.0),
			"duration": duration,
		})
	return normalized


func _resolve_devices(override_devices: Array[int]) -> Array[int]:
	var devices: Array[int] = []
	for override_device: int in override_devices:
		if override_device >= 0 and not devices.has(override_device):
			devices.append(override_device)
			if devices.size() >= maximum_devices:
				return devices

	if not devices.is_empty():
		return devices

	var connected: Array[int] = Input.get_connected_joypads()
	var preferred_device: int = -1
	if source_actor != null and source_actor.has_meta("preferred_joypad_device"):
		preferred_device = int(source_actor.get_meta("preferred_joypad_device"))
	if preferred_device >= 0 and connected.has(preferred_device):
		devices.append(preferred_device)

	for device_id: int in connected:
		if devices.has(device_id):
			continue
		devices.append(device_id)
		if devices.size() >= maximum_devices:
			break
	return devices


func _resolve_preference_scale() -> float:
	if source_actor != null and source_actor.has_meta(
		"controller_vibration_scale"
	):
		var meta_value: Variant = source_actor.get_meta(
			"controller_vibration_scale"
		)
		if meta_value is float or meta_value is int:
			return clampf(float(meta_value), 0.0, 1.0)

	if source_actor != null:
		var preferences: Node = source_actor.get_node_or_null("PlayerPreferences")
		if preferences != null and preferences.has_method("get_preference"):
			var preference_value: Variant = preferences.call(
				"get_preference",
				"controller_vibration_scale"
			)
			if preference_value is float or preference_value is int:
				return clampf(float(preference_value), 0.0, 1.0)

	return clampf(fallback_intensity_scale, 0.0, 1.0)


func get_debug_data() -> Dictionary:
	return {
		"controller_haptic_pattern": true,
		"pattern_id": active_pattern_id,
		"active": active,
		"step_index": step_index,
		"step_count": pattern_steps.size(),
		"step_remaining": step_remaining,
		"device_count": active_devices.size(),
		"devices": active_devices.duplicate(),
		"intensity_scale": intensity_scale,
		"native_output": native_output_enabled,
		"started_steps": started_step_count,
		"vibration_starts": vibration_start_count,
		"vibration_stops": vibration_stop_count,
		"completed_patterns": completed_pattern_count,
		"finish_reason": finish_reason,
	}
