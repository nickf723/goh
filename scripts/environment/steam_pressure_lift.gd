extends Node3D
class_name SteamPressureLift

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")

@export var activation_message: String = "Steam pressure reaches the threshold. The lift rises."
@export var gauge_refresh_interval: float = 0.08

@onready var reservoir: PressureReservoir = get_node_or_null("PressureReservoir") as PressureReservoir
@onready var consumer: ElementConsumer = get_node_or_null("SteamConsumer") as ElementConsumer
@onready var actuator: MechanicalActuator = get_node_or_null("MechanicalActuator") as MechanicalActuator
@onready var gauge_label: Label3D = get_node_or_null("GaugeLabel") as Label3D
@onready var gauge_needle: Node3D = get_node_or_null("GaugeNeedle") as Node3D
@onready var platform: Node3D = get_node_or_null("LiftPlatform") as Node3D

var refresh_timer: float = 0.0
var activation_announced: bool = false


func _ready() -> void:
	add_to_group("debuggable")
	add_to_group("lab_resettable")

	if reservoir != null:
		reservoir.pressure_changed.connect(_on_pressure_changed)
	if actuator != null:
		actuator.activated.connect(_on_activated)
		actuator.deactivated.connect(_on_deactivated)

	update_gauge()


func _process(delta: float) -> void:
	refresh_timer -= delta
	if refresh_timer > 0.0:
		return
	refresh_timer = max(gauge_refresh_interval, 0.04)
	update_gauge()


func _on_pressure_changed(
	_current_pressure: float,
	_maximum_pressure: float,
	_delta_pressure: float,
	_source: String
) -> void:
	update_gauge()


func _on_activated() -> void:
	update_gauge()
	if activation_announced:
		return
	activation_announced = true
	show_message(activation_message)
	GameState.set_objective("The elemental machine converted Steam into mechanical work.")


func _on_deactivated() -> void:
	update_gauge()


func update_gauge() -> void:
	if reservoir == null:
		return

	var pressure: float = reservoir.current_pressure
	var maximum: float = max(reservoir.maximum_pressure, 0.01)
	var ratio: float = reservoir.get_pressure_ratio()
	var threshold: float = actuator.activation_pressure if actuator != null else maximum
	var cycles: int = consumer.consumption_count if consumer != null else 0
	var state_text: String = "LIFTED" if is_lift_activated() else "CHARGING"

	if gauge_label != null:
		gauge_label.text = (
			"STEAM PRESSURE: "
			+ str(roundi(pressure))
			+ " / "
			+ str(roundi(maximum))
			+ "\nTHRESHOLD: "
			+ str(roundi(threshold))
			+ "  •  BURSTS: "
			+ str(cycles)
			+ "\nMACHINE: "
			+ state_text
		)
		gauge_label.modulate = (
			ElementVisuals.get_element_color("steam")
			if is_lift_activated()
			else ElementVisuals.get_element_color("neutral").lerp(
				ElementVisuals.get_element_color("steam"),
				ratio
			)
		)

	if gauge_needle != null:
		gauge_needle.rotation_degrees.z = lerpf(-105.0, 105.0, ratio)


func is_lift_activated() -> bool:
	return actuator != null and actuator.is_activated


func get_pressure() -> float:
	return reservoir.current_pressure if reservoir != null else 0.0


func get_pressure_ratio() -> float:
	return reservoir.get_pressure_ratio() if reservoir != null else 0.0


func reset_target() -> void:
	activation_announced = false
	refresh_timer = 0.0

	if consumer != null:
		consumer.reset_consumer()
		var status_receiver: Node = consumer.get_node_or_null("StatusReceiver")
		if status_receiver != null and status_receiver.has_method("clear_all_statuses"):
			status_receiver.clear_all_statuses()

	if actuator != null:
		actuator.reset_actuator()
	if reservoir != null:
		reservoir.reset_pressure()

	call_deferred("update_gauge")


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"steam_pressure_lift": true,
		"pressure": reservoir.get_debug_data() if reservoir != null else {},
		"consumer": consumer.get_debug_data() if consumer != null else {},
		"actuator": actuator.get_debug_data() if actuator != null else {},
		"activated": is_lift_activated(),
		"platform_position": platform.position if platform != null else Vector3.ZERO,
	}
