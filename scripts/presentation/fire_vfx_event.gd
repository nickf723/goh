extends RefCounted
class_name FireVfxEvent

const KIND_IGNITION: String = "ignition"
const KIND_FLAME: String = "flame"
const KIND_BURST: String = "burst"
const KIND_SMOLDER: String = "smolder"
const KIND_EXTINGUISH: String = "extinguish"
const KIND_PROJECTILE: String = "projectile"

var kind: String = KIND_FLAME
var world_position: Vector3 = Vector3.ZERO
var direction: Vector3 = Vector3.UP
var intensity: float = 1.0
var radius: float = 0.5
var temperature_c: float = 600.0
var smoke_strength: float = 0.5
var ember_strength: float = 0.4
var wind_velocity: Vector3 = Vector3.ZERO
var duration_seconds: float = 1.2
var event_seed: int = 1
var source_id: String = "unknown"
var tags: Array[String] = []
var metadata: Dictionary = {}


static func make(
	next_kind: String,
	next_position: Vector3,
	next_intensity: float = 1.0,
	next_radius: float = 0.5,
	next_source_id: String = "unknown",
	next_tags: Array[String] = []
) -> FireVfxEvent:
	var event := FireVfxEvent.new()
	event.kind = next_kind if next_kind != "" else KIND_FLAME
	event.world_position = next_position
	event.intensity = clampf(next_intensity, 0.0, 5.0)
	event.radius = clampf(next_radius, 0.05, 8.0)
	event.source_id = next_source_id if next_source_id != "" else "unknown"
	event.tags = next_tags.duplicate()
	return event


func is_finite_event() -> bool:
	return (
		world_position.is_finite()
		and direction.is_finite()
		and wind_velocity.is_finite()
		and is_finite(intensity)
		and is_finite(radius)
		and is_finite(temperature_c)
		and is_finite(smoke_strength)
		and is_finite(ember_strength)
		and is_finite(duration_seconds)
	)


func sanitize() -> void:
	if direction.length() <= 0.001:
		direction = Vector3.UP
	else:
		direction = direction.normalized()
	intensity = clampf(intensity, 0.0, 5.0)
	radius = clampf(radius, 0.05, 8.0)
	temperature_c = clampf(temperature_c, -273.15, 2500.0)
	smoke_strength = clampf(smoke_strength, 0.0, 3.0)
	ember_strength = clampf(ember_strength, 0.0, 3.0)
	duration_seconds = clampf(duration_seconds, 0.05, 20.0)
	if event_seed == 0:
		event_seed = 1


func duplicate_event() -> FireVfxEvent:
	var copy := FireVfxEvent.new()
	copy.kind = kind
	copy.world_position = world_position
	copy.direction = direction
	copy.intensity = intensity
	copy.radius = radius
	copy.temperature_c = temperature_c
	copy.smoke_strength = smoke_strength
	copy.ember_strength = ember_strength
	copy.wind_velocity = wind_velocity
	copy.duration_seconds = duration_seconds
	copy.event_seed = event_seed
	copy.source_id = source_id
	copy.tags = tags.duplicate()
	copy.metadata = metadata.duplicate(true)
	return copy


func get_debug_data() -> Dictionary:
	return {
		"kind": kind,
		"position": world_position,
		"direction": direction,
		"intensity": snapped(intensity, 0.01),
		"radius": snapped(radius, 0.01),
		"temperature_c": snapped(temperature_c, 0.1),
		"smoke": snapped(smoke_strength, 0.01),
		"embers": snapped(ember_strength, 0.01),
		"wind": wind_velocity,
		"duration": snapped(duration_seconds, 0.01),
		"seed": event_seed,
		"source_id": source_id,
		"tags": tags.duplicate(),
	}
