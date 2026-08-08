extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const RepeatSpellScene: PackedScene = preload(
	"res://scenes/abilities/repeat_concentration_spell.tscn"
)
const FireboltAbility: AbilityDefinition = preload(
	"res://data/abilities/firebolt_ability.tres"
)
const BoulderAbility: AbilityDefinition = preload(
	"res://data/abilities/boulder_ability.tres"
)
const RainAbility: AbilityDefinition = preload(
	"res://data/abilities/rain_weather_ability.tres"
)
const GrowAbility: AbilityDefinition = preload(
	"res://data/abilities/grow_ability.tres"
)
const Semantics = preload(
	"res://scripts/abilities/spell_clone_semantics.gd"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	_prepare_stats()
	_test_policy_contract()

	var floor := StaticBody3D.new()
	floor.name = "RepeatSpellReplayFloor"
	floor.position = Vector3(0.0, -0.5, 0.0)
	floor.collision_layer = 1
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(40.0, 1.0, 40.0)
	floor_collision.shape = floor_shape
	floor.add_child(floor_collision)
	add_child(floor)

	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "RepeatSpellReplayPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	player.add_to_group("player")
	add_child(player)
	await _wait_frames(18)
	await get_tree().physics_frame

	var caster: Node = player.get_node_or_null("AbilityCaster")
	_expect(caster != null, "Repeat spell replay resolves Grace's AbilityCaster")
	if caster == null:
		_finish([player, floor])
		return

	var repeat_spell: Node = RepeatSpellScene.instantiate()
	add_child(repeat_spell)
	if repeat_spell.has_method("execute"):
		repeat_spell.call("execute", player, Vector3.FORWARD)
	await _wait_frames(8)
	var controller: RepeatEchoControllerFullTimeline = get_tree().get_first_node_in_group(
		"repeat_echo_controller"
	) as RepeatEchoControllerFullTimeline
	_expect(controller != null, "Repeat installs the full timeline controller")
	if controller == null:
		_finish([player, floor])
		return

	var firebolt_index: int = _find_ability_index(caster, "firebolt")
	_expect(firebolt_index >= 0, "Firebolt is available for Repeat's integration fixture")
	if firebolt_index >= 0:
		caster.call("select_ability", firebolt_index, false)
		var cast_start: Vector3 = player.global_position
		_expect(
			bool(caster.call("cast_from_player", player, 0.0, false)),
			"Grace successfully casts the original Firebolt"
		)
		player.global_position += Vector3(5.0, 0.0, 0.0)
		await _wait_physics_frames(90)
		var replay_debug: Dictionary = controller.get_debug_data()
		_expect(
			int(replay_debug.get("replayed_trajectories", 0)) >= 1,
			"Repeat replays Firebolt as a recorded trajectory"
		)
		_expect(
			str(replay_debug.get("last_replayed_spell", "")) == "firebolt",
			"the trajectory replay keeps the actual selected spell identity"
		)
		var echo: RepeatEchoActor = get_tree().get_first_node_in_group(
			"repeat_echoes"
		) as RepeatEchoActor
		_expect(echo != null, "Repeat still owns its delayed Grace echo")
		if echo != null:
			_expect(
				echo.global_position.distance_to(cast_start) < 1.5,
				"the echo remains near Grace's historical cast position after Grace moves away"
			)

	var trajectory_nodes: Array[Node] = get_tree().get_nodes_in_group(
		"repeat_trajectory_echoes"
	)
	if not trajectory_nodes.is_empty():
		var replayed_node: Node = trajectory_nodes[0]
		var trajectory_debug: Dictionary = replayed_node.call("get_debug_data") as Dictionary
		_expect(
			bool(trajectory_debug.get("path_is_timeline_authoritative", false)),
			"projectile Repeat uses prerecorded path authority"
		)
		_expect(
			bool(trajectory_debug.get("collisions_cannot_redirect_replay", false)),
			"new contacts cannot redirect remembered projectile motion"
		)

	var manager: Node = get_tree().get_first_node_in_group("concentration_manager")
	if manager != null and manager.has_method("deactivate_effect"):
		manager.call("deactivate_effect", false)
	await _wait_frames(4)
	_expect(
		get_tree().get_first_node_in_group("repeat_echo_controller") == null,
		"releasing concentration cleans up Repeat timeline replay"
	)

	_finish([player, floor])


func _test_policy_contract() -> void:
	_expect(
		Semantics.get_repeat_mode(FireboltAbility) == Semantics.REPEAT_TRAJECTORY,
		"Firebolt uses trajectory memory rather than a second simulation"
	)
	_expect(
		Semantics.get_repeat_mode(BoulderAbility) == Semantics.REPEAT_TRAJECTORY,
		"Boulder uses exact recorded physics motion"
	)
	_expect(
		Semantics.get_repeat_mode(RainAbility) == Semantics.REPEAT_WORLD_STATE,
		"Rain is a delayed no-op because the world weather already exists"
	)
	_expect(
		Semantics.get_repeat_mode(GrowAbility) == Semantics.REPEAT_SOURCE_STATE,
		"Grow is reproduced through the recorded Grace state"
	)
	_expect(
		Semantics.get_duplicate_mode(BoulderAbility) == Semantics.DUPLICATE_LIVE,
		"future Soul Boulder remains a second live simulation"
	)


func _find_ability_index(caster: Node, spell_id: String) -> int:
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return -1
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
	for ability_index: int in range(loadout.get_equipped_ability_count()):
		var ability: AbilityDefinition = loadout.get_equipped_ability(ability_index)
		if ability != null and ability.get_spell_id() == spell_id:
			return ability_index
	return -1


func _prepare_stats() -> void:
	GameState.set_stat("max_health", 100)
	GameState.set_stat("health", 100)
	GameState.set_stat("max_mana", 100)
	GameState.set_stat("mana", 100)
	GameState.set_stat("max_stamina", 40)
	GameState.set_stat("stamina", 40)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)


func _wait_frames(frame_count: int) -> void:
	for _frame: int in range(maxi(frame_count, 0)):
		await get_tree().process_frame


func _wait_physics_frames(frame_count: int) -> void:
	for _frame: int in range(maxi(frame_count, 0)):
		await get_tree().physics_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("REPEAT_SPELL_REPLAY_SMOKE_TEST: " + label)


func _restore_state() -> void:
	GameState.stats = original_stats.duplicate(true)
	for stat_value: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_value)
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_value]))


func _finish(nodes: Array) -> void:
	Engine.time_scale = 1.0
	_restore_state()
	for node_value: Variant in nodes:
		if node_value is Node and is_instance_valid(node_value as Node):
			(node_value as Node).queue_free()
	if failures.is_empty():
		print("REPEAT_SPELL_REPLAY_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("REPEAT_SPELL_REPLAY_SMOKE_TEST: " + failure)
	get_tree().quit(1)
