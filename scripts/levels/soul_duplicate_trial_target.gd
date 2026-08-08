extends StaticBody3D
class_name SoulDuplicateTrialTarget

signal hit_received(payload: DamagePayload, hit_count: int)

@export var display_name: String = "Soul Trial Target"
@export_range(1, 999, 1) var maximum_health: int = 100

var health: int = 100
var hit_count: int = 0
var grace_hit_count: int = 0
var duplicate_hit_count: int = 0
var last_source_name: String = "none"
var last_tags: Array[String] = []


func _ready() -> void:
	health = maximum_health
	add_to_group("soul_duplicate_trial_targets")
	add_to_group("debuggable")


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if payload == null:
		return {"received": false}
	hit_count += 1
	health = maxi(health - maxi(payload.amount, 0), 0)
	last_source_name = payload.source_name
	last_tags = payload.tags.duplicate()
	if payload.tags.has("duplicate") or payload.tags.has("live_clone"):
		duplicate_hit_count += 1
	else:
		grace_hit_count += 1
	hit_received.emit(payload, hit_count)
	return {
		"received": true,
		"damage": payload.amount,
		"health": health,
		"duplicate": payload.tags.has("duplicate") or payload.tags.has("live_clone"),
	}


func reset_target() -> void:
	health = maximum_health
	hit_count = 0
	grace_hit_count = 0
	duplicate_hit_count = 0
	last_source_name = "none"
	last_tags.clear()


func get_debug_data() -> Dictionary:
	return {
		"duplicate_trial_target": true,
		"health": health,
		"hits": hit_count,
		"grace_hits": grace_hit_count,
		"duplicate_hits": duplicate_hit_count,
		"last_source": last_source_name,
		"last_tags": last_tags,
	}
