extends Node
class_name PlayerPreferenceService

signal preference_changed(preference_id: String, value: Variant)
signal preferences_reset
signal preferences_loaded(from_disk: bool)

const SETTINGS_VERSION: int = 1
const SETTINGS_PATH: String = "user://goh_player_preferences.json"

const CAMERA_CATEGORY: String = "Camera Input"
const FEEDBACK_CATEGORY: String = "Motion and Feedback"

const PREFERENCE_IDS: Array[String] = [
	"mouse_camera_scale",
	"controller_camera_scale",
	"controller_camera_deadzone",
	"focus_menu_camera",
	"camera_impact_scale",
	"motion_effect_scale",
]

const PREFERENCE_DEFINITIONS: Dictionary = {
	"mouse_camera_scale": {
		"label": "Mouse Look Speed",
		"description": "Scales mouse camera movement without changing the authored pitch limits.",
		"category": CAMERA_CATEGORY,
		"icon": "M",
		"default": 1.0,
		"options": [
			{"value": 0.5, "label": "50%"},
			{"value": 0.75, "label": "75%"},
			{"value": 1.0, "label": "100%"},
			{"value": 1.25, "label": "125%"},
			{"value": 1.5, "label": "150%"},
			{"value": 2.0, "label": "200%"},
		],
	},
	"controller_camera_scale": {
		"label": "Controller Look Speed",
		"description": "Scales right-stick camera movement while preserving the existing response curve.",
		"category": CAMERA_CATEGORY,
		"icon": "R",
		"default": 1.0,
		"options": [
			{"value": 0.5, "label": "50%"},
			{"value": 0.75, "label": "75%"},
			{"value": 1.0, "label": "100%"},
			{"value": 1.25, "label": "125%"},
			{"value": 1.5, "label": "150%"},
			{"value": 2.0, "label": "200%"},
		],
	},
	"controller_camera_deadzone": {
		"label": "Camera Stick Deadzone",
		"description": "Controls how far the right stick must move before the camera responds.",
		"category": CAMERA_CATEGORY,
		"icon": "◎",
		"default": 0.18,
		"options": [
			{"value": 0.1, "label": "Small"},
			{"value": 0.18, "label": "Default"},
			{"value": 0.25, "label": "Large"},
			{"value": 0.32, "label": "Extra Large"},
		],
	},
	"focus_menu_camera": {
		"label": "Camera During Focus Menu",
		"description": "Allows the right stick to move the camera while the spell Focus menu is open.",
		"category": CAMERA_CATEGORY,
		"icon": "F",
		"default": false,
		"options": [
			{"value": false, "label": "Locked"},
			{"value": true, "label": "Enabled"},
		],
	},
	"camera_impact_scale": {
		"label": "Camera Impact",
		"description": "Scales landing and weapon-impact camera motion. Off never changes damage or timing.",
		"category": FEEDBACK_CATEGORY,
		"icon": "↯",
		"default": 1.0,
		"options": [
			{"value": 0.0, "label": "Off"},
			{"value": 0.5, "label": "Reduced"},
			{"value": 1.0, "label": "Full"},
		],
	},
	"motion_effect_scale": {
		"label": "Motion Pulses",
		"description": "Scales footstep, takeoff, landing, and climbing motion particles independently of gameplay.",
		"category": FEEDBACK_CATEGORY,
		"icon": "◌",
		"default": 1.0,
		"options": [
			{"value": 0.0, "label": "Off"},
			{"value": 0.5, "label": "Reduced"},
			{"value": 1.0, "label": "Full"},
		],
	},
}

@export var auto_save_changes: bool = true

var actor: CharacterBody3D
var weapon_controller: WeaponController
var motion_feedback: PlayerMotionFeedback

var values: Dictionary = {}
var initialized: bool = false
var loaded_from_disk: bool = false
var last_storage_result: String = "not_loaded"

var baseline_mouse_sensitivity: float = 0.0025
var baseline_controller_sensitivity: float = 3.0
var baseline_controller_deadzone: float = 0.18
var baseline_focus_menu_camera: bool = false
var baseline_weapon_camera_impact: float = 0.075


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("player_preference_service")
	add_to_group("debuggable")
	call_deferred("_initialize")


