extends "res://scripts/actions/curling_puck.gd"
class_name CurlingPuckReady

# Neutral input sends the puck straight. Holding left or right while casting
# selects the curl direction, letting one spell author straight bridges, curved
# puzzle routes, and momentum runways without a second aiming mode.


func _resolve_curl_sign() -> float:
	var left_strength: float = Input.get_action_strength("move_left")
	var right_strength: float = Input.get_action_strength("move_right")
	if left_strength > right_strength + 0.12:
		return -1.0
	if right_strength > left_strength + 0.12:
		return 1.0
	return 0.0


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["player_selected_curl"] = true
	data["neutral_cast_is_straight"] = true
	return data
