extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)

var failures: Array[String] = []
var old_story_flags: Dictionary = {}
var player: Node3D


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	old_story_flags = GameState.story_flags.duplicate(true)

	var mixed_flags: Dictionary = {
		"test_boolean": true,
		"__progression__::counter::live_wire": 2,
		"__progression__::tracked_quest": "ruined_village_relay",
		"__recorded_objects__::selected_blueprint": "platform",
		"test_nested_record": {
			"state": "active",
			"count": 3,
		},
		"test_array_record": ["fire", "water", "lightning"],
	}
	GameState.apply_saved_flags({"story_flags": mixed_flags})

	assert_true(
		GameState.story_flags.get("test_boolean") is bool,
		"Boolean flags preserve their type"
	)
	assert_equal(
		GameState.story_flags.get("test_boolean"),
		true,
		"Boolean flags preserve their value"
	)
	assert_true(
		GameState.story_flags.get("__progression__::counter::live_wire") is int,
		"Progression counters remain numeric"
	)
	assert_equal(
		int(GameState.story_flags.get("__progression__::counter::live_wire", 0)),
		2,
		"Progression counter value survives loading"
	)
	assert_equal(
		str(GameState.story_flags.get("__progression__::tracked_quest", "")),
		"ruined_village_relay",
		"Tracked quest IDs remain strings"
	)
	assert_equal(
		str(GameState.story_flags.get(
			"__recorded_objects__::selected_blueprint",
			""
		)),
		"platform",
		"Selected blueprint IDs remain strings"
	)
	assert_true(
		GameState.story_flags.get("test_nested_record") is Dictionary,
		"Nested progression records remain dictionaries"
	)
	assert_true(
		GameState.story_flags.get("test_array_record") is Array,
		"Array progression records remain arrays"
	)

	player = PlayerScene.instantiate() as Node3D
	add_child(player)
	for _index: int in range(4):
		await get_tree().process_frame

	var caster: Node = player.get_node_or_null("AbilityCaster")
	assert_true(caster != null, "Player ability caster exists")
	if caster != null:
		caster.call(
			"show_earth_spike_erupt_visual",
			Vector3(3.0, 0.25, -2.0),
			2.0
		)
		await get_tree().process_frame
		var eruption: Node3D = get_node_or_null(
			"EarthSpikeEruption"
		) as Node3D
		assert_true(
			eruption != null and eruption.is_inside_tree(),
			"Earth Spike visual attaches to the active scene"
		)
		if eruption != null:
			assert_true(
				eruption.global_position.distance_to(
					Vector3(3.0, 0.25, -2.0)
				) < 0.01,
				"Earth Spike visual receives its global position after attachment"
			)

		var visual_count_before: int = _count_earth_spike_visuals()
		remove_child(player)
		caster.call(
			"show_earth_spike_erupt_visual",
			Vector3(8.0, 0.0, 8.0),
			2.0
		)
		await get_tree().process_frame
		assert_equal(
			_count_earth_spike_visuals(),
			visual_count_before,
			"Detached casters do not create teardown visuals"
		)

	_restore_state()
	_finish()


func _count_earth_spike_visuals() -> int:
	var count: int = 0
	for child: Node in get_children():
		if str(child.name).begins_with("EarthSpikeEruption"):
			count += 1
	return count


func _restore_state() -> void:
	if player != null and is_instance_valid(player):
		if player.get_parent() != null:
			player.get_parent().remove_child(player)
		player.free()
	player = null
	for child: Node in get_children():
		if str(child.name).begins_with("EarthSpikeEruption"):
			child.queue_free()
	GameState.story_flags = old_story_flags.duplicate(true)


func _finish() -> void:
	if failures.is_empty():
		print("DEATH_SAVE_RECOVERY_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("DEATH_SAVE_RECOVERY_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func assert_true(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(
			label
			+ " (expected "
			+ str(expected)
			+ ", got "
			+ str(actual)
			+ ")"
		)