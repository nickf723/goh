extends "res://scripts/avatars/manifested_avatar_actor.gd"
class_name RuviaManifestedAvatarActor


func _ready() -> void:
	super._ready()
	remove_from_group("combat_targetable")
	add_to_group("friendly_manifestation")
	add_to_group("ruvia_manifestation")
