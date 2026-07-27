extends Node

const SceneUnderTest: PackedScene = preload("res://scenes/levels/prototypes/prototype_drowned_bell_v1.tscn")

var failures: Array[String] = []


func _ready() -> void:
	GameState.reset_run()
	var mission := SceneUnderTest.instantiate()
	add_child(mission)
	await get_tree().process_frame
	check(mission.get_script().resource_path.ends_with("prototype_drowned_bell_v1.gd"), "scene uses the direct Drowned Bell director")
	check(mission.get("quest") != null, "quest runtime is composed")
	check(mission.get("chapel_state") != null, "world-state variant is composed")
	check(mission.get_node_or_null("FerrymanOrin") != null, "Ferryman Orin exists")
	check(mission.get_node_or_null("BellListeningPoint") != null, "bell listening point exists")
	check(mission.get_node_or_null("World/FloodedState") != null, "flooded world variant exists")
	check(mission.get_node_or_null("World/QuietState") != null, "quiet world variant exists")

	mission.call("_on_ferryman_choice", "accept", mission.get("ferryman"))
	check(GameState.get_flag("drowned_bell_accepted"), "accepting starts the investigation")
	check(str(GameState.get_quest("the_drowned_bell").get("state", "")) == "active", "quest is active")
	check(int(GameState.get_quest("the_drowned_bell").get("stage", -1)) == 1, "quest advances to listening stage")

	mission.call("_on_bell_listened", mission.get("bell_marker"))
	check(GameState.get_flag("drowned_bell_heard_pattern"), "listening records the bell pattern")
	check(int(GameState.get_quest("the_drowned_bell").get("stage", -1)) == 2, "quest advances to chapel entry stage")

	mission.get("chapel_state").apply("quiet")
	check(not mission.get_node("World/FloodedState").visible, "quiet state hides flood presentation")
	check(mission.get_node("World/QuietState").visible, "quiet state exposes chapel steps")

	mission.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("DROWNED_BELL_FOUNDATION_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		print("DROWNED_BELL_FOUNDATION_SMOKE_TEST: FAIL")
		get_tree().quit(1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
