extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const DuplicateSpellScene: PackedScene = preload(
	"res://scenes/abilities/duplicate_concentration_spell.tscn"
)
const RepeatSpellScene: PackedScene = preload(
	"res://scenes/abilities/repeat_concentration_spell.tscn"
)
const FireboltAbility: AbilityDefinition = preload(
	"res://data/abilities/firebolt_ability.tres"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}

class CombatTarget:
	extends StaticBody3D
	var hit_count: int = 0
	var duplicate_hits: int = 0
	var repeat_hits: int = 0

	func receive_damage_payload(payload: DamagePayload) -> Dictionary:
		hit_count += 1
		if payload.tags.has("duplicate") or payload.tags.has("live_clone"):
			duplicate_hits += 1
		if payload.tags.has("repeat") or payload.tags.has("echo"):
			repeat_hits += 1
		return {"received": true, "damage": payload.amount}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	_prepare_stats()
	var floor: StaticBody3D = _make_floor()
	add_child(floor)
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "DuplicateRepeatMultiSourcePlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	player.add_to_group("player")
	add_child(player)
	await _wait_frames(20)
	await get_tree().physics_frame

	var duplicate_spell: Node = DuplicateSpellScene.instantiate()
	add_child(duplicate_spell)
	duplicate_spell.call("execute", player, Vector3.FORWARD)
	await _wait_frames(8)

	var duplicate_controller: SoulDuplicateControllerCombatSynced = (
		get_tree().get_first_node_in_group("soul_duplicate_controller")
		as SoulDuplicateControllerCombatSynced
	)
	var duplicate: SoulDuplicateActorCombatSynced = (
		get_tree().get_first_node_in_group("soul_duplicates")
		as SoulDuplicateActorCombatSynced
	)
	_expect(duplicate_controller != null, "Duplicate uses the combat-synced controller")
	_expect(duplicate != null, "Duplicate spawns the combat-synced Soul Grace")
	if duplicate_controller == null or duplicate == null:
		_finish([player, floor])
		return

	_expect(
		is_equal_approx(duplicate.jump_velocity, float(player.get("jump_velocity"))),
		"Soul Grace uses Grace's exact jump launch velocity"
	)
	_expect(
		is_equal_approx(duplicate.gravity, float(player.get("gravity"))),
		"Soul Grace uses Grace's gravity constant"
	)
	_expect(
		is_equal_approx(duplicate.move_speed, float(player.get("move_speed"))),
		"Soul Grace uses Grace's authored ground speed"
	)

	var forward: Vector3 = Vector3.FORWARD
	var target := CombatTarget.new()
	target.name = "SoulAttackTarget"
	target.position = duplicate.global_position + forward * 1.45
	target.collision_layer = 1
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.55
	collision.shape = sphere
	target.add_child(collision)
	add_child(target)

	var attack := WeaponAttackDefinition.new()
	attack.attack_id = "soul_synced_attack"
	attack.startup_time = 0.01
	attack.active_time = 0.04
	attack.recovery_time = 0.05
	attack.attack_range = 2.1
	attack.attack_center_forward_offset = 0.7
	attack.cone_angle_degrees = 80.0
	attack.max_targets = 2
	var payload := DamagePayload.new()
	payload.amount = 3
	payload.stance_damage = 2
	payload.tags = ["physical", "weapon"]
	attack.payload = payload
	duplicate.mirror_weapon_attack_with_forward(attack, null, forward)
	await _wait_frames(5)
	_expect(target.duplicate_hits >= 1, "Soul Grace can land a duplicate-tagged melee attack")
	_expect(
		duplicate.last_mirrored_attack_forward.dot(forward) > 0.99,
		"Soul Grace keeps the supplied combat aim instead of its stale body facing"
	)

	var repeat_spell: Node = RepeatSpellScene.instantiate()
	add_child(repeat_spell)
	repeat_spell.call("execute", player, Vector3.FORWARD)
	await _wait_frames(8)
	var repeat: RepeatEchoControllerMultiSourceReady = (
		get_tree().get_first_node_in_group("repeat_echo_controller")
		as RepeatEchoControllerMultiSourceReady
	)
	_expect(repeat != null, "Repeat uses the multi-source timeline authority")
	if repeat == null:
		_finish([target, player, floor])
		return
	await _wait_frames(4)
	var repeat_debug: Dictionary = repeat.get_debug_data()
	_expect(
		int(repeat_debug.get("secondary_source_count", 0)) == 1,
		"Repeat discovers the already-active Soul Grace"
	)
	_expect(
		get_tree().get_node_count_in_group("repeat_echoes") >= 2,
		"Repeat creates one Time Grace and one Time Soul at base level"
	)

	# Put Soul Grace somewhere Grace never occupied. Its own time echo must later
	# arrive there rather than following Grace's primary history lane.
	var soul_history_position := Vector3(5.5, 0.96, 2.0)
	duplicate.global_position = soul_history_position
	duplicate.velocity = Vector3.ZERO
	await _wait_physics_frames(72)
	var soul_echo: RepeatEchoActor = _find_soul_repeat_echo(duplicate.get_instance_id())
	_expect(soul_echo != null, "Repeat exposes a Time Soul tied to the duplicate source ID")
	if soul_echo != null:
		_expect(
			soul_echo.global_position.distance_to(soul_history_position) < 1.0,
			"Time Soul follows Soul Grace's independent historical position"
		)

	# Attack recording is source-specific as well. The delayed attack should drain
	# from the secondary event queue after one second even if Grace stands elsewhere.
	repeat.record_registered_source_attack(
		duplicate,
		attack,
		null,
		forward
	)
	await _wait_physics_frames(72)
	repeat_debug = repeat.get_debug_data()
	_expect(
		int(repeat_debug.get("secondary_attack_replays", 0)) >= 1,
		"Time Soul replays Soul Grace's weapon event one second later"
	)

	# A duplicated projectile reports its live instance into Soul Grace's lane.
	duplicate_controller.call("_mirror_ability", FireboltAbility, null)
	await _wait_frames(3)
	repeat_debug = repeat.get_debug_data()
	_expect(
		int(repeat_debug.get("secondary_trajectory_records", 0)) >= 1,
		"a Soul Firebolt creates its own Repeat trajectory record"
	)

	var manager: Node = get_tree().get_first_node_in_group("concentration_manager")
	if manager != null and manager.has_method("deactivate_effect_by_id"):
		manager.call("deactivate_effect_by_id", "repeat_concentration", false)
		manager.call("deactivate_effect_by_id", "duplicate_concentration", false)
	await _wait_frames(4)
	_expect(
		get_tree().get_node_count_in_group("repeat_echoes") == 0,
		"releasing Repeat removes Grace and Soul timeline echoes"
	)
	_expect(
		get_tree().get_node_count_in_group("soul_duplicates") == 0,
		"releasing Duplicate removes Soul Grace"
	)
	_finish([target, player, floor])


