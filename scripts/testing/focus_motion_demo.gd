extends Node3D
class_name FocusMotionDemo

@export var orbit_radius: float = 3.2
@export var orbit_speed: float = 1.8
@export var vertical_amplitude: float = 0.45
@export var vertical_speed: float = 2.4

var elapsed: float = 0.0


func _ready() -> void:
	add_to_group("debuggable")


func _process(delta: float) -> void:
	elapsed += delta
	var children: Array[Node] = get_children()
	var count: int = max(children.size(), 1)

	for index: int in range(children.size()):
		var child: Node = children[index]
		if not child is Node3D:
			continue

		var angle: float = elapsed * orbit_speed + TAU * float(index) / float(count)
		var y_offset: float = sin(elapsed * vertical_speed + float(index)) * vertical_amplitude
		(child as Node3D).position = Vector3(
			cos(angle) * orbit_radius,
			1.3 + y_offset,
			sin(angle) * orbit_radius
		)


func reset_demo() -> void:
	elapsed = 0.0


func get_debug_data() -> Dictionary:
	return {
		"elapsed": snapped(elapsed, 0.01),
		"time_scale": snapped(Engine.time_scale, 0.01),
		"orbs": get_child_count(),
	}
