extends Node3D
class_name RainWeatherSpell

const WeatherRuntime = preload(
	"res://scripts/weather/weather_spell_runtime.gd"
)


func execute(player: Node3D, _cast_direction: Vector3) -> void:
	var weather_controller: Node = WeatherRuntime.resolve_or_create(
		get_tree(),
		"rain",
		player
	)
	if weather_controller == null or not weather_controller.has_method("toggle_weather"):
		show_message("Rain has nowhere to form in this scene.")
		queue_free()
		return

	weather_controller.call("toggle_weather", "rain", player)
	queue_free()


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)
