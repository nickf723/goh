extends Node

var failures: Array[String] = []


func _ready() -> void:
	var original_level: int = GameState.get_stat("level")
	var original_experience: int = GameState.get_experience()
	var original_points: int = GameState.get_growth_points()
	var original_max_health: int = GameState.get_stat("max_health")
	var original_health: int = GameState.get_stat("health")
	GameState.set_stat("level", 1)
	GameState.set_stat("max_health", 5)
	GameState.set_stat("health", 3)
	GameState.set_progression(0, 0)
	GameState.add_experience(39)
	_expect(GameState.get_stat("level") == 1, "Experience below threshold does not level up")
	_expect(GameState.get_experience() == 39, "Experience progress is retained")
	var result: Dictionary = GameState.add_experience(1)
	_expect(int(result.get("levels", 0)) == 1, "Crossing the threshold reports a level")
	_expect(GameState.get_stat("level") == 2, "Level increases")
	_expect(GameState.get_growth_points() == 1, "Level awards a Growth Point")
	_expect(GameState.get_experience() == 0, "Spent threshold experience rolls over")
	var shrine := GrowthShrine.new()
	add_child(shrine)
	await get_tree().process_frame
	var vitality: Dictionary = GrowthShrine.UPGRADES[0]
	_expect(shrine.apply_upgrade(vitality), "Growth Point applies an upgrade")
	_expect(GameState.get_stat("max_health") == 7, "Vitality raises maximum Health")
	_expect(GameState.get_growth_points() == 0, "Upgrade spends exactly one Growth Point")
	GameState.set_stat("level", original_level)
	GameState.set_stat("max_health", original_max_health)
	GameState.set_stat("health", original_health)
	GameState.set_progression(original_experience, original_points)
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	if failures.is_empty():
		print("GROWTH PROGRESSION SMOKE TEST PASSED")
	else:
		push_error("GROWTH PROGRESSION SMOKE TEST FAILED: " + ", ".join(failures))
