extends Node

var is_active: bool = false
var restore_time_scale: float = 1.0


func request(duration: float = 0.06, time_scale: float = 0.05) -> void:
	if duration <= 0.0:
		return

	if is_active:
		return

	is_active = true
	restore_time_scale = Engine.time_scale
	Engine.time_scale = time_scale

	await get_tree().create_timer(duration, true, false, true).timeout

	Engine.time_scale = restore_time_scale
	is_active = false
