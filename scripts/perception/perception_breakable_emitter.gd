extends Node
class_name PerceptionBreakableEmitter

@export_range(0.5, 30.0, 0.25) var crack_loudness: float = 7.0
@export_range(0.5, 40.0, 0.25) var break_loudness: float = 15.0
@export var crack_display_name: String = "Cracking object"
@export var break_display_name: String = "Breaking object"
@export var enabled: bool = true

var breakable: Node3D = null
var manager: PerceptionStimulusManager = null


func _ready() -> void:
	breakable = get_parent() as Node3D
	manager = get_tree().get_first_node_in_group("perception_stimulus_manager") as PerceptionStimulusManager
	add_to_group("perception_emitters")
	connect_breakable_signals()


func connect_breakable_signals() -> void:
	if breakable == null:
		return
	var cracked_callable := Callable(self, "_on_cracked")
	var broken_callable := Callable(self, "_on_broken")
	if breakable.has_signal("cracked") and not breakable.is_connected("cracked", cracked_callable):
		breakable.connect("cracked", cracked_callable)
	if breakable.has_signal("broken") and not breakable.is_connected("broken", broken_callable):
		breakable.connect("broken", broken_callable)


func _on_cracked() -> void:
	emit_noise(crack_loudness, "impact", crack_display_name, 0.85)


func _on_broken() -> void:
	emit_noise(break_loudness, "break", break_display_name, 1.35)


func emit_noise(loudness: float, category: String, display_name: String, priority: float) -> void:
	if not enabled or breakable == null:
		return
	resolve_manager()
	if manager == null:
		return
	manager.emit_stimulus(
		breakable.global_position,
		loudness,
		category,
		1.25,
		breakable,
		display_name,
		priority,
		["impact", "prop", "breakable"]
	)


func resolve_manager() -> void:
	if manager == null or not is_instance_valid(manager):
		manager = get_tree().get_first_node_in_group("perception_stimulus_manager") as PerceptionStimulusManager
