extends Area3D
class_name PerceptionNoiseBeacon

@export var prompt_text: String = "Trigger noise"
@export var message_text: String = "The beacon releases a sharp metallic chime."
@export var stimulus_category: String = "distraction"
@export var stimulus_display_name: String = "Noise beacon"
@export_range(0.5, 40.0, 0.25) var loudness: float = 13.0
@export_range(0.1, 4.0, 0.05) var stimulus_duration: float = 1.25
@export_range(0.1, 4.0, 0.05) var priority: float = 1.2
@export_range(0.0, 10.0, 0.1) var cooldown: float = 1.0
@export var stimulus_offset: Vector3 = Vector3.ZERO

var manager: PerceptionStimulusManager = null
var cooldown_timer: float = 0.0
var trigger_count: int = 0


func _ready() -> void:
	add_to_group("interactable_target")
	add_to_group("perception_emitters")
	add_to_group("debuggable")
	manager = get_tree().get_first_node_in_group("perception_stimulus_manager") as PerceptionStimulusManager


func _process(delta: float) -> void:
	cooldown_timer = max(cooldown_timer - max(delta, 0.0), 0.0)


func interact() -> Dictionary:
	if cooldown_timer > 0.0:
		return {
			"message": "The beacon is still resonating.",
			"objective": "",
		}
	resolve_manager()
	if manager != null:
		manager.emit_stimulus(
			global_position + global_transform.basis * stimulus_offset,
			loudness,
			stimulus_category,
			stimulus_duration,
			self,
			stimulus_display_name,
			priority,
			["distraction", "authored"]
		)
	cooldown_timer = cooldown
	trigger_count += 1
	pulse_visuals()
	return {
		"message": message_text,
		"objective": "Watch which enemies investigate the sound instead of Grace.",
	}


func resolve_manager() -> void:
	if manager == null or not is_instance_valid(manager):
		manager = get_tree().get_first_node_in_group("perception_stimulus_manager") as PerceptionStimulusManager


func pulse_visuals() -> void:
	var visual: Node3D = get_node_or_null("Visual") as Node3D
	if visual == null:
		return
	visual.scale = Vector3.ONE
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "scale", Vector3.ONE * 1.28, 0.08)
	tween.tween_property(visual, "scale", Vector3.ONE, 0.18)


func reset_target() -> void:
	cooldown_timer = 0.0
	trigger_count = 0


func get_debug_data() -> Dictionary:
	return {
		"perception_noise_beacon": true,
		"triggers": trigger_count,
		"cooldown": snapped(cooldown_timer, 0.01),
		"loudness": loudness,
	}
