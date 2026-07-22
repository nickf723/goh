extends Node

const FlightDefinition: Resource = preload("res://data/concentration/flight_concentration.tres")
const FlightAbility: Resource = preload("res://data/abilities/flight_concentration_ability.tres")
const AerialLabScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_aerial_traversal_lab_v1.tscn")

var failures: Array[String] = []


func _ready() -> void:
	test_flight_definition()
	test_flight_ability()
	await test_lab_contract()

	if failures.is_empty():
		print("AERIAL_TRAVERSAL_CONCENTRATION_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return

	for failure: String in failures:
		push_error("AERIAL_TRAVERSAL_CONCENTRATION_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func test_flight_definition() -> void:
	if FlightDefinition == null:
		failures.append("Flight concentration definition failed to load")
		return
	if str(FlightDefinition.get("effect_id")) != "flight_concentration":
		failures.append("Flight effect id must be flight_concentration")
	if not is_equal_approx(float(FlightDefinition.get("mana_reservation_fraction")), 0.75):
		failures.append("Flight I must reserve 75 percent of maximum mana")
	if int(FlightDefinition.call("get_usable_mana_cap", 12)) != 3:
		failures.append("Flight should leave 3 usable mana from a maximum of 12")
	if bool(FlightDefinition.call("makes_element_free", "air")):
		failures.append("Flight must not make Air spells free")


func test_flight_ability() -> void:
	if FlightAbility == null:
		failures.append("Flight ability failed to load")
		return
	if str(FlightAbility.get("spell_id")) != "flight_concentration":
		failures.append("Flight ability spell id must be flight_concentration")
	if int(FlightAbility.get("mana_cost")) != 0:
		failures.append("Flight must use concentration rather than a fixed mana cost")
	if str(FlightAbility.get("element")) != "air":
		failures.append("Flight ability must belong to Air")
	if FlightAbility.get("ability_scene") == null:
		failures.append("Flight ability must reference its toggle action scene")


func test_lab_contract() -> void:
	if AerialLabScene == null:
		failures.append("Aerial laboratory scene failed to load")
		return

	var lab: Node = AerialLabScene.instantiate()
	if lab == null:
		failures.append("Aerial laboratory scene failed to instantiate")
		return
	add_child(lab)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame

	var manager: Node = lab.get_node_or_null("ConcentrationManager")
	var player: Node = lab.get_node_or_null("Player")
	var aerial: Node = player.get_node_or_null("AerialLocomotion") if player != null else null
	var action_state: Node = player.get_node_or_null("PlayerActionState") if player != null else null

	if manager == null:
		failures.append("Aerial laboratory is missing ConcentrationManager")
	elif not manager.has_method("get_usable_mana_cap"):
		failures.append("ConcentrationManager must expose usable mana cap")

	if player == null:
		failures.append("Aerial laboratory is missing Player")
	if aerial == null:
		failures.append("Player is missing AerialLocomotion")
	else:
		if not bool(aerial.get("double_jump_unlocked")):
			failures.append("Aerial lab must unlock Double Jump")
		if not bool(aerial.get("hover_unlocked")):
			failures.append("Aerial lab must unlock Hover")
		if not bool(aerial.get("flight_unlocked")):
			failures.append("Aerial lab must unlock Flight")
		if not aerial.has_method("process_locomotion"):
			failures.append("AerialLocomotion must expose process_locomotion")
		if not aerial.has_method("activate_flight"):
			failures.append("AerialLocomotion must expose activate_flight")

	if action_state == null:
		failures.append("Player is missing PlayerActionState")
	elif action_state.get("is_flying") == null:
		failures.append("PlayerActionState must expose flight state")

	lab.queue_free()
	await get_tree().process_frame
