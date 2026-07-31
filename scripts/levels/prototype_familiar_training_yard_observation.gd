extends "res://scripts/levels/prototype_familiar_training_yard.gd"

const CreatureObservationAccess = preload(
	"res://scripts/animals/creature_observation_access.gd"
)


func _ready() -> void:
	CreatureObservationAccess.get_service(get_tree())
	super._ready()


func _on_wild_gremlin_defeated(_member_name: String) -> void:
	wild_defeats += 1
	var remaining: int = 0
	if enemy_root != null:
		for child: Node in enemy_root.get_children():
			if child.is_in_group("enemy") and not child.is_queued_for_deletion():
				remaining += 1
	if remaining > 0:
		show_message(
			"Wild Gremlin defeated. " + str(remaining)
			+ " pack member" + ("s" if remaining != 1 else "")
			+ " remain."
		)
	else:
		show_message("The wild Gremlin pack is defeated. Field records are updating.")
