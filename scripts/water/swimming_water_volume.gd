extends Area3D
class_name SwimmingWaterVolume

@export var surface_height_offset: float = 3.0
@export var current_velocity: Vector3 = Vector3.ZERO
@export var swirl_strength: float = 0.0
@export var inward_strength: float = 0.0
@export var water_label: String = "Water"


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("swimming_water_volume")


func get_surface_y() -> float:
	return global_position.y + surface_height_offset


func sample_current(world_position: Vector3) -> Vector3:
	var result: Vector3 = current_velocity
	var radial: Vector3 = world_position - global_position
	radial.y = 0.0
	if radial.length_squared() > 0.001:
		var radial_direction: Vector3 = radial.normalized()
		var tangent := Vector3(-radial_direction.z, 0.0, radial_direction.x)
		result += tangent * swirl_strength
		result -= radial_direction * inward_strength
	return result


func _on_body_entered(body: Node3D) -> void:
	var controller: Node = body.get_node_or_null("SwimmingController")
	if controller != null and controller.has_method("enter_water"):
		controller.call("enter_water", self)


func _on_body_exited(body: Node3D) -> void:
	var controller: Node = body.get_node_or_null("SwimmingController")
	if controller != null and controller.has_method("exit_water"):
		controller.call("exit_water", self)


func get_debug_data() -> Dictionary:
	return {
		"label": water_label,
		"surface_y": snappedf(get_surface_y(), 0.01),
		"current": current_velocity,
		"swirl": swirl_strength,
		"inward": inward_strength,
	}
