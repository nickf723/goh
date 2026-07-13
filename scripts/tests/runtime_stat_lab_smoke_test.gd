extends Node

const SessionScript = preload("res://scripts/systems/runtime_stat_lab_session.gd")
const FocusTimeScript = preload("res://scripts/systems/focus_time.gd")

var failures: Array[String] = []
var original_snapshot: Dictionary = {}


func _ready() -> void:
	original_snapshot = GameState.get_stat_snapshot()
	var controlled_snapshot: Dictionary = original_snapshot.duplicate(true)
	controlled_snapshot["stamina"] = 7
	controlled_snapshot["max_stamina"] = 9
	controlled_snapshot["mana"] = 4
	controlled_snapshot["max_mana"] = 6
	controlled_snapshot["focus"] = 5
	apply_snapshot(controlled_snapshot)

	var session: RuntimeStatLabSession = SessionScript.new() as RuntimeStatLabSession
	add_child(session)
	session.begin_session()

	assert_equal(session.get_entry_snapshot().get("stamina"), 7, "entry stamina snapshot")
	assert_equal(session.get_entry_snapshot().get("max_stamina"), 9, "entry max stamina snapshot")

	session.apply_station_action("stamina", "overcharge", 1000)
	assert_equal(GameState.get_stat("stamina"), 1000, "stamina overcharge current")
	assert_equal(GameState.get_stat("max_stamina"), 1000, "stamina overcharge maximum")

	session.apply_station_action("stamina", "infinite")
	assert_true(session.is_infinite("stamina"), "infinite stamina enabled")
	assert_true(GameState.spend_stamina(375), "stamina spend succeeds while overcharged")
	assert_equal(GameState.get_stat("stamina"), 625, "stamina decreases before refill")
	session.refill_infinite_resources()
	assert_equal(GameState.get_stat("stamina"), 1000, "infinite stamina refills")

	session.apply_station_action("mana", "overcharge", 1000)
	assert_equal(GameState.get_stat("mana"), 1000, "mana overcharge current")
	assert_equal(GameState.get_stat("max_mana"), 1000, "mana overcharge maximum")

	session.apply_station_action("health", "minimum", 1)
	assert_equal(GameState.get_stat("health"), 1, "health minimum is nonlethal")
	session.apply_station_action("health", "full")
	assert_equal(GameState.get_stat("health"), GameState.get_stat("max_health"), "health full restore")

	var focus_time: Node = FocusTimeScript.new()
	add_child(focus_time)
	GameState.set_stat("focus", 0)
	assert_approx(float(focus_time.call("get_focus_time_scale")), 1.0, 0.001, "focus zero time scale")
	GameState.set_stat("focus", 10)
	assert_approx(float(focus_time.call("get_focus_time_scale")), 0.12, 0.001, "focus ten reaches best slowdown")
	GameState.set_stat("focus", 1000)
	assert_approx(float(focus_time.call("get_focus_time_scale")), 0.12, 0.001, "focus overcharge respects minimum time scale")

	assert_equal(session.get_implementation_status("stamina"), "LIVE", "stamina classification")
	assert_equal(session.get_implementation_status("power"), "PARTIAL", "power classification")
	assert_equal(session.get_implementation_status("defense"), "DORMANT", "defense classification")

	Engine.time_scale = 0.25
	session.restore_entry_snapshot(true)
	assert_snapshot(controlled_snapshot, "entry snapshot restoration")
	assert_true(not session.is_infinite("stamina"), "reset disables infinite stamina")
	assert_approx(Engine.time_scale, 1.0, 0.001, "reset restores world time scale")

	session.prepare_exit()
	assert_snapshot(controlled_snapshot, "exit restoration")

	apply_snapshot(original_snapshot)
	Engine.time_scale = 1.0

	if failures.is_empty():
		print("Runtime stat lab smoke test passed.")
		get_tree().quit(0)
		return

	for failure: String in failures:
		push_error(failure)
	get_tree().quit(1)


func apply_snapshot(snapshot: Dictionary) -> void:
	GameState.stats = snapshot.duplicate(true)
	for stat_variant: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_variant)
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_variant]))


func assert_snapshot(expected: Dictionary, label: String) -> void:
	var actual: Dictionary = GameState.get_stat_snapshot()
	for key_variant: Variant in expected.keys():
		var key: String = str(key_variant)
		if int(actual.get(key, -999999)) != int(expected[key_variant]):
			failures.append(
				label + ": " + key + " expected " + str(expected[key_variant]) + " but got " + str(actual.get(key, "missing"))
			)


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(label + ": expected " + str(expected) + " but got " + str(actual))


func assert_true(value: bool, label: String) -> void:
	if not value:
		failures.append(label + ": expected true")


func assert_approx(actual: float, expected: float, tolerance: float, label: String) -> void:
	if abs(actual - expected) > tolerance:
		failures.append(label + ": expected " + str(expected) + " but got " + str(actual))
