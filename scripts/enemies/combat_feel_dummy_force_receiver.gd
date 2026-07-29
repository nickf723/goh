extends Node
class_name CombatFeelDummyForceReceiver

var total_impulses: int = 0
var last_source: String = "none"
var last_strength: float = 0.0
var last_up_strength: float = 0.0


func _ready() -> void:
	add_to_group("force_receivers")
	add_to_group("debuggable")


func apply_impulse(
	direction: Vector3,
	strength: float,
	up_strength: float = 0.0,
	source_name: String = "Force"
) -> void:
	var dummy: CombatFeelDummy = get_parent() as CombatFeelDummy
	if dummy == null:
		return
	var planar: Vector3 = direction
	planar.y = 0.0
	if planar.length_squared() <= 0.0001:
		planar = Vector3.BACK
	var resolved_strength: float = maxf(strength, 0.0)
	var resolved_up: float = maxf(up_strength, 0.0)
	dummy.recoil_velocity += planar.normalized() * resolved_strength
	if resolved_up > 0.0:
		dummy.velocity.y = maxf(dummy.velocity.y, resolved_up)
	total_impulses += 1
	last_source = source_name
	last_strength = resolved_strength
	last_up_strength = resolved_up


func get_debug_data() -> Dictionary:
	return {
		"total_impulses": total_impulses,
		"last_source": last_source,
		"last_strength": snappedf(last_strength, 0.01),
		"last_up_strength": snappedf(last_up_strength, 0.01),
	}