func _initialize() -> void:
	if initialized:
		return
	actor = get_parent() as CharacterBody3D
	if actor != null:
		weapon_controller = actor.get_node_or_null("WeaponController") as WeaponController
		motion_feedback = actor.get_node_or_null("PlayerMotionFeedback") as PlayerMotionFeedback
	_capture_baselines()
	_reset_values_to_defaults()
	initialized = true
	var load_result: Dictionary = load_preferences()
	_apply_to_player()
	preferences_loaded.emit(bool(load_result.get("loaded", false)))


func set_preference(
	preference_id: String,
	value: Variant,
	persist: bool = true
) -> Dictionary:
	_ensure_initialized()
	if not PREFERENCE_DEFINITIONS.has(preference_id):
		return {
			"ok": false,
			"error": "unknown preference",
			"id": preference_id,
		}
	var normalized: Variant = _normalize_value(preference_id, value)
	var previous: Variant = values.get(
		preference_id,
		_get_default_value(preference_id)
	)
	values[preference_id] = normalized
	_apply_to_player()
	if not _values_equal(previous, normalized):
		preference_changed.emit(preference_id, normalized)
	var storage: Dictionary = {}
	if persist and auto_save_changes:
		storage = save_preferences()
	return {
		"ok": true,
		"id": preference_id,
		"previous": previous,
		"value": normalized,
		"label": get_value_label(preference_id),
		"changed": not _values_equal(previous, normalized),
		"storage": storage,
	}


func cycle_preference(
	preference_id: String,
	direction: int = 1,
	persist: bool = true
) -> Dictionary:
	_ensure_initialized()
	if not PREFERENCE_DEFINITIONS.has(preference_id):
		return {
			"ok": false,
			"error": "unknown preference",
			"id": preference_id,
		}
	var options: Array = _get_options(preference_id)
	if options.is_empty():
		return {
			"ok": false,
			"error": "preference has no options",
			"id": preference_id,
		}
	var current_index: int = _find_option_index(
		preference_id,
		get_preference(preference_id)
	)
	if current_index < 0:
		current_index = _find_option_index(
			preference_id,
			_get_default_value(preference_id)
		)
	var step: int = 1 if direction >= 0 else -1
	var next_index: int = posmod(current_index + step, options.size())
	var option: Dictionary = options[next_index] as Dictionary
	return set_preference(preference_id, option.get("value"), persist)


func reset_defaults(persist: bool = true) -> Dictionary:
	_ensure_initialized()
	_reset_values_to_defaults()
	_apply_to_player()
	preferences_reset.emit()
	var storage: Dictionary = {}
	if persist and auto_save_changes:
		storage = save_preferences()
	return {
		"ok": true,
		"values": values.duplicate(true),
		"storage": storage,
	}


func get_preference(preference_id: String) -> Variant:
	_ensure_initialized()
	return values.get(preference_id, _get_default_value(preference_id))


func get_float(preference_id: String) -> float:
	return float(get_preference(preference_id))


func get_bool(preference_id: String) -> bool:
	return bool(get_preference(preference_id))


func get_value_label(preference_id: String) -> String:
	_ensure_initialized()
	var options: Array = _get_options(preference_id)
	var current: Variant = values.get(
		preference_id,
		_get_default_value(preference_id)
	)
	for option_variant: Variant in options:
		if not option_variant is Dictionary:
			continue
		var option: Dictionary = option_variant as Dictionary
		if _values_equal(option.get("value"), current):
			return str(option.get("label", current))
	return str(current)


