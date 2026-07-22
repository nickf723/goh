extends Node3D
class_name AirflowTurbine

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")

@export var local_capture_axis: Vector3 = Vector3.RIGHT
@export var response_speed: float = 4.5
@export var rotation_scale: float = 0.7
@export var maximum_rotation_speed: float = 18.0
@export var show_readout: bool = true

var airflow_manager: Node = null
var rotor: Node3D = null
var readout: Label3D = null
var angular_speed: float = 0.0
var total_rotation: float = 0.0
var last_air_velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group("lab_resettable")
	add_to_group("debuggable")
	build_visuals()


func _process(delta: float) -> void:
	var manager: Node = resolve_manager()
	last_air_velocity = Vector3.ZERO
	if manager != null and manager.has_method("sample_total_airflow"):
		var sampled_value: Variant = manager.call("sample_total_airflow", global_position + Vector3.UP * 1.7)
		if sampled_value is Vector3:
			last_air_velocity = sampled_value as Vector3
	var capture_axis: Vector3 = global_transform.basis * local_capture_axis.normalized()
	var captured_speed: float = last_air_velocity.dot(capture_axis)
	var target_speed: float = clampf(captured_speed * rotation_scale, -maximum_rotation_speed, maximum_rotation_speed)
	angular_speed = move_toward(angular_speed, target_speed, response_speed * max(delta, 0.0))
	total_rotation += angular_speed * delta
	if rotor != null:
		rotor.rotation.x = total_rotation
	update_readout(captured_speed)


func resolve_manager() -> Node:
	if airflow_manager != null and is_instance_valid(airflow_manager):
		return airflow_manager
	airflow_manager = get_tree().get_first_node_in_group("airflow_manager")
	return airflow_manager


func build_visuals() -> void:
	ElementVisuals.add_box(self, "Stand", Vector3(0.55, 3.4, 0.55), Color(0.16, 0.2, 0.27, 1.0), Vector3(0.0, 1.7, 0.0), Vector3.ZERO, 0.1, 1.0)
	rotor = Node3D.new()
	rotor.name = "Rotor"
	rotor.position = Vector3(0.0, 3.2, 0.0)
	add_child(rotor)
	ElementVisuals.add_capsule(rotor, "Hub", 0.28, 0.7, Color(0.48, 0.72, 0.92, 1.0), Vector3.ZERO, Vector3.ONE, Vector3(0.0, 0.0, 90.0), 1.2, 1.0)
	for index: int in range(4):
		var blade_root := Node3D.new()
		blade_root.name = "BladeRoot" + str(index)
		blade_root.rotation.x = TAU * float(index) / 4.0
		rotor.add_child(blade_root)
		ElementVisuals.add_box(
			blade_root,
			"Blade",
			Vector3(0.16, 1.5, 0.48),
			Color(0.34, 0.68, 0.92, 1.0),
			Vector3(0.0, 0.95, 0.0),
			Vector3(0.0, 0.0, 12.0),
			0.85,
			0.9
		)

	if show_readout:
		readout = Label3D.new()
		readout.name = "TurbineReadout"
		readout.position = Vector3(0.0, 4.6, 0.0)
		readout.font_size = 26
		readout.pixel_size = 0.006
		readout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		readout.outline_size = 5
		add_child(readout)


func update_readout(captured_speed: float) -> void:
	if readout == null:
		return
	readout.text = (
		"AIR TURBINE\nWind " + str(snapped(captured_speed, 0.1)) + " m/s"
		+ "  •  Rotor " + str(snapped(angular_speed, 0.1)) + " rad/s"
	)
	readout.modulate = Color(0.56, 0.9, 1.0, 1.0) if abs(angular_speed) > 0.1 else Color(0.56, 0.62, 0.7, 1.0)


func reset_target() -> void:
	angular_speed = 0.0
	total_rotation = 0.0
	last_air_velocity = Vector3.ZERO
	if rotor != null:
		rotor.rotation = Vector3.ZERO


func get_debug_data() -> Dictionary:
	return {
		"airflow_turbine": true,
		"air_velocity": last_air_velocity,
		"angular_speed": snapped(angular_speed, 0.01),
		"total_rotation": snapped(total_rotation, 0.01),
	}
