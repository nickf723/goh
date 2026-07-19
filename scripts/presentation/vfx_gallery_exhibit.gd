extends Node3D
class_name VfxGalleryExhibit

signal preview_triggered(exhibit_id: String, effect_kind: String, intensity: float)

var exhibit_id: String = ""
var element_id: String = ""
var display_name: String = ""
var description: String = ""
var effect_kinds: Array[String] = []
var accent_color: Color = Color.WHITE
var auto_play: bool = false
var auto_interval_seconds: float = 1.5
var current_kind_index: int = 0
var trigger_count: int = 0
var last_effect_kind: String = ""
var trigger_callback: Callable
var auto_timer: float = 0.0


func _ready() -> void:
	add_to_group("vfx_gallery_exhibits")
	add_to_group("debuggable")
	add_to_group("lab_resettable")


func configure(
	next_exhibit_id: String,
	next_element_id: String,
	next_display_name: String,
	next_description: String,
	next_effect_kinds: Array[String],
	next_accent_color: Color,
	next_trigger_callback: Callable
) -> void:
	exhibit_id = next_exhibit_id
	element_id = next_element_id
	display_name = next_display_name
	description = next_description
	effect_kinds = next_effect_kinds.duplicate()
	accent_color = next_accent_color
	trigger_callback = next_trigger_callback
	current_kind_index = 0
	auto_timer = max(auto_interval_seconds, 0.1)


func _process(delta: float) -> void:
	if not auto_play or effect_kinds.is_empty():
		return
	auto_timer -= max(delta, 0.0)
	if auto_timer > 0.0:
		return
	auto_timer = max(auto_interval_seconds, 0.1)
	trigger_preview(1.0)


func get_current_kind() -> String:
	if effect_kinds.is_empty():
		return ""
	current_kind_index = posmod(current_kind_index, effect_kinds.size())
	return effect_kinds[current_kind_index]


func cycle_kind(direction: int = 1) -> String:
	if effect_kinds.is_empty():
		return ""
	current_kind_index = posmod(current_kind_index + direction, effect_kinds.size())
	return get_current_kind()


func trigger_preview(intensity: float = 1.0) -> bool:
	var effect_kind: String = get_current_kind()
	if effect_kind.is_empty() or not trigger_callback.is_valid():
		return false
	var accepted: Variant = trigger_callback.call(self, effect_kind, max(intensity, 0.05))
	if accepted is bool and not bool(accepted):
		return false
	trigger_count += 1
	last_effect_kind = effect_kind
	preview_triggered.emit(exhibit_id, effect_kind, intensity)
	return true


func set_auto_play(next_enabled: bool) -> void:
	auto_play = next_enabled
	auto_timer = max(auto_interval_seconds, 0.1)


func reset_target() -> void:
	auto_play = false
	auto_timer = max(auto_interval_seconds, 0.1)
	current_kind_index = 0
	trigger_count = 0
	last_effect_kind = ""


func get_debug_data() -> Dictionary:
	return {
		"vfx_gallery_exhibit": true,
		"exhibit_id": exhibit_id,
		"element_id": element_id,
		"display_name": display_name,
		"effect_kind": get_current_kind(),
		"effect_kinds": effect_kinds,
		"auto_play": auto_play,
		"auto_interval_seconds": auto_interval_seconds,
		"trigger_count": trigger_count,
		"last_effect_kind": last_effect_kind,
	}
