extends CircuitSwitch
class_name PressurePlateSwitch

signal pressed_changed(is_pressed: bool)
signal mechanism_signal_changed(mechanism_id: String, active: bool, packet: Dictionary)

@export var accept_any_physics_body: bool = true
@export var accepted_group: String = "player"
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
var plate_tween: Tween = null
var last_mechanism_packet: Dictionary = {}


func _ready() -> void:
	starts_closed = false
	super._ready()
	add_to_group("lab_resettable")
	add_to_group("mechanism_inputs")
	plate_visual = get_node_or_null(plate_visual_path) as Node3D
	current_glow = get_node_or_null(current_glow_path) as Node3D
	state_label = get_node_or_null(state_label_path) as Label3D
	if plate_visual != null:
		plate_up_position = plate_visual.position

	connect_body_detection_signals()
	set_pressed(false, true)
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
	for raw_id in occupying_bodies.keys():
		var body: Node = occupying_bodies[raw_id] as Node
		if body == null or not is_instance_valid(body):
			stale_ids.append(raw_id)
	for raw_id in stale_ids:
		occupying_bodies.erase(raw_id)
	set_pressed(not occupying_bodies.is_empty())


func set_pressed(next_pressed: bool, immediate: bool = false) -> void:
	var changed: bool = is_pressed != next_pressed
	is_pressed = next_pressed
	if path_enabled != is_pressed:
		path_enabled = is_pressed
		notify_topology_changed()
	animate_plate(immediate)
	refresh_label()
	if changed:
		last_mechanism_packet = {
			"mechanism_id": get_mechanism_id(),
			"active": is_pressed,
			"source_type": "pressure_plate",
			"occupants": occupying_bodies.size(),
		}
		pressed_changed.emit(is_pressed)
		mechanism_signal_changed.emit(
			get_mechanism_id(),
			is_pressed,
			last_mechanism_packet.duplicate(true)
		)


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
	state_label.text = "PRESSURE PLATE\n" + ("PRESSED" if is_pressed else "RELEASED")


func interact() -> Dictionary:
	return {
		"message": display_name + " closes only while physical weight rests on it.",
		"objective": "Stand on the plate or place a movable object on it.",
	}


func get_mechanism_id() -> String:
	var normalized: String = component_id.to_lower().strip_edges().replace(" ", "_")
	return normalized if normalized != "" else str(name).to_lower()


func is_mechanism_active() -> bool:
	return is_pressed


func get_mechanism_packet() -> Dictionary:
	return last_mechanism_packet.duplicate(true)


func reset_target() -> void:
	occupying_bodies.clear()
	set_pressed(false, true)
	apply_circuit_state(false, 0.0, 0.0, -1)
	notify_topology_changed()
	refresh_label()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["pressure_plate"] = true
	data["pressed"] = is_pressed
	data["occupants"] = occupying_bodies.size()
	data["mechanism_id"] = get_mechanism_id()
	data["mechanism_packet"] = last_mechanism_packet.duplicate(true)
	return data
