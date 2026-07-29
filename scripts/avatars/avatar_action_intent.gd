extends RefCounted
class_name AvatarActionIntent

var movement_direction: Vector3 = Vector3.ZERO
var movement_strength: float = 0.0
var facing_direction: Vector3 = Vector3.ZERO
var target: Node3D
var attack_id: String = ""
var spell_id: String = ""
var dodge_requested: bool = false
var dodge_direction: Vector3 = Vector3.ZERO
var dodge_kind: String = "side"
var guard_requested: bool = false
var recall_requested: bool = false
var decision_tag: String = "idle"
var action_reason: String = ""


func clear() -> void:
	movement_direction = Vector3.ZERO
	movement_strength = 0.0
	facing_direction = Vector3.ZERO
	target = null
	attack_id = ""
	spell_id = ""
	dodge_requested = false
	dodge_direction = Vector3.ZERO
	dodge_kind = "side"
	guard_requested = false
	recall_requested = false
	decision_tag = "idle"
	action_reason = ""


func set_movement(direction: Vector3, strength: float = 1.0) -> void:
	var planar: Vector3 = direction
	planar.y = 0.0
	movement_strength = clampf(strength, 0.0, 1.0)
	movement_direction = (
		planar.normalized()
		if planar.length_squared() > 0.0001 and movement_strength > 0.0
		else Vector3.ZERO
	)


func set_facing(direction: Vector3) -> void:
	var planar: Vector3 = direction
	planar.y = 0.0
	facing_direction = (
		planar.normalized()
		if planar.length_squared() > 0.0001
		else Vector3.ZERO
	)


func has_action_request() -> bool:
	return (
		attack_id != ""
		or spell_id != ""
		or dodge_requested
		or guard_requested
		or recall_requested
	)


func copy_from(other: AvatarActionIntent) -> void:
	clear()
	if other == null:
		return
	movement_direction = other.movement_direction
	movement_strength = other.movement_strength
	facing_direction = other.facing_direction
	target = other.target
	attack_id = other.attack_id
	spell_id = other.spell_id
	dodge_requested = other.dodge_requested
	dodge_direction = other.dodge_direction
	dodge_kind = other.dodge_kind
	guard_requested = other.guard_requested
	recall_requested = other.recall_requested
	decision_tag = other.decision_tag
	action_reason = other.action_reason


func get_debug_data() -> Dictionary:
	return {
		"movement_direction": movement_direction,
		"movement_strength": snappedf(movement_strength, 0.01),
		"facing_direction": facing_direction,
		"target": (
			target.name
			if target != null and is_instance_valid(target)
			else "none"
		),
		"attack": attack_id if attack_id != "" else "none",
		"spell": spell_id if spell_id != "" else "none",
		"dodge": dodge_requested,
		"dodge_direction": dodge_direction,
		"dodge_kind": dodge_kind,
		"guard": guard_requested,
		"recall": recall_requested,
		"decision": decision_tag,
		"reason": action_reason,
	}
