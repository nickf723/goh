extends Node

const SceneUnderTest: PackedScene = preload("res://scenes/levels/prototypes/prototype_drowned_bell_v1.tscn")
const ListenerScene: PackedScene = preload("res://scenes/actors/enemies/echo_listener.tscn")

var failures: Array[String] = []
var elapsed: float = 0.0
var current_step: String = "startup"
var finished: bool = false


func _process(delta: float) -> void:
	if finished:
		return
	elapsed += delta
	if elapsed >= 24.0:
		push_error("Drowned Bell crypt test stalled during: " + current_step)
		print("DROWNED_BELL_CRYPT_SMOKE_TEST: STALLED AT " + current_step)
		get_tree().quit(1)


func _ready() -> void:
	GameState.reset_run()
	current_step = "instantiate quest"
	var mission := SceneUnderTest.instantiate()
	add_child(mission)
	for _index: int in range(5):
		await get_tree().process_frame
	await get_tree().physics_frame

	var crypt_pass: Node = mission.get_node_or_null("CryptPass")
	check(crypt_pass != null, "crypt finale composes as its own pass")
	check(crypt_pass != null and bool(crypt_pass.get("installed")), "crypt finale installs after environment and playability")
	check(mission.get_node_or_null("World/BellBelowV3") != null, "The Bell Below environment exists")
	check(mission.get_node_or_null("World/CryptDoorwayWallPatch") != null, "chapel back wall is authored around the crypt doorway")
	check(mission.get_node_or_null("World/BellBelowV3/CryptDescent/BurialStair") != null, "burial stair exists")
	check(mission.get_node_or_null("World/BellBelowV3/CollapsedBurialPassage") != null, "collapsed swimming passage exists")
	check(mission.get_node_or_null("World/BellBelowV3/ListenerChamber") != null, "Listener chamber exists")

	current_step = "advance original quest"
	mission.call("_on_ferryman_choice", "accept", mission.get("ferryman"))
	mission.call("_on_bell_listened", mission.get("bell_marker"))
	mission.call("_on_chapel_entered", mission.get("chapel_entrance"))
	mission.call("_on_plaque_read", mission.get("plaque_clue"))
	mission.call("_on_rope_found", mission.get("rope_clue"))
	mission.call("_on_mechanism_found", mission.get("mechanism_clue"))
	mission.call("_on_tuning_plate_recovered", mission.get("tuning_plate"))
	check(GameState.has_key_item("drowned_bell_tuning_plate"), "tuning plate is carried before opening the crypt")

	current_step = "open crypt"
	var crypt_seal: Area3D = mission.get_node("SubmergedCryptSeal") as Area3D
	crypt_seal.interact()
	await get_tree().process_frame
	check(GameState.get_flag("drowned_bell_crypt_opened"), "tuning plate opens the crypt")
	check(not GameState.has_key_item("drowned_bell_tuning_plate"), "inserted tuning plate leaves Grace's inventory")
	var door_blocker: StaticBody3D = mission.get_node("World/BellBelowV3/CryptDescent/CryptDoorBlocker") as StaticBody3D
	check(door_blocker.collision_layer == 0, "crypt doorway collision clears when opened")
	var threshold: Area3D = mission.get_node("World/BellBelowV3/CryptThreshold") as Area3D
	check(threshold.monitoring, "crypt threshold activates after opening")

	current_step = "enter and observe"
	threshold.interact()
	var observation: Area3D = mission.get_node("World/BellBelowV3/ListenerObservation") as Area3D
	check(observation.monitoring, "observation point activates at the lower landing")
	observation.interact()
	var listener: EchoListenerActor = mission.get_node("World/BellBelowV3/TheListener") as EchoListenerActor
	check(listener.revealed, "blind Listener is revealed after observing the chamber")
	check(listener.is_in_group("enemy"), "revealed Listener can be targeted if Grace chooses combat")

	current_step = "inspect crypt water"
	var crypt_water: Area3D = mission.get_node("World/BellBelowV3/CryptSwimPassage") as Area3D
	check(crypt_water.get_script().resource_path.ends_with("swimming_water_volume.gd"), "crypt passage reuses shared swimming water")
	var exit_count: int = 0
	for candidate: Node in get_tree().get_nodes_in_group("swimming_exit_anchor"):
		if mission.is_ancestor_of(candidate) and candidate.has_method("supports_volume"):
			if bool(candidate.call("supports_volume", crypt_water)):
				exit_count += 1
	check(exit_count >= 2, "crypt swimming passage has two registered exits")

	current_step = "calm Listener"
	var sequence: Area3D = mission.get_node("World/BellBelowV3/TrueSequenceStone") as Area3D
	sequence.interact()
	await get_tree().process_frame
	check(GameState.get_flag("drowned_bell_listener_calmed"), "true two-note sequence records the calm route")
	check(GameState.get_flag("drowned_bell_call_resolved"), "calm route resolves the false call")
	check(not crypt_water.monitoring, "resolved passage drains and disables swimming")
	var walkway: StaticBody3D = mission.get_node("World/BellBelowV3/DrainedPassageWalkway") as StaticBody3D
	check(walkway.collision_layer != 0, "drained return walkway becomes physical")
	var record: Area3D = mission.get_node("World/BellBelowV3/DrownedBurialRegister") as Area3D
	check(record.monitoring, "burial register becomes recoverable after resolution")

	current_step = "recover record and return"
	record.interact()
	check(GameState.has_key_item("drowned_bell_burial_register"), "burial register becomes a key item")
	check(GameState.get_flag("drowned_bell_return_calm"), "Orin receives calm-route return dialogue")
	crypt_pass.call("_on_orin_choice", "report_calm", mission.get("ferryman"))
	check(GameState.get_flag("drowned_bell_complete"), "reporting to Orin completes The Drowned Bell")
	check(str(GameState.get_quest("the_drowned_bell").get("state", "")) == "completed", "quest journal records completion")
	check(GameState.has_key_item("orin_marsh_pass_token"), "Orin rewards the marsh-passage token")
	check(GameState.get_stat("level") > 1 or GameState.get_experience() >= 75, "quest completion grants experience or a level")
	check(mission.get_node("World/QuietState").visible, "completed chapel remains in its quiet aftermath")

	current_step = "reload completed aftermath"
	mission.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	var reloaded_mission := SceneUnderTest.instantiate()
	add_child(reloaded_mission)
	for _index: int in range(5):
		await get_tree().process_frame
	await get_tree().physics_frame
	var reloaded_pass: Node = reloaded_mission.get_node_or_null("CryptPass")
	check(reloaded_pass != null and bool(reloaded_pass.get("installed")), "completed quest reloads the crypt composition")
	var reloaded_door: StaticBody3D = reloaded_mission.get_node("World/BellBelowV3/CryptDescent/CryptDoorBlocker") as StaticBody3D
	check(reloaded_door.collision_layer == 0, "opened crypt remains open after reload")
	var reloaded_water: Area3D = reloaded_mission.get_node("World/BellBelowV3/CryptSwimPassage") as Area3D
	check(not reloaded_water.monitoring and not reloaded_water.visible, "resolved lower passage remains drained after reload")
	var reloaded_walkway: StaticBody3D = reloaded_mission.get_node("World/BellBelowV3/DrainedPassageWalkway") as StaticBody3D
	check(reloaded_walkway.collision_layer != 0, "drained return walkway persists after reload")
	var reloaded_listener: EchoListenerActor = reloaded_mission.get_node("World/BellBelowV3/TheListener") as EchoListenerActor
	check(not reloaded_listener.visible and not reloaded_listener.is_in_group("enemy"), "resolved Listener does not return after reload")
	check(reloaded_mission.get_node("World/QuietState").visible, "quiet chapel aftermath persists after reload")

	current_step = "combat route contract"
	var listener_test: EchoListenerActor = ListenerScene.instantiate() as EchoListenerActor
	add_child(listener_test)
	await get_tree().process_frame
	listener_test.set_revealed(true)
	var payload := DamagePayload.new()
	payload.amount = 1
	payload.stance_damage = 0
	payload.element = "neutral"
	payload.source_name = "Smoke Test Strike"
	payload.hit_type = "melee"
	payload.tags = ["weapon", "melee"]
	var payload_receiver: Node = listener_test.get_node("PayloadReceiver")
	payload_receiver.call("receive_payload", payload)
	check(listener_test.combat_active, "attacking the passive Listener provokes its combat behavior")
	var hit_receiver: Node = listener_test.get_node("HitReceiver")
	hit_receiver.set("current_health", 1)
	payload_receiver.call("receive_payload", payload)
	await get_tree().process_frame
	check(listener_test.resolved and listener_test.current_route == "fought", "defeating the Listener exposes the combat resolution route")

	current_step = "cleanup"
	reloaded_mission.queue_free()
	listener_test.queue_free()
	await get_tree().process_frame
	finished = true
	if failures.is_empty():
		print("DROWNED_BELL_CRYPT_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		print("DROWNED_BELL_CRYPT_SMOKE_TEST: FAIL")
		get_tree().quit(1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
