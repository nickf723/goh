extends Area3D
class_name FrozenWaterBridgeArea

signal body_supported(body: Node3D)
signal body_released(body: Node3D)

@export var bridge_label: String = "Frozen Water Path"

var tracked_bodies: Dictionary = {}
var support_count: int = 0
var release_count: int = 0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = true
	var entered_callback := Callable(self, "_on_body_entered")
	var exited_callback := Callable(self, "_on_body_exited")
	if not body_entered.is_connected(entered_callback):
		body_entered.connect(entered_callback)
	if not body_exited.is_connected(exited_callback):
		body_exited.connect(exited_callback)
	add_to_group("frozen_water_bridge_areas")
	add_to_group("debuggable")


func _exit_tree() -> void:
	clear_supported_bodies()


func _on_body_entered(body: Node3D) -> void:
	register_body(body)


func _on_body_exited(body: Node3D) -> void:
	unregister_body(body)


func register_body(body: Node3D) -> void:
	if body == null or not is_instance_valid(body):
		return
	var body_id: int = body.get_instance_id()
	if tracked_bodies.has(body_id):
		return
	tracked_bodies[body_id] = body
	support_count += 1
	body.set_meta("frozen_water_bridge_label", bridge_label)
	var swimming_controller: Node = body.get_node_or_null("SwimmingController")
	if (
		swimming_controller != null
		and swimming_controller.has_method("enter_frozen_surface")
	):
		swimming_controller.call("enter_frozen_surface", self)
	body_supported.emit(body)


func unregister_body(body: Node3D) -> void:
	if body == null:
		return
	var body_id: int = body.get_instance_id()
	if not tracked_bodies.has(body_id):
		return
	tracked_bodies.erase(body_id)
	release_count += 1
	var swimming_controller: Node = body.get_node_or_null("SwimmingController")
	if (
		swimming_controller != null
		and swimming_controller.has_method("exit_frozen_surface")
	):
		swimming_controller.call("exit_frozen_surface", self)
	body_released.emit(body)


func has_registered_body(body: Node) -> bool:
	return (
		body != null
		and is_instance_valid(body)
		and tracked_bodies.has(body.get_instance_id())
	)


func clear_supported_bodies() -> void:
	var bodies: Array[Node3D] = []
	for body_value: Variant in tracked_bodies.values():
		if body_value is Node3D:
			var body := body_value as Node3D
			if body != null and is_instance_valid(body):
				bodies.append(body)
	for body: Node3D in bodies:
		unregister_body(body)
	tracked_bodies.clear()


func get_debug_data() -> Dictionary:
	var body_names: Array[String] = []
	for body_value: Variant in tracked_bodies.values():
		if body_value is Node and is_instance_valid(body_value as Node):
			body_names.append(str((body_value as Node).name))
	body_names.sort()
	return {
		"frozen_water_bridge": true,
		"label": bridge_label,
		"tracked_bodies": tracked_bodies.size(),
		"body_names": body_names,
		"supports": support_count,
		"releases": release_count,
	}
