extends "res://scripts/player/player_controller_free_aim.gd"
class_name PlayerControllerFreeAimStatus

var player_status_receiver: PlayerStatusReceiver


func _ready() -> void:
	super._ready()
	player_status_receiver = get_node_or_null(
		"StatusReceiver"
	) as PlayerStatusReceiver


func _get_requested_ground_velocity() -> Vector3:
	var requested: Vector3 = super._get_requested_ground_velocity()
	if player_status_receiver == null:
		return requested
	return requested * clampf(
		player_status_receiver.get_movement_multiplier(),
		0.0,
		1.0
	)
