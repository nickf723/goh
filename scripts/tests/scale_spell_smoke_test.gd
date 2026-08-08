extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const ScaleAbility: AbilityDefinition = preload(
	"res://data/abilities/scale_ability.tres"
)
const CloneSemantics = preload(
	"res://scripts/abilities/spell_clone_semantics.gd"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	_prepare_stats()
	_test_ability_contract()

	var floor: StaticBody3D = _make_floor()
	add_child(floor)
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "ScaleSpellTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	player.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	add_child(player)
	for _frame: int in range(12):
		await get_tree().process_frame
	await get_tree().physics_frame

	var caster: Node = player.get_node_or_null("AbilityCaster")
	_expect(caster != null, "Scale test resolves AbilityCaster")
	if caster == null:
		_finish([player, floor])
		return
	var scale_index: int = _find_scale_index(caster)
	_expect(scale_index >= 0, "Grace's runtime loadout contains Scale")
	if scale_index < 0:
		_finish([player, floor])
		return

	var starting_mana: int = GameState.get_stat("mana")
	caster.call("select_ability", scale_index, false)
	var cast_result: bool = bool(caster.call("cast_from_player", player, 0.0, false))
	_expect(cast_result, "Scale casts through the ordinary AbilityCaster path")
	_expect(
		GameState.get_stat("mana") == starting_mana - ScaleAbility.mana_cost,
		"Scale spends two Mana upfront"
	)

	var controller: PlayerScaleController = player.get_node_or_null(
		"ScaleController"
	) as PlayerScaleController
	_expect(controller != null, "Scale installs one reusable traversal controller")
	if controller == null:
		_finish([player, floor])
		return
	var start_position: Vector3 = player.global_position
	var initial_direction: Vector3 = controller.ascent_direction
	var max_height: float = player.global_position.y
	var guard_frames: int = 0
	while controller.is_scale_active() and guard_frames < 240:
		await get_tree().physics_frame
		max_height = maxf(max_height, player.global_position.y)
		guard_frames += 1
	var end_debug: Dictionary = controller.get_debug_data()
	_expect(not controller.is_scale_active(), "Scale resolves after its committed phrase")
	_expect(
		str(end_debug.get("last_end_reason", "")) == "completed",
		"an unobstructed Scale ends by completing the phrase"
	)
	_expect(
		int(end_debug.get("completed_steps", 0)) == 8,
		"Scale performs exactly eight note-steps"
	)
	_expect(
		max_height - start_position.y >= 4.7,
		"the octave grants about five metres of verticality"
	)
	var planar_offset: Vector3 = player.global_position - start_position
	planar_offset.y = 0.0
	var forward_distance: float = planar_offset.dot(initial_direction)
	var lateral_offset: Vector3 = planar_offset - initial_direction * forward_distance
	_expect(forward_distance > 7.0, "Scale commits Grace forward while ascending")
	_expect(lateral_offset.length() < 0.35, "Scale cannot steer sideways during the phrase")
	_expect(player.is_physics_processing(), "ordinary Grace locomotion resumes after Scale")
	_expect(
		CloneSemantics.get_repeat_mode(ScaleAbility) == CloneSemantics.REPEAT_SOURCE_STATE,
		"Repeat treats Scale as recorded source-state traversal"
	)
	_expect(
		CloneSemantics.get_duplicate_mode(ScaleAbility) == CloneSemantics.DUPLICATE_SOURCE_STATE,
		"Duplicate treats Scale as a live source-state traversal"
	)

	# A wall across the committed route should interrupt rather than steering the
	# phrase around it.
	player.global_position = Vector3(0.0, 0.96, 0.0)
	player.velocity = Vector3.ZERO
	var blocker: StaticBody3D = _make_blocker(Vector3(0.0, 2.0, 1.6))
	add_child(blocker)
	await get_tree().physics_frame
	var blocked_result: Dictionary = controller.activate_scale(Vector3.FORWARD)
	_expect(bool(blocked_result.get("activated", false)), "Scale can begin a second clean test phrase")
	guard_frames = 0
	while controller.is_scale_active() and guard_frames < 120:
		await get_tree().physics_frame
		guard_frames += 1
	var blocked_debug: Dictionary = controller.get_debug_data()
	_expect(not controller.is_scale_active(), "blocked Scale releases locomotion ownership")
	_expect(
		str(blocked_debug.get("last_end_reason", "")) in ["blocked", "ceiling_blocked"],
		"architecture interrupts Scale instead of bending its heading"
	)
	_expect(
		int(blocked_debug.get("completed_steps", 8)) < 8,
		"blocked Scale cannot silently finish the octave"
	)

	_finish([player, floor, blocker])


func _test_ability_contract() -> void:
	_expect(ScaleAbility.get_spell_id() == "scale", "Scale has a stable spell ID")
	_expect(ScaleAbility.element == "sound", "Scale belongs to Sound")
	_expect(ScaleAbility.mana_cost == 2, "Scale costs two Mana")
	_expect(
		ScaleAbility.ability_scene != null
		and ScaleAbility.ability_scene.resource_path == "res://scenes/actions/scale_cast.tscn",
		"Scale uses its dedicated traversal action"
	)
	_expect(
		ScaleAbility.get_delivery_type() == "committed_traversal_state",
		"Scale advertises committed traversal delivery"
	)
	_expect(ScaleAbility.get_roles().has("verticality"), "Scale exposes vertical traversal as a role")


func _find_scale_index(caster: Node) -> int:
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return -1
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
	for index: int in range(loadout.get_equipped_ability_count()):
		var ability: AbilityDefinition = loadout.get_equipped_ability(index)
		if ability != null and ability.get_spell_id() == "scale":
			return index
	return -1


func _make_floor() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "ScaleSmokeFloor"
	body.position = Vector3(0.0, -0.1, 7.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(30.0, 0.2, 40.0)
	collision.shape = shape
	body.add_child(collision)
	return body


func _make_blocker(position_value: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "ScaleSmokeBlocker"
	body.position = position_value
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.0, 5.0, 0.5)
	collision.shape = shape
	body.add_child(collision)
	return body


func _prepare_stats() -> void:
	GameState.set_stat("max_health", 100)
	GameState.set_stat("health", 100)
	GameState.set_stat("max_mana", 60)
	GameState.set_stat("mana", 60)
	GameState.set_stat("max_stamina", 40)
	GameState.set_stat("stamina", 40)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("SCALE_SPELL_SMOKE_TEST: " + label)


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
		print("SCALE_SPELL_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("SCALE_SPELL_SMOKE_TEST: " + failure)
	get_tree().quit(1)
