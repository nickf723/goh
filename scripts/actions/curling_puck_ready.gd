extends "res://scripts/actions/curling_puck.gd"
class_name CurlingPuckReady

# Neutral input sends the puck straight. Holding left or right while casting
# selects the curl direction, letting one spell author straight bridges, curved
# puzzle routes, and momentum runways without a second aiming mode.


func execute(player: Node3D, requested_direction: Vector3) -> void:
	super.execute(player, requested_direction)
	if trail != null and is_instance_valid(trail):
		trail.set_meta("curling_puck_curl_sign", curl_sign)
		trail.set_meta("curling_puck_route_kind", _get_route_kind())


func _resolve_curl_sign() -> float:
	var left_strength: float = Input.get_action_strength("move_left")
	var right_strength: float = Input.get_action_strength("move_right")
	if left_strength > right_strength + 0.12:
		return -1.0
	if right_strength > left_strength + 0.12:
		return 1.0
	return 0.0


func _get_route_kind() -> String:
	if curl_sign < -0.5:
		return "left_curl"
	if curl_sign > 0.5:
		return "right_curl"
	return "straight"


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["player_selected_curl"] = true
	data["neutral_cast_is_straight"] = true
	data["route_kind"] = _get_route_kind()
	data["trail_records_curl"] = (
		trail != null
		and is_instance_valid(trail)
		and trail.has_meta("curling_puck_curl_sign")
	)
	return data
