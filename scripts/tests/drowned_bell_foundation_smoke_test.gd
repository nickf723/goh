extends Node

const SceneUnderTest: PackedScene = preload("res://scenes/levels/prototypes/prototype_drowned_bell_v1.tscn")

var failures: Array[String] = []
var elapsed: float = 0.0
var current_step: String = "startup"
var finished: bool = false


func _process(delta: float) -> void:
	if finished:
		return
	elapsed += delta
	if elapsed >= 8.0:
		push_error("Drowned Bell test stalled during: " + current_step)
		print("DROWNED_BELL_INTERIOR_SMOKE_TEST: STALLED AT " + current_step)
		get_tree().quit(1)


func _ready() -> void:
	current_step = "reset run"
	GameState.reset_run()
	current_step = "instantiate mission"
	var mission := SceneUnderTest.instantiate()
	add_child(mission)
	await get_tree().process_frame
	current_step = "inspect composition"
	check(mission.get_script().resource_path.ends_with("prototype_drowned_bell_v1.gd"), "scene uses the direct Drowned Bell director")
	check(mission.get("quest") != null, "quest runtime is composed")
	check(mission.get("chapel_state") != null, "world-state variant is composed")
	check(mission.get_node_or_null("FerrymanOrin") != null, "Ferryman Orin exists")
	check(mission.get_node_or_null("BellListeningPoint") != null, "bell listening point exists")
	check(mission.get_node_or_null("ChapelEntrance") != null, "chapel entrance exists")
	check(mission.get_node_or_null("MemorialPlaque") != null, "memorial plaque clue exists")
	check(mission.get_node_or_null("SeveredBellRope") != null, "severed rope clue exists")
	check(mission.get_node_or_null("BurialMechanism") != null, "submerged mechanism clue exists")
	check(mission.get_node_or_null("NaveSwimPocket") != null, "real swimming volume exists")
	check(mission.get_node_or_null("CorrodedTuningPlate") != null, "tuning plate exists")
	check(mission.get_node_or_null("SubmergedCryptSeal") != null, "crypt seal exists")
	check(mission.get_node_or_null("World/FloodedState") != null, "flooded world variant exists")
	check(mission.get_node_or_null("World/QuietState") != null, "quiet world variant exists")

	var listening_point: Area3D = mission.get_node("BellListeningPoint") as Area3D
	var entrance: Area3D = mission.get_node("ChapelEntrance") as Area3D
	var plaque: Area3D = mission.get_node("MemorialPlaque") as Area3D
	var rope: Area3D = mission.get_node("SeveredBellRope") as Area3D
	var mechanism: Area3D = mission.get_node("BurialMechanism") as Area3D
	var plate: Area3D = mission.get_node("CorrodedTuningPlate") as Area3D
	var crypt: Area3D = mission.get_node("SubmergedCryptSeal") as Area3D
	check(not listening_point.monitoring, "listening point begins locked")
	check(not entrance.monitoring, "chapel entrance begins locked")
	check(not plaque.monitoring and not rope.monitoring and not mechanism.monitoring, "interior clues begin locked")
	check(not plate.monitoring, "tuning plate begins hidden from interaction")
	check(not crypt.monitoring, "crypt seal begins locked")

	current_step = "accept quest"
	mission.call("_on_ferryman_choice", "accept", mission.get("ferryman"))
	check(GameState.get_flag("drowned_bell_accepted"), "accepting starts the investigation")
	check(str(GameState.get_quest("the_drowned_bell").get("state", "")) == "active", "quest is active")
	check(int(GameState.get_quest("the_drowned_bell").get("stage", -1)) == 1, "quest advances to listening stage")
	check(listening_point.monitoring and listening_point.monitorable, "listening point activates for player detection")

	current_step = "listen to bell"
	mission.call("_on_bell_listened", mission.get("bell_marker"))
	check(GameState.get_flag("drowned_bell_heard_pattern"), "listening records the bell pattern")
	check(int(GameState.get_quest("the_drowned_bell").get("stage", -1)) == 2, "quest advances to chapel entry stage")
	check(not listening_point.monitoring, "listening point locks after use")
	check(entrance.monitoring, "chapel entrance activates after the pattern is heard")

	current_step = "enter chapel"
	mission.call("_on_chapel_entered", mission.get("chapel_entrance"))
	check(GameState.get_flag("drowned_bell_chapel_entered"), "chapel entry is recorded")
	check(not entrance.monitoring, "chapel entrance locks after entry")
	check(plaque.monitoring and rope.monitoring and mechanism.monitoring, "all three resonance clues activate")

	current_step = "inspect swimming volume"
	var swim_volume: Area3D = mission.get_node("NaveSwimPocket") as Area3D
	check(swim_volume.get_script().resource_path.ends_with("swimming_water_volume.gd"), "swim pocket uses shared swimming water volume")
	check(Vector3(swim_volume.get("current_velocity")).length() > 0.1, "swim pocket carries a real current")

	current_step = "resolve clues"
	mission.call("_on_plaque_read", mission.get("plaque_clue"))
	mission.call("_on_rope_found", mission.get("rope_clue"))
	check(not GameState.get_flag("drowned_bell_clues_complete"), "two clues do not prematurely finish investigation")
	mission.call("_on_mechanism_found", mission.get("mechanism_clue"))
	check(GameState.get_flag("drowned_bell_plaque_read"), "plaque clue recorded")
	check(GameState.get_flag("drowned_bell_rope_found"), "rope clue recorded")
	check(GameState.get_flag("drowned_bell_mechanism_found"), "mechanism clue recorded")
	check(GameState.get_flag("drowned_bell_clues_complete"), "three clues expose the tuning plate")
	check(plate.monitoring, "tuning plate activates after all clues")

	current_step = "recover tuning plate"
	mission.call("_on_tuning_plate_recovered", mission.get("tuning_plate"))
	check(GameState.get_flag("drowned_bell_tuning_plate_recovered"), "tuning plate recovery flag is recorded")
	check(GameState.has_key_item("drowned_bell_tuning_plate"), "tuning plate is stored as a key item")
	check(int(GameState.get_quest("the_drowned_bell").get("stage", -1)) == 3, "quest advances to crypt stage")
	check(crypt.monitoring, "crypt seal activates after recovering the plate")

	current_step = "inspect crypt milestone"
	mission.call("_on_crypt_examined", mission.get("crypt_seal"))
	check(str(GameState.get_quest("the_drowned_bell").get("objective", "")).contains("next quest milestone"), "crypt inspection marks the v2 endpoint")

	current_step = "apply quiet variant"
	var world_state: RefCounted = mission.get("chapel_state") as RefCounted
	check(world_state != null, "world-state handle is available")
	if world_state != null:
		world_state.call("apply", "quiet")
	check(not mission.get_node("World/FloodedState").visible, "quiet state hides flood presentation")
	check(mission.get_node("World/QuietState").visible, "quiet state exposes chapel steps")

	current_step = "cleanup"
	mission.queue_free()
	await get_tree().process_frame
	finished = true
	if failures.is_empty():
		print("DROWNED_BELL_INTERIOR_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		print("DROWNED_BELL_INTERIOR_SMOKE_TEST: FAIL")
		get_tree().quit(1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
