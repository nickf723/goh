extends Node
class_name AuthoredSwimmingVolumeAdapter

@export var volume_path: NodePath
@export var volume_position: Vector3 = Vector3.ZERO
@export var collision_size: Vector3 = Vector3(6.0, 5.0, 6.0)
@export var surface_height_offset: float = 3.0
@export var current_velocity: Vector3 = Vector3.ZERO
@export var water_label: String = "Authored Water"

var volume: Area3D
var collision: CollisionShape3D
var installed: bool = false


func _ready() -> void:
	add_to_group("authored_swimming_volume_adapter")
	call_deferred("install")


func install() -> bool:
	if installed:
		return true
	volume = get_node_or_null(volume_path) as Area3D
	if volume == null:
		return false
	volume.position = volume_position
	volume.set("surface_height_offset", surface_height_offset)
	volume.set("current_velocity", current_velocity)
	volume.set("water_label", water_label)
	collision = _find_collision_shape(volume)
	if collision == null:
		collision = CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		volume.add_child(collision)
	elif collision.name != "CollisionShape3D":
		collision.name = "CollisionShape3D"
	var shape: BoxShape3D = collision.shape as BoxShape3D
	if shape == null:
		shape = BoxShape3D.new()
		collision.shape = shape
	shape.size = collision_size
	installed = true
	return true


func _find_collision_shape(parent: Node) -> CollisionShape3D:
	for child: Node in parent.get_children():
		if child is CollisionShape3D:
			return child as CollisionShape3D
	return null


func get_debug_data() -> Dictionary:
	return {
		"installed": installed,
		"volume": volume.get_path() if volume != null else NodePath(),
		"collision_size": collision_size,
		"surface_offset": surface_height_offset,
		"current": current_velocity,
	}
