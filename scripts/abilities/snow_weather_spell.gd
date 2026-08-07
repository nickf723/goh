extends Node3D
class_name SnowWeatherSpell

const WeatherRuntime = preload(
	"res://scripts/weather/weather_spell_runtime.gd"
)


func execute(player: Node3D, _cast_direction: Vector3) -> void:
	var weather_controller: Node = WeatherRuntime.resolve_or_create(
		get_tree(),
		"snow",
		player
	)
	if weather_controller == null or not weather_controller.has_method("toggle_weather"):
		show_message("Snowfall has nowhere to form in this scene.")
		queue_free()
		return

	var active_after_toggle: bool = bool(
		weather_controller.call("toggle_weather", "snow", player)
	)
	_cleanup_dismissed_runtime_controller(
		weather_controller,
		active_after_toggle
	)
	queue_free()


func _cleanup_dismissed_runtime_controller(
	weather_controller: Node,
	active_after_toggle: bool
) -> void:
	if (
		active_after_toggle
		or weather_controller == null
		or not is_instance_valid(weather_controller)
		or not bool(weather_controller.get_meta("runtime_weather_controller", false))
	):
		return
	weather_controller.queue_free()


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)
