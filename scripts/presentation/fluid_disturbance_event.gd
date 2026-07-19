extends RefCounted
class_name FluidDisturbanceEvent

const KIND_RIPPLE: String = "ripple"
const KIND_ENTRY: String = "entry"
const KIND_IMPACT: String = "impact"
const KIND_WAKE: String = "wake"
const KIND_CHURN: String = "churn"
const KIND_BUBBLE: String = "bubble"
const KIND_BOIL: String = "boil"
const KIND_ELECTRICAL: String = "electrical"

var kind: String = KIND_RIPPLE
var world_position: Vector3 = Vector3.ZERO
var direction: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var strength: float = 1.0
var radius: float = 0.5
var source_id: String = "unknown"
var tint: Color = Color.WHITE
var tags: Array[String] = []
var metadata: Dictionary = {}


static func make(
	next_kind: String,
	next_position: Vector3,
	next_direction: Vector3 = Vector3.ZERO,
	next_velocity: Vector3 = Vector3.ZERO,
	next_strength: float = 1.0,
	next_radius: float = 0.5,
	next_source_id: String = "unknown",
	next_tags: Array[String] = []
) -> FluidDisturbanceEvent:
	var event := FluidDisturbanceEvent.new()
	event.kind = next_kind if next_kind != "" else KIND_RIPPLE
	event.world_position = next_position
	event.direction = next_direction
	event.velocity = next_velocity
	event.strength = clampf(next_strength, 0.0, 12.0)
	event.radius = clampf(next_radius, 0.05, 12.0)
	event.source_id = next_source_id if next_source_id != "" else "unknown"
	event.tags = next_tags.duplicate()
	return event


func get_horizontal_direction(fallback: Vector3 = Vector3.FORWARD) -> Vector3:
	var horizontal := Vector3(direction.x, 0.0, direction.z)
	if horizontal.length() <= 0.001:
		horizontal = Vector3(velocity.x, 0.0, velocity.z)
	if horizontal.length() <= 0.001:
		horizontal = Vector3(fallback.x, 0.0, fallback.z)
	if horizontal.length() <= 0.001:
		return Vector3.FORWARD
	return horizontal.normalized()


func has_tag(tag: String) -> bool:
	return tags.has(tag)


func is_finite_event() -> bool:
	return (
		is_finite(world_position.x)
		and is_finite(world_position.y)
		and is_finite(world_position.z)
		and is_finite(direction.x)
		and is_finite(direction.y)
		and is_finite(direction.z)
		and is_finite(velocity.x)
		and is_finite(velocity.y)
		and is_finite(velocity.z)
		and is_finite(strength)
		and is_finite(radius)
	)


func get_debug_data() -> Dictionary:
	return {
		"kind": kind,
		"position": world_position,
		"direction": direction,
		"velocity": velocity,
		"strength": snapped(strength, 0.01),
		"radius": snapped(radius, 0.01),
		"source_id": source_id,
		"tags": tags.duplicate(),
		"metadata": metadata.duplicate(true),
	}
