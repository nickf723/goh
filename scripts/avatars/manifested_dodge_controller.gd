extends "res://scripts/player/player_dodge_controller.gd"
class_name ManifestedDodgeController

var external_steering_direction: Vector3 = Vector3.ZERO


func _ready() -> void:
	super._ready()
	set_process_unhandled_input(false)
	add_to_group("manifested_avatar_dodge_controller")


func _unhandled_input(_event: InputEvent) -> void:
	pass


func set_external_steering_direction(direction: Vector3) -> void:
	external_steering_direction = direction
	external_steering_direction.y = 0.0
	if external_steering_direction.length_squared() > 0.001:
		external_steering_direction = external_steering_direction.normalized()


func _capture_follow_up_inputs() -> void:
	pass


func _apply_late_steering(delta: float) -> void:
	if profile == null:
		return
	if dodge_progress < profile.steering_start or dodge_progress > profile.steering_end:
		return
	if external_steering_direction.length_squared() <= 0.001:
		return
	_apply_steering_direction(external_steering_direction, delta)


func _spend_dodge_stamina() -> bool:
	return true


func _update_invulnerability_window() -> void:
	var should_be_active: bool = (
		dodge_progress >= get_invulnerability_start()
		and dodge_progress < get_invulnerability_end()
	)
	if should_be_active:
		iframe_started = true
	if iframe_active != should_be_active:
		iframe_active = should_be_active
		dodge_iframe_changed.emit(iframe_active)


func _show_message(_text: String) -> void:
	pass