func get_rows() -> Array[Dictionary]:
	_ensure_initialized()
	var rows: Array[Dictionary] = []
	for preference_id: String in PREFERENCE_IDS:
		var definition: Dictionary = (
			PREFERENCE_DEFINITIONS[preference_id] as Dictionary
		)
		var current: Variant = get_preference(preference_id)
		var default_value: Variant = _get_default_value(preference_id)
		rows.append({
			"id": preference_id,
			"label": str(definition.get("label", preference_id.capitalize())),
			"description": str(definition.get("description", "")),
			"category": str(definition.get("category", "Preferences")),
			"icon": str(definition.get("icon", "◇")),
			"value": current,
			"value_label": get_value_label(preference_id),
			"default": default_value,
			"is_default": _values_equal(current, default_value),
			"option_count": _get_options(preference_id).size(),
		})
	return rows


func get_summary() -> Dictionary:
	_ensure_initialized()
	var changed_count: int = 0
	for preference_id: String in PREFERENCE_IDS:
		if not _values_equal(
			get_preference(preference_id),
			_get_default_value(preference_id)
		):
			changed_count += 1
	return {
		"preference_count": PREFERENCE_IDS.size(),
		"changed_count": changed_count,
		"default_count": PREFERENCE_IDS.size() - changed_count,
		"scope": "user_profile",
		"auto_save": auto_save_changes,
		"loaded_from_disk": loaded_from_disk,
		"storage_result": last_storage_result,
	}


func capture_snapshot() -> Dictionary:
	_ensure_initialized()
	return {
		"version": SETTINGS_VERSION,
		"values": values.duplicate(true),
	}


func apply_snapshot(
	snapshot: Dictionary,
	persist: bool = false
) -> Dictionary:
	_ensure_initialized()
	_reset_values_to_defaults()
	var raw_values: Variant = snapshot.get("values", snapshot)
	if raw_values is Dictionary:
		var incoming: Dictionary = raw_values as Dictionary
		for preference_id: String in PREFERENCE_IDS:
			if incoming.has(preference_id):
				values[preference_id] = _normalize_value(
					preference_id,
					incoming[preference_id]
				)
	_apply_to_player()
	var storage: Dictionary = {}
	if persist and auto_save_changes:
		storage = save_preferences()
	return {
		"ok": true,
		"values": values.duplicate(true),
		"storage": storage,
	}


func save_preferences() -> Dictionary:
	_ensure_initialized()
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		last_storage_result = "write_failed"
		return {
			"ok": false,
			"error": str(FileAccess.get_open_error()),
			"path": SETTINGS_PATH,
		}
	file.store_string(JSON.stringify(capture_snapshot(), "\t"))
	file.close()
	last_storage_result = "saved"
	return {
		"ok": true,
		"path": SETTINGS_PATH,
	}


