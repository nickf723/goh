extends Node3D
class_name SnowWeatherSpell


func execute(player: Node3D, _cast_direction: Vector3) -> void:
	var weather_controller: Node = find_snow_controller()
	if weather_controller == null or not weather_controller.has_method("toggle_weather"):
		show_message("Snowfall has nowhere to form in this scene.")
		queue_free()
		return

	weather_controller.call("toggle_weather", "snow", player)
	queue_free()


func find_snow_controller() -> Node:
	for candidate: Node in get_tree().get_nodes_in_group("weather_controller"):
		if candidate == null or not is_instance_valid(candidate):
			continue
		var definition: Variant = candidate.get("weather_definition")
		if definition == null:
			continue
		var effect_id: String = str(definition.get("effect_id"))
		var weather_kind: String = str(definition.get("weather_kind"))
		if effect_id == "snow_weather" or weather_kind == "snow":
			return candidate
	return null


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)
