extends "res://scripts/concentration/concentration_effect_definition.gd"
class_name WeatherDefinition

@export var weather_kind: String = "weather"
@export var generated_elements: Array[String] = []
@export var weather_tags: Array[String] = []

@export_group("Atmospheric Exposure")
@export_range(0.05, 5.0, 0.05) var exposure_interval: float = 0.6
@export_range(0.1, 30.0, 0.1) var status_duration: float = 3.0
@export_range(0.0, 5.0, 0.05) var exposure_strength: float = 1.0

@export_group("Rain Presentation")
@export_range(8, 256, 1) var rain_drop_count: int = 84
@export_range(2.0, 30.0, 0.5) var rain_radius: float = 10.0
@export_range(2.0, 20.0, 0.5) var rain_height: float = 8.0
@export_range(1.0, 40.0, 0.5) var fall_speed: float = 18.0
@export var wind_velocity: Vector3 = Vector3(1.2, 0.0, 0.4)

@export_group("Snow Presentation")
@export_range(8, 256, 1) var snowflake_count: int = 108
@export_range(2.0, 30.0, 0.5) var snow_radius: float = 10.0
@export_range(2.0, 20.0, 0.5) var snow_height: float = 8.5
@export_range(0.5, 15.0, 0.25) var snow_fall_speed: float = 4.5
@export_range(0.0, 4.0, 0.05) var snow_sway_strength: float = 0.8
@export_range(0.0, 1.0, 0.01) var snow_accumulation_rate: float = 0.14


func generates_element(element: String) -> bool:
	return generated_elements.has(element.to_lower().strip_edges())


func request_element_units(element: String, requested_units: float) -> float:
	if requested_units <= 0.0 or not generates_element(element):
		return 0.0
	return requested_units


func get_weather_debug_data() -> Dictionary:
	var data: Dictionary = get_debug_data()
	data["weather_kind"] = weather_kind
	data["generated_elements"] = generated_elements
	data["weather_tags"] = weather_tags
	data["exposure_interval"] = exposure_interval
	data["status_duration"] = status_duration
	return data
