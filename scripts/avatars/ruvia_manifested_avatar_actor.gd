extends "res://scripts/avatars/manifested_avatar_actor.gd"
class_name RuviaManifestedAvatarActor


func _ready() -> void:
	super._ready()
	remove_from_group("combat_targetable")
	add_to_group("friendly_manifestation")
	add_to_group("ruvia_manifestation")
	add_to_group("enemy_targetable")
	# Layer 2 is reserved here for enemy projectile contact with friendly
	# manifestations. Grace's ordinary projectiles remain on mask 1 and ignore it.
	collision_layer = 2