func load_preferences() -> Dictionary:
	_reset_values_to_defaults()
	loaded_from_disk = false
	if not FileAccess.file_exists(SETTINGS_PATH):
		last_storage_result = "defaults"
		_apply_to_player()
		return {
			"ok": true,
			"loaded": false,
			"path": SETTINGS_PATH,
		}
	var text: String = FileAccess.get_file_as_string(SETTINGS_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		last_storage_result = "invalid_json"
		_apply_to_player()
		return {
			"ok": false,
			"loaded": false,
			"error": "invalid settings JSON",
			"path": SETTINGS_PATH,
		}
	var raw_values: Variant = (parsed as Dictionary).get("values", {})
	if raw_values is Dictionary:
		var incoming: Dictionary = raw_values as Dictionary
		for preference_id: String in PREFERENCE_IDS:
			if incoming.has(preference_id):
				values[preference_id] = _normalize_value(
					preference_id,
					incoming[preference_id]
				)
	loaded_from_disk = true
	last_storage_result = "loaded"
	_apply_to_player()
	return {
		"ok": true,
		"loaded": true,
		"path": SETTINGS_PATH,
	}


func get_debug_data() -> Dictionary:
	_ensure_initialized()
	var summary: Dictionary = get_summary()
	summary["values"] = values.duplicate(true)
	summary["baseline_mouse_sensitivity"] = baseline_mouse_sensitivity
	summary["baseline_controller_sensitivity"] = baseline_controller_sensitivity
	summary["baseline_controller_deadzone"] = baseline_controller_deadzone
	summary["baseline_focus_menu_camera"] = baseline_focus_menu_camera
	summary["baseline_weapon_camera_impact"] = baseline_weapon_camera_impact
	summary["actor_ready"] = actor != null
	summary["weapon_ready"] = weapon_controller != null
	summary["motion_feedback_ready"] = motion_feedback != null
	return summary


func _capture_baselines() -> void:
	if actor != null:
		baseline_mouse_sensitivity = float(actor.get("mouse_sensitivity"))
		baseline_controller_sensitivity = float(
			actor.get("controller_camera_sensitivity")
		)
		baseline_controller_deadzone = float(
			actor.get("controller_camera_deadzone")
		)
		baseline_focus_menu_camera = bool(
			actor.get("allow_controller_camera_during_focus_menu")
		)
	if weapon_controller != null:
		baseline_weapon_camera_impact = weapon_controller.camera_impact_amount


func _apply_to_player() -> void:
	if actor != null:
		actor.set(
			"mouse_sensitivity",
			baseline_mouse_sensitivity * get_float("mouse_camera_scale")
		)
		actor.set(
			"controller_camera_sensitivity",
			baseline_controller_sensitivity * get_float("controller_camera_scale")
		)
		actor.set(
			"controller_camera_deadzone",
			get_float("controller_camera_deadzone")
		)
		actor.set(
			"allow_controller_camera_during_focus_menu",
			get_bool("focus_menu_camera")
		)
	var camera_scale: float = get_float("camera_impact_scale")
	if weapon_controller != null:
		weapon_controller.camera_impact_amount = (
			baseline_weapon_camera_impact * camera_scale
		)
	if motion_feedback != null:
		motion_feedback.visual_effect_scale = get_float("motion_effect_scale")
		motion_feedback.camera_impulse_scale = camera_scale


func _ensure_initialized() -> void:
	if not initialized:
		_initialize()


func _reset_values_to_defaults() -> void:
	values.clear()
	for preference_id: String in PREFERENCE_IDS:
		values[preference_id] = _get_default_value(preference_id)


func _get_default_value(preference_id: String) -> Variant:
	if not PREFERENCE_DEFINITIONS.has(preference_id):
		return null
	var definition: Dictionary = (
		PREFERENCE_DEFINITIONS[preference_id] as Dictionary
	)
	return definition.get("default")


func _get_options(preference_id: String) -> Array:
	if not PREFERENCE_DEFINITIONS.has(preference_id):
		return []
	var definition: Dictionary = (
		PREFERENCE_DEFINITIONS[preference_id] as Dictionary
	)
	var options: Variant = definition.get("options", [])
	return options as Array if options is Array else []


func _normalize_value(preference_id: String, candidate: Variant) -> Variant:
	var options: Array = _get_options(preference_id)
	for option_variant: Variant in options:
		if not option_variant is Dictionary:
			continue
		var option: Dictionary = option_variant as Dictionary
		var option_value: Variant = option.get("value")
		if _values_equal(option_value, candidate):
			return option_value
	if candidate is float or candidate is int:
		var target: float = float(candidate)
		var best_distance: float = INF
		var best_value: Variant = _get_default_value(preference_id)
		for option_variant: Variant in options:
			if not option_variant is Dictionary:
				continue
			var option: Dictionary = option_variant as Dictionary
			var option_value: Variant = option.get("value")
			if not (option_value is float or option_value is int):
				continue
			var distance: float = absf(float(option_value) - target)
			if distance < best_distance:
				best_distance = distance
				best_value = option_value
		return best_value
	return _get_default_value(preference_id)


func _find_option_index(preference_id: String, value: Variant) -> int:
	var options: Array = _get_options(preference_id)
	for index: int in range(options.size()):
		var option_variant: Variant = options[index]
		if not option_variant is Dictionary:
			continue
		if _values_equal((option_variant as Dictionary).get("value"), value):
			return index
	return -1


func _values_equal(left: Variant, right: Variant) -> bool:
	if (left is float or left is int) and (right is float or right is int):
		return is_equal_approx(float(left), float(right))
	return left == right
