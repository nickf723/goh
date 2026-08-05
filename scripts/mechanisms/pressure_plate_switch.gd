extends CircuitSwitch
class_name PressurePlateSwitch

signal pressed_changed(is_pressed: bool)
signal mechanism_signal_changed(mechanism_id: String, active: bool, packet: Dictionary)
signal mechanism_value_changed(value: float, packet: Dictionary)

@export_group("Detection")
@export var accept_any_physics_body: bool = true
@export var accepted_group: String = "player"

@export_group("Weight Value")
@export_range(0.0, 1000.0, 0.1) var default_non_rigid_body_mass_kg: float = 70.0
@export_range(0.1, 10000.0, 0.1) var maximum_reported_mass_kg: float = 100.0
@export_range(0.0001, 1.0, 0.0001) var mass_change_epsilon: float = 0.001
@export var show_weight_in_label: bool = true

@export_group("Presentation")
@export_range(0.01, 0.4, 0.01) var depress_distance: float = 0.13
@export_range(0.02, 1.0, 0.01) var animation_seconds: float = 0.12
@export var plate_visual_path: NodePath = NodePath("PlateVisual")
@export var current_glow_path: NodePath = NodePath("CurrentGlow")
@export var state_label_path: NodePath = NodePath("StateLabel")

var plate_visual: Node3D = null
var current_glow: Node3D = null
var state_label: Label3D = null
var plate_up_position: Vector3 = Vector3.ZERO
var occupying_bodies: Dictionary = {}
var is_pressed: bool = false
var measured_mass_kg: float = 0.0
var plate_tween: Tween = null
var last_mechanism_packet: Dictionary = {}


func _ready() -> void:
	starts_closed = false
	super._ready()
	add_to_group("lab_resettable")
	add_to_group("mechanism_inputs")
	add_to_group("mechanism_value_sources")
	plate_visual = get_node_or_null(plate_visual_path) as Node3D
	current_glow = get_node_or_null(current_glow_path) as Node3D
	state_label = get_node_or_null(state_label_path) as Label3D
	if plate_visual != null:
		plate_up_position = plate_visual.position

	connect_body_detection_signals()
	_set_plate_state(false, 0.0, true, true)
	refresh_energized_visual()


func connect_body_detection_signals() -> void:
	var entered_callback: Callable = Callable(self, "_on_body_entered")
	var exited_callback: Callable = Callable(self, "_on_body_exited")

	if has_signal("body_entered") and not is_connected("body_entered", entered_callback):
		connect("body_entered", entered_callback)
	if has_signal("body_exited") and not is_connected("body_exited", exited_callback):
		connect("body_exited", exited_callback)


func _on_body_entered(body: Node3D) -> void:
	if not accepts_body(body):
		return
	occupying_bodies[body.get_instance_id()] = body
	refresh_pressed_state()


func _on_body_exited(body: Node3D) -> void:
	occupying_bodies.erase(body.get_instance_id())
	refresh_pressed_state()


func accepts_body(body: Node3D) -> bool:
	if body == null:
		return false
	if accept_any_physics_body and body is PhysicsBody3D:
		return true
	return accepted_group != "" and body.is_in_group(accepted_group)


func refresh_pressed_state() -> void:
	var stale_ids: Array = []
	for raw_id: Variant in occupying_bodies.keys():
		var body: Node = occupying_bodies[raw_id] as Node
		if body == null or not is_instance_valid(body):
			stale_ids.append(raw_id)
	for raw_id: Variant in stale_ids:
		occupying_bodies.erase(raw_id)
	_set_plate_state(
		not occupying_bodies.is_empty(),
		calculate_total_mass_kg(),
		false,
		false
	)


func calculate_total_mass_kg() -> float:
	var total_mass: float = 0.0
	for body_value: Variant in occupying_bodies.values():
		if body_value is Node3D:
			var body := body_value as Node3D
			if body != null and is_instance_valid(body):
				total_mass += get_body_mass_kg(body)
	return maxf(total_mass, 0.0)


func get_body_mass_kg(body: Node3D) -> float:
	if body == null or not is_instance_valid(body):
		return 0.0
	if body.has_method("get_mechanism_mass_kg"):
		return maxf(float(body.call("get_mechanism_mass_kg")), 0.0)
	if body.has_meta("mechanism_mass_kg"):
		return maxf(float(body.get_meta("mechanism_mass_kg", 0.0)), 0.0)
	if body is RigidBody3D:
		return maxf((body as RigidBody3D).mass, 0.0)
	var mass_value: Variant = body.get("mass")
	if mass_value != null:
		return maxf(float(mass_value), 0.0)
	return maxf(default_non_rigid_body_mass_kg, 0.0)


func set_pressed(
	next_pressed: bool,
	immediate: bool = false,
	force_emit: bool = false
) -> void:
	_set_plate_state(next_pressed, measured_mass_kg, immediate, force_emit)


