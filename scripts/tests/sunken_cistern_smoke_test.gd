extends Node
## Headless regression for the Sunken Cistern elemental dungeon.
##
## Asserts the six spaces build, every ward registers with the right element,
## feeding each ward its element opens the gate its controller drives, and the
## capstone enemy + exit are present.

const SceneUnderTest: PackedScene = preload("res://scenes/levels/prototypes/sunken_cistern_v1.tscn")

var failures: Array[String] = []
var elapsed: float = 0.0
var finished: bool = false


func _process(delta: float) -> void:
	if finished:
		return
	elapsed += delta
	if elapsed >= 12.0:
		push_error("SUNKEN_CISTERN_SMOKE_TEST: stalled")
		print("SUNKEN_CISTERN_SMOKE_TEST: STALLED")
		get_tree().quit(1)


func _ready() -> void:
	GameState.reset_run()

	var dungeon := SceneUnderTest.instantiate()
	add_child(dungeon)
	# _build_dungeon() is deferred; lock controllers then wait a frame of their own.
	for i in 5:
		await get_tree().process_frame

	check(dungeon.get_script().resource_path.ends_with("sunken_cistern.gd"),
		"scene runs the Sunken Cistern director")

	var arch: Node = dungeon.get_node_or_null("CisternArchitecture")
	check(arch != null, "architecture root builds")
	if arch == null:
		_finish()
		return

	# --- structure: one representative node per space --------------------
	for node_name: String in [
		"EntryFloor", "FrozenSluice", "SluiceIceLock", "PumpGateWingLeft", "PumpGate",
		"PumpFloor", "PumpBoltLock", "ReservoirGate",
		"GalleryFloor", "GalleryFlameLock", "CacheGate", "GalleryCache",
		"ResWalkNorth", "ResIceLock", "ResBoltLock", "UndercroftGate",
		"UndercroftFloor", "UndercroftRewardAltar", "UndercroftExit",
	]:
		check(arch.get_node_or_null(node_name) != null, "%s exists" % node_name)

	# --- enemies -------------------------------------------------------
	for enemy_name: String in [
		"PumpGremlinA", "PumpGremlinB", "ReservoirConstruct", "UndercroftSalamander",
	]:
		var enemy: Node = arch.get_node_or_null(enemy_name)
		check(enemy != null and enemy.is_in_group("enemy"), "%s spawned as an enemy" % enemy_name)

	# --- wards register with the right element ------------------------
	_assert_lock(arch, "SluiceIceLock", "ice", "cistern_r1_locks")
	_assert_lock(arch, "PumpBoltLock", "lightning", "cistern_r2_locks")
	_assert_lock(arch, "GalleryFlameLock", "fire", "cistern_cache_locks")
	_assert_lock(arch, "ResIceLock", "ice", "cistern_r3_locks")
	_assert_lock(arch, "ResBoltLock", "lightning", "cistern_r3_locks")

	# --- functional: element in -> gate opens -----------------------
	check(not _gate_open(arch, "PumpGate"), "pump gate starts sealed")
	_cast_at(arch, "SluiceIceLock", "ice")
	await get_tree().process_frame
	check(_gate_open(arch, "PumpGate"), "ice ward opens the pump gate")

	_cast_at(arch, "PumpBoltLock", "lightning")
	await get_tree().process_frame
	check(_gate_open(arch, "ReservoirGate"), "lightning ward opens the reservoir gate")

	_cast_at(arch, "GalleryFlameLock", "fire")
	await get_tree().process_frame
	check(_gate_open(arch, "CacheGate"), "fire ward opens the optional cache")

	check(not _gate_open(arch, "UndercroftGate"), "undercroft gate needs both wards")
	_cast_at(arch, "ResIceLock", "ice")
	_cast_at(arch, "ResBoltLock", "lightning")
	await get_tree().process_frame
	check(_gate_open(arch, "UndercroftGate"), "paired ice+lightning wards open the undercroft gate")

	# --- wrong element is rejected ----------------------------------
	var fresh := preload("res://scripts/puzzles/prototype_element_lock_target.gd").new()
	fresh.set("required_element", "ice")
	add_child(fresh)
	var payload := DamagePayload.new()
	payload.element = "fire"
	fresh.receive_damage_payload(payload)
	check(not bool(fresh.call("is_active")), "a ward rejects the wrong element")
	fresh.queue_free()

	_finish()


func _assert_lock(arch: Node, node_name: String, element: String, group_name: String) -> void:
	var lock: Node = arch.get_node_or_null(node_name)
	if lock == null:
		failures.append("%s missing" % node_name)
		return
	check(str(lock.get("required_element")) == element, "%s wants %s" % [node_name, element])
	check(lock.is_in_group(group_name), "%s is in %s" % [node_name, group_name])
	check(lock.is_in_group("element_lock_target"), "%s registers as an element lock" % node_name)


func _cast_at(arch: Node, lock_name: String, element: String) -> void:
	var lock: Node = arch.get_node_or_null(lock_name)
	if lock == null or not lock.has_method("receive_damage_payload"):
		failures.append("cannot cast at %s" % lock_name)
		return
	var payload := DamagePayload.new()
	payload.element = element
	lock.receive_damage_payload(payload)


func _gate_open(arch: Node, gate_name: String) -> bool:
	var gate: Node = arch.get_node_or_null(gate_name)
	return gate != null and bool(gate.get("is_unlocked"))


func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	finished = true
	if failures.is_empty():
		print("SUNKEN_CISTERN_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("SUNKEN_CISTERN_SMOKE_TEST: " + failure)
	print("SUNKEN_CISTERN_SMOKE_TEST: FAIL")
	get_tree().quit(1)
