extends Node

const RainDefinition: Resource = preload("res://data/weather/rain_weather.tres")
const RainAbility: Resource = preload("res://data/abilities/rain_weather_ability.tres")
const RainLabScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_rain_weather_lab_v1.tscn")

var failures: Array[String] = []


func _ready() -> void:
	test_rain_definition()
	test_rain_ability()
	await test_lab_contract()

	if failures.is_empty():
		print("RAIN_CONCENTRATION_WEATHER_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return

	for failure: String in failures:
		push_error("RAIN_CONCENTRATION_WEATHER_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func test_rain_definition() -> void:
	if RainDefinition == null:
		failures.append("Rain weather definition failed to load")
		return

	if str(RainDefinition.get("effect_id")) != "rain_weather":
		failures.append("Rain effect id must be rain_weather")
	if not is_equal_approx(float(RainDefinition.get("mana_reservation_fraction")), 0.4):
		failures.append("Rain must reserve 40 percent of maximum mana")
	if int(RainDefinition.call("get_usable_mana_cap", 10)) != 6:
		failures.append("Rain should leave 6 usable mana from a maximum of 10")
	if not bool(RainDefinition.call("makes_element_free", "water")):
		failures.append("Rain must make Water abilities free")
	if bool(RainDefinition.call("makes_element_free", "fire")):
		failures.append("Rain must not make Fire abilities free")
	if not is_equal_approx(float(RainDefinition.call("request_element_units", "water", 250.0)), 250.0):
		failures.append("Rain must provide an infinite Water source contract")
	if float(RainDefinition.call("request_element_units", "fire", 1.0)) != 0.0:
		failures.append("Rain must not provide Fire element units")


func test_rain_ability() -> void:
	if RainAbility == null:
		failures.append("Rain ability failed to load")
		return
	if str(RainAbility.get("spell_id")) != "rain_weather":
		failures.append("Rain ability spell id must be rain_weather")
	if int(RainAbility.get("mana_cost")) != 0:
		failures.append("Rain must use concentration rather than a fixed mana cost")
	if str(RainAbility.get("element")) != "water":
		failures.append("Rain ability must belong to Water")
	if RainAbility.get("ability_scene") == null:
		failures.append("Rain ability must reference its toggle action scene")


func test_lab_contract() -> void:
	if RainLabScene == null:
		failures.append("Rain laboratory scene failed to load")
		return

	var lab: Node = RainLabScene.instantiate()
	if lab == null:
		failures.append("Rain laboratory scene failed to instantiate")
		return
	add_child(lab)
	await get_tree().process_frame
	await get_tree().process_frame

	var manager: Node = lab.get_node_or_null("ConcentrationManager")
	var controller: Node = lab.get_node_or_null("RainWeatherController")
	var player: Node = lab.get_node_or_null("Player")

	if manager == null:
		failures.append("Rain laboratory is missing ConcentrationManager")
	if controller == null:
		failures.append("Rain laboratory is missing RainWeatherController")
	elif controller.get("weather_definition") == null:
		failures.append("RainWeatherController is missing its weather definition")
	if player == null or player.get_node_or_null("AbilityCaster") == null:
		failures.append("Rain laboratory player is missing AbilityCaster")

	if manager != null and not manager.has_method("get_usable_mana_cap"):
		failures.append("ConcentrationManager must expose the usable mana cap")
	if controller != null and not controller.has_method("request_element_units"):
		failures.append("WeatherController must expose infinite element requests")

	lab.queue_free()
	await get_tree().process_frame
