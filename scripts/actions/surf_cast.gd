extends Node3D
class_name SurfCast

const SurfControllerScript = preload(
	"res://scripts/player/player_surf_controller.gd"
)

var source_actor: Node3D


func set_source_actor(new_source_actor: Node) -> void:
	if new_source_actor is Node3D:
		source_actor = new_source_actor as Node3D


func execute(player: Node3D, cast_direction: Vector3) -> void:
	if source_actor == null:
		source_actor = player
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return

	var controller: Node = source_actor.get_node_or_null("SurfController")
	if controller == null:
		controller = SurfControllerScript.new()
		controller.name = "SurfController"
		source_actor.add_child(controller)
	if controller.has_method("activate_surf"):
		controller.call("activate_surf", cast_direction)
	queue_free()
