extends Resource
class_name ResonancePayload

@export var source_name: String = "Resonant Pulse"
@export_range(20.0, 2000.0, 1.0) var frequency_hz: float = 220.0
@export_range(0.1, 100.0, 0.1) var energy: float = 18.0
@export_range(0.5, 30.0, 0.25) var radius: float = 9.0
@export_range(0.0, 1.0, 0.01) var minimum_distance_factor: float = 0.15
@export var tags: Array[String] = [
	"sound",
	"resonance",
	"frequency",
	"pulse",
]


func duplicate_with_frequency(new_frequency_hz: float) -> ResonancePayload:
	var result: ResonancePayload = duplicate(true) as ResonancePayload
	result.frequency_hz = maxf(new_frequency_hz, 1.0)
	return result


func get_distance_factor(distance: float) -> float:
	if radius <= 0.0 or distance > radius:
		return 0.0
	var normalized_distance: float = clampf(distance / radius, 0.0, 1.0)
	return lerpf(1.0, minimum_distance_factor, normalized_distance)

