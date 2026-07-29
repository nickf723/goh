extends "res://scripts/player/player_combat_footwork_controller.gd"
class_name ManifestedCombatFootworkController

var external_steering_direction: Vector3 = Vector3.ZERO


func _ready() -> void:
	super._ready()
	add_to_group("manifested_avatar_footwork_controller")


func set_external_steering_direction(direction: Vector3) -> void:
	external_steering_direction = direction
	external_steering_direction.y = 0.0
	if external_steering_direction.length_squared() > 0.001:
		external_steering_direction = external_steering_direction.normalized()


func _apply_late_steering(delta: float) -> void:
	if profile == null:
		return
	if motion_progress < profile.steering_start or motion_progress > profile.steering_end:
		return
	if external_steering_direction.length_squared() <= 0.001:
		return
	_apply_steering_direction(external_steering_direction, delta)