func set_simulated_mass_kg(next_mass_kg: float, immediate: bool = true) -> void:
	var safe_mass: float = maxf(next_mass_kg, 0.0)
	_set_plate_state(safe_mass > mass_change_epsilon, safe_mass, immediate, true)


func _set_plate_state(
	next_pressed: bool,
	next_mass_kg: float,
	immediate: bool,
	force_emit: bool
) -> void:
	var pressed_changed_now: bool = is_pressed != next_pressed
	var safe_mass: float = maxf(next_mass_kg, 0.0)
	var value_changed_now: bool = (
		absf(measured_mass_kg - safe_mass) > mass_change_epsilon
	)
	is_pressed = next_pressed
	measured_mass_kg = safe_mass
	if path_enabled != is_pressed:
		path_enabled = is_pressed
		notify_topology_changed()
	animate_plate(immediate)
	refresh_label()
	last_mechanism_packet = build_mechanism_packet()
	if pressed_changed_now:
		pressed_changed.emit(is_pressed)
	if value_changed_now or force_emit:
		mechanism_value_changed.emit(
			measured_mass_kg,
			last_mechanism_packet.duplicate(true)
		)
	if pressed_changed_now or value_changed_now or force_emit:
		mechanism_signal_changed.emit(
			get_mechanism_id(),
			is_pressed,
			last_mechanism_packet.duplicate(true)
		)


func build_mechanism_packet() -> Dictionary:
	return {
		"mechanism_id": get_mechanism_id(),
		"active": is_pressed,
		"source_type": "pressure_plate",
		"occupants": occupying_bodies.size(),
		"value": measured_mass_kg,
		"minimum_value": get_mechanism_min_value(),
		"maximum_value": get_mechanism_max_value(),
		"normalized_value": get_mechanism_normalized_value(),
		"unit": get_mechanism_value_unit(),
		"body_masses": get_body_mass_rows(),
	}


func get_body_mass_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for body_value: Variant in occupying_bodies.values():
		if not body_value is Node3D:
			continue
		var body := body_value as Node3D
		if body == null or not is_instance_valid(body):
			continue
		rows.append({
			"name": body.name,
			"instance_id": body.get_instance_id(),
			"mass_kg": get_body_mass_kg(body),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return rows


func animate_plate(immediate: bool) -> void:
	if plate_visual == null:
		return
	var target_position: Vector3 = plate_up_position
	if is_pressed:
		target_position.y -= depress_distance

	if plate_tween != null and plate_tween.is_valid():
		plate_tween.kill()
	if immediate:
		plate_visual.position = target_position
		return

	plate_tween = create_tween()
	plate_tween.set_trans(Tween.TRANS_QUAD)
	plate_tween.set_ease(Tween.EASE_OUT)
	plate_tween.tween_property(plate_visual, "position", target_position, animation_seconds)


func _on_circuit_state_applied() -> void:
	refresh_energized_visual()
	refresh_label()


func refresh_energized_visual() -> void:
	if current_glow != null:
		current_glow.visible = energized


func refresh_label() -> void:
	if state_label == null:
		return
	var state_text: String = "PRESSED" if is_pressed else "RELEASED"
	if show_weight_in_label:
		state_label.text = (
			"PRESSURE PLATE\n"
			+ str(snappedf(measured_mass_kg, 0.1))
			+ " kg • "
			+ state_text
		)
	else:
		state_label.text = "PRESSURE PLATE\n" + state_text


func interact() -> Dictionary:
	return {
		"message": (
			display_name
			+ " reports both contact and total supported mass. Current load: "
			+ str(snappedf(measured_mass_kg, 0.1))
			+ " kg."
		),
		"objective": "Stand on the plate or combine movable objects to reach a weight threshold.",
	}


func get_mechanism_id() -> String:
	var normalized: String = component_id.to_lower().strip_edges().replace(" ", "_")
	return normalized if normalized != "" else str(name).to_lower()


func is_mechanism_active() -> bool:
	return is_pressed


func get_mechanism_value() -> float:
	return measured_mass_kg


func get_mechanism_min_value() -> float:
	return 0.0


func get_mechanism_max_value() -> float:
	return maxf(maximum_reported_mass_kg, 0.1)


func get_mechanism_normalized_value() -> float:
	return clampf(
		measured_mass_kg / get_mechanism_max_value(),
		0.0,
		1.0
	)


func get_mechanism_value_unit() -> String:
	return "kg"


func get_mechanism_packet() -> Dictionary:
	return last_mechanism_packet.duplicate(true)


func reset_target() -> void:
	occupying_bodies.clear()
	_set_plate_state(false, 0.0, true, true)
	apply_circuit_state(false, 0.0, 0.0, -1)
	notify_topology_changed()
	refresh_label()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["pressure_plate"] = true
	data["pressed"] = is_pressed
	data["occupants"] = occupying_bodies.size()
	data["mass_kg"] = measured_mass_kg
	data["mass_rows"] = get_body_mass_rows()
	data["mechanism_id"] = get_mechanism_id()
	data["mechanism_packet"] = last_mechanism_packet.duplicate(true)
	return data
