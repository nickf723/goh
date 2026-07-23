extends CharacterBody3D
class_name WhipPullSwitch

signal switch_pulled()

@export var switch_label: String = "REMOTE PULL RING"
@export_range(0.0, 90.0, 1.0) var pulled_rotation_degrees: float = 62.0

@onready var lever_pivot: Node3D = get_node_or_null("LeverPivot")
@onready var name_label: Label3D = get_node_or_null("NameLabel")

var pulled: bool = false
var pull_count: int = 0


func _ready() -> void:
	add_to_group("combat_arena_resettable")
	add_to_group("whip_pull_targets")
	add_to_group("debuggable")
	if name_label != null:
		name_label.text = switch_label + "\nLIGHT → HEAVY TO PULL"
	_update_visual()


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	return {
		"message": (
			payload.source_name + " catches " + switch_label + "."
			if payload != null
			else "The whip catches " + switch_label + "."
		),
		"objective": "",
	}


func receive_whip_pull(_strength: float, _source: Node3D = null) -> void:
	if pulled:
		return
	pulled = true
	pull_count += 1
	_update_visual()
	switch_pulled.emit()


func reset_target() -> void:
	pulled = false
	pull_count = 0
	_update_visual()


func _update_visual() -> void:
	if lever_pivot != null:
		lever_pivot.rotation_degrees.x = pulled_rotation_degrees if pulled else 0.0
	if name_label != null:
		name_label.modulate = Color(0.4, 1.0, 0.7, 1.0) if pulled else Color(0.9, 0.54, 1.0, 1.0)
		name_label.text = (
			switch_label + "\nPULLED"
			if pulled
			else switch_label + "\nLIGHT → HEAVY TO PULL"
		)


func get_debug_data() -> Dictionary:
	return {
		"whip_pull_switch": true,
		"pulled": pulled,
		"pull_count": pull_count,
	}
