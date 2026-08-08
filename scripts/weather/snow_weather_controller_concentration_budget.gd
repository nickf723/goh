extends "res://scripts/weather/snow_weather_controller.gd"
class_name SnowWeatherControllerConcentrationBudget


func stop_weather(show_feedback: bool = true) -> void:
	if not active:
		return
	active = false
	set_rain_visuals_visible(false)
	restore_weather_environment()
	_release_own_concentration(show_feedback)
	weather_stopped.emit(get_weather_id())
	if show_feedback and show_messages:
		show_message("The snowfall thins and its own reserved Mana is released.")


func _release_own_concentration(show_feedback: bool) -> void:
	if concentration_manager == null:
		return
	var effect_id: String = get_weather_id()
	if concentration_manager.has_method("deactivate_effect_by_id"):
		concentration_manager.call("deactivate_effect_by_id", effect_id, show_feedback)
	elif concentration_manager.has_method("deactivate_effect"):
		concentration_manager.call("deactivate_effect", show_feedback)
