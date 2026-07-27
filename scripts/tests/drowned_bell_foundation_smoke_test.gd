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
	if elapsed >= 5.0:
		push_error("Drowned Bell test stalled during: " + current_step)
		print("DROWNED_BELL_FOUNDATION_SMOKE_TEST: STALLED AT " + current_step)
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
	check(mission.get_node_or_null("World/FloodedState") != null, "flooded world variant exists")
	check(mission.get_node_or_null("World/QuietState") != null, "quiet world variant exists")
	var listening_point: Area3D = mission.get_node("BellListeningPoint") as Area3D
	check(listening_point != null, "listening point is an Area3D")
	check(not listening_point.monitoring, "listening point begins locked before accepting the quest")

	current_step = "accept quest"
	mission.call("_on_ferryman_choice", "accept", mission.get("ferryman"))
	check(GameState.get_flag("drowned_bell_accepted"), "accepting starts the investigation")
	check(str(GameState.get_quest("the_drowned_bell").get("state", "")) == "active", "quest is active")
	check(int(GameState.get_quest("the_drowned_bell").get("stage", -1)) == 1, "quest advances to listening stage")
	check(listening_point.monitoring, "listening point activates when the acceptance flag changes")
	check(listening_point.monitorable, "listening point becomes detectable by the player interaction area")

	current_step = "listen to bell"
	mission.call("_on_bell_listened", mission.get("bell_marker"))
	check(GameState.get_flag("drowned_bell_heard_pattern"), "listening records the bell pattern")
	check(int(GameState.get_quest("the_drowned_bell").get("stage", -1)) == 2, "quest advances to chapel entry stage")
	check(not listening_point.monitoring, "one-time listening point locks after the pattern is recorded")

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