func _find_soul_repeat_echo(source_id: int) -> RepeatEchoActor:
	for node: Node in get_tree().get_nodes_in_group("repeat_echoes"):
		if (
			node is RepeatEchoActor
			and int(node.get_meta("repeat_source_id", -1)) == source_id
		):
			return node as RepeatEchoActor
	return null


func _make_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "DuplicateRepeatFloor"
	floor.position = Vector3(0.0, -0.5, 0.0)
	floor.collision_layer = 1
	floor.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(50.0, 1.0, 50.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor


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
	push_error("DUPLICATE_REPEAT_MULTISOURCE_SMOKE_TEST: " + label)


func _restore_state() -> void:
	GameState.stats = original_stats.duplicate(true)
	for key: Variant in GameState.stats.keys():
		GameState.stat_changed.emit(str(key), int(GameState.stats[key]))


func _finish(nodes: Array) -> void:
	Engine.time_scale = 1.0
	_restore_state()
	for value: Variant in nodes:
		if value is Node and is_instance_valid(value as Node):
			(value as Node).queue_free()
	if failures.is_empty():
		print("DUPLICATE_REPEAT_MULTISOURCE_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("DUPLICATE_REPEAT_MULTISOURCE_SMOKE_TEST: " + failure)
		get_tree().quit(1)
