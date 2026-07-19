extends Area3D
class_name RotationalConveyorDrive

signal coupling_changed(is_coupled: bool)

@export var starts_coupled: bool = true
@export var track_length: float = 5.0
@export var revolutions_per_track_length: float = 4.0
@export var starting_track_offset: float = 0.5

var shaft: RotationalShaftState
var carriage: Node3D
var coupled: bool = true
var track_offset: float = 0.0
var last_shaft_revolutions: float = 0.0
var carriage_initial_position: Vector3 = Vector3.ZERO
var total_distance_moved: float = 0.0


func _ready() -> void:
	coupled = starts_coupled
	track_offset = clampf(starting_track_offset, 0.0, max(track_length, 0.01))
	if carriage != null:
		carriage_initial_position = carriage.position
	if shaft != null:
		last_shaft_revolutions = shaft.total_revolutions
	add_to_group("debuggable")
	add_to_group("lab_resettable")
	update_carriage_position()


func _process(_delta: float) -> void:
	step_drive()


func configure(next_shaft: RotationalShaftState, next_carriage: Node3D) -> void:
	shaft = next_shaft
	carriage = next_carriage
	if carriage != null:
		carriage_initial_position = carriage.position
	if shaft != null:
		last_shaft_revolutions = shaft.total_revolutions
	update_carriage_position()


func step_drive() -> float:
	if shaft == null:
		return 0.0
	var revolution_delta: float = shaft.total_revolutions - last_shaft_revolutions
	last_shaft_revolutions = shaft.total_revolutions
	if not coupled or is_zero_approx(revolution_delta):
		return 0.0
	var safe_revolutions: float = max(revolutions_per_track_length, 0.01)
	var distance_delta: float = revolution_delta / safe_revolutions * max(track_length, 0.01)
	track_offset = fposmod(track_offset + distance_delta, max(track_length, 0.01))
	total_distance_moved += absf(distance_delta)
	update_carriage_position()
	return distance_delta


func update_carriage_position() -> void:
	if carriage == null:
		return
	var length: float = max(track_length, 0.01)
	carriage.position = carriage_initial_position + Vector3(track_offset - length * 0.5, 0.0, 0.0)


func set_coupled(next_coupled: bool) -> void:
	if coupled == next_coupled:
		return
	coupled = next_coupled
	if shaft != null:
		last_shaft_revolutions = shaft.total_revolutions
	coupling_changed.emit(coupled)


func interact() -> Dictionary:
	set_coupled(not coupled)
	return {
		"message": "Conveyor clutch " + ("engaged." if coupled else "disengaged."),
		"objective": "Compare motor rotation with and without mechanical work attached.",
	}


func reset_target() -> void:
	coupled = starts_coupled
	track_offset = clampf(starting_track_offset, 0.0, max(track_length, 0.01))
	total_distance_moved = 0.0
	if shaft != null:
		last_shaft_revolutions = shaft.total_revolutions
	update_carriage_position()
	coupling_changed.emit(coupled)


func get_debug_data() -> Dictionary:
	return {
		"rotational_conveyor": true,
		"coupled": coupled,
		"shaft_rpm": snapped(shaft.current_rpm, 0.1) if shaft != null else 0.0,
		"track_offset": snapped(track_offset, 0.01),
		"total_distance_moved": snapped(total_distance_moved, 0.01),
	}
