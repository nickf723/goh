extends Node

const SnowDefinition: Resource = preload("res://data/weather/snow_weather.tres")
const SnowAbility: Resource = preload("res://data/abilities/snow_weather_ability.tres")
const SnowLabScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_snow_weather_lab_v1.tscn")
const WeatherExposureProbeScript = preload("res://scripts/weather/weather_exposure_probe.gd")

var failures: Array[String] = []


func _ready() -> void:
	test_snow_definition()
	test_snow_ability()
	await test_probe_accumulation()
	await test_lab_contract()

	if failures.is_empty():
		print("SNOW_CONCENTRATION_WEATHER_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return

	for failure: String in failures:
		push_error("SNOW_CONCENTRATION_WEATHER_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func test_snow_definition() -> void:
	if SnowDefinition == null:
		failures.append("Snow weather definition failed to load")
		return

	if str(SnowDefinition.get("effect_id")) != "snow_weather":
		failures.append("Snow effect id must be snow_weather")
	if not is_equal_approx(float(SnowDefinition.get("mana_reservation_fraction")), 0.45):
		failures.append("Snowfall must reserve 45 percent of maximum mana")
	if int(SnowDefinition.call("get_usable_mana_cap", 10)) != 5:
		failures.append("Snowfall should leave 5 usable mana from a maximum of 10")
	if not bool(SnowDefinition.call("makes_element_free", "ice")):
		failures.append("Snowfall must make Ice abilities free")
	if bool(SnowDefinition.call("makes_element_free", "water")):
		failures.append("Snowfall must not make Water abilities free")
	if not is_equal_approx(float(SnowDefinition.call("request_element_units", "ice", 250.0)), 250.0):
		failures.append("Snowfall must provide an infinite Ice source contract")
	if float(SnowDefinition.call("request_element_units", "fire", 1.0)) != 0.0:
		failures.append("Snowfall must not provide Fire element units")


func test_snow_ability() -> void:
	if SnowAbility == null:
		failures.append("Snowfall ability failed to load")
		return
	if str(SnowAbility.get("spell_id")) != "snow_weather":
		failures.append("Snowfall ability spell id must be snow_weather")
	if int(SnowAbility.get("mana_cost")) != 0:
		failures.append("Snowfall must use concentration rather than a fixed mana cost")
	if str(SnowAbility.get("element")) != "ice":
		failures.append("Snowfall ability must belong to Ice")
	if SnowAbility.get("ability_scene") == null:
		failures.append("Snowfall ability must reference its toggle action scene")


func test_probe_accumulation() -> void:
	var probe: Node3D = WeatherExposureProbeScript.new() as Node3D
	probe.name = "SnowProbeFixture"
	probe.set("snow_exposure_to_freeze", 1.2)
	add_child(probe)
	await get_tree().process_frame

	var payload := DamagePayload.new()
	payload.element = "ice"
	payload.source_name = "Fixture Snowfall"
	payload.hit_type = "weather"
	payload.status_duration = 4.0
	payload.status_strength = 0.45
	payload.tags = ["snow", "ice", "cold", "weather"]

	probe.call("receive_weather_payload", payload)
	if str(probe.get("weather_state")) != "frosting":
		failures.append("A first Snow pulse should put an exposure probe into frosting state")
	probe.call("receive_weather_payload", payload)
	probe.call("receive_weather_payload", payload)
	if str(probe.get("weather_state")) != "frozen":
		failures.append("Repeated Snow pulses should freeze an exposure probe")

	probe.queue_free()
	await get_tree().process_frame


func test_lab_contract() -> void:
	if SnowLabScene == null:
		failures.append("Snowfall laboratory scene failed to load")
		return

	var lab: Node = SnowLabScene.instantiate()
	if lab == null:
		failures.append("Snowfall laboratory scene failed to instantiate")
		return
	add_child(lab)
	await get_tree().process_frame
	await get_tree().process_frame

	var manager: Node = lab.get_node_or_null("ConcentrationManager")
	var controller: Node = lab.get_node_or_null("SnowWeatherController")
	var player: Node = lab.get_node_or_null("Player")
	var accumulation: Node = lab.get_node_or_null("SnowAccumulationField")
	var basin: Node = lab.get_node_or_null("SnowPhaseBasin")

	if manager == null:
		failures.append("Snowfall laboratory is missing ConcentrationManager")
	if controller == null:
		failures.append("Snowfall laboratory is missing SnowWeatherController")
	elif controller.get("weather_definition") == null:
		failures.append("SnowWeatherController is missing its weather definition")
	elif not controller.has_method("request_element_units"):
		failures.append("SnowWeatherController must expose infinite element requests")
	if player == null or player.get_node_or_null("AbilityCaster") == null:
		failures.append("Snowfall laboratory player is missing AbilityCaster")
	if accumulation == null or not accumulation.has_method("receive_weather_payload"):
		failures.append("Snowfall laboratory is missing its accumulation field")
	if basin == null or not basin.has_method("is_frozen"):
		failures.append("Snowfall laboratory is missing its phase-change basin")
	if manager != null and not manager.has_method("get_usable_mana_cap"):
		failures.append("ConcentrationManager must expose the usable mana cap")

	lab.queue_free()
	await get_tree().process_frame
