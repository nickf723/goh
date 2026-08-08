extends Node3D
class_name ScaleCast

const ScaleControllerScript = preload(
	"res://scripts/player/player_scale_controller.gd"
)

var source_actor: Node3D = null


func set_source_actor(new_source_actor: Node) -> void:
	if new_source_actor is Node3D:
		source_actor = new_source_actor as Node3D


func execute(player: Node3D, cast_direction: Vector3) -> void:
	if source_actor == null:
		source_actor = player
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return

	var controller: Node = source_actor.get_node_or_null("ScaleController")
	if controller == null:
		controller = ScaleControllerScript.new()
		controller.name = "ScaleController"
		source_actor.add_child(controller)
	if controller.has_method("activate_scale"):
		var result: Variant = controller.call("activate_scale", cast_direction)
		if result is Dictionary and not bool((result as Dictionary).get("activated", false)):
			_refund_cast_cost()
	queue_free()


func _refund_cast_cost() -> void:
	# Scale costs 2 Mana in v1. Failed recasts/blocked ownership should not charge
	# the player for a traversal phrase that never began.
	if GameState == null:
		return
	var current: int = GameState.get_stat("mana")
	var maximum: int = GameState.get_stat("max_mana")
	GameState.set_stat("mana", mini(current + 2, maximum))
