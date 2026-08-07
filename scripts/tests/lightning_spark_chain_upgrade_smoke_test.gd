extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const TargetScene: PackedScene = preload(
	"res://scenes/actors/testing/combat_training_target.tscn"
)
const SparkScene: PackedScene = preload(
	"res://scenes/actions/lightning_spark_burst.tscn"
)
const LightningSparkAbility: AbilityDefinition = preload(
	"res://data/abilities/lightning_spark_ability.tres"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	_prepare_stats()

	var floor: StaticBody3D = _make_floor()
	add_child(floor)
	var player := PlayerScene.instantiate() as CharacterBody3D
	player.name = "LightningSparkChainTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	player.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	add_child(player)

	var primary_center: CombatTrainingTarget = _spawn_target(
		"ChainPrimaryCenter",
		Vector3(0.0, 0.0, 3.0)
	)
	var primary_left: CombatTrainingTarget = _spawn_target(
		"ChainPrimaryLeft",
		Vector3(-1.0, 0.0, 3.2)
	)
	var secondary_one: CombatTrainingTarget = _spawn_target(
		"ChainSecondaryOne",
		Vector3(3.6, 0.0, 3.0)
	)
	var secondary_two: CombatTrainingTarget = _spawn_target(
		"ChainSecondaryTwo",
		Vector3(3.6, 0.0, 6.0)
	)

	for _frame: int in range(6):
		await get_tree().process_frame
	await get_tree().physics_frame

	var modified_payload: DamagePayload = (
		LightningSparkAbility.get_action_payload().duplicate(true)
		as DamagePayload
	)
	modified_payload.source_name = "Chain Lightning"
	modified_payload.stance_damage += 1
	modified_payload.status_duration *= 1.15
	for tag: String in [
		"chain_lightning",
		"chain",
		"upgrade",
		"lightning_spark",
	]:
		if not modified_payload.tags.has(tag):
			modified_payload.tags.append(tag)

	var spark := SparkScene.instantiate() as LightningSparkBurstUpgraded
	add_child(spark)
	spark.set_source_actor(player)
	spark.set_payload(modified_payload)
	spark.execute(player, Vector3.BACK)

	var debug: Dictionary = spark.get_debug_data()
	_expect(
		int(debug.get("primary_target_count", -1)) == 2,
		"the cone identifies both direct primary targets"
	)
	_expect(
		bool(debug.get("chain_effect_applied", false)),
		"Chain Lightning upgrade remains active on the cone runtime"
	)
	_expect(
		str(debug.get("chain_primary_target", ""))
		== "ChainPrimaryCenter",
		"the nearest direct target anchors the single chain"
	)
	_expect(
		not bool(debug.get("chain_per_primary", true)),
		"the cone does not start a separate chain from every primary target"
	)

	_expect(
		_get_health(primary_center) == 8,
		"nearest primary receives normal cone damage"
	)
	_expect(
		_get_health(primary_left) == 8,
		"second primary receives normal cone damage"
	)
	_expect(
		_get_health(secondary_one) == 8,
		"first outside-cone target receives the first chain jump"
	)
	_expect(
		_get_health(secondary_two) == 8,
		"second outside-cone target receives the second chain jump"
	)

	var arc_count: int = find_children(
		"ChainLightningArc",
		"MeshInstance3D",
		true,
		false
	).size()
	_expect(
		arc_count == 2,
		"one upgraded cone creates exactly the authored two secondary arcs"
	)

	_finish([
		player,
		primary_center,
		primary_left,
		secondary_one,
		secondary_two,
		floor,
	])


func _spawn_target(
	node_name: String,
	position_value: Vector3
) -> CombatTrainingTarget:
	var target := TargetScene.instantiate() as CombatTrainingTarget
	target.name = node_name
	target.target_label = node_name
	target.position = position_value
	add_child(target)
	target.set_physics_process(false)
	var receiver: Node = target.get_node_or_null("HitReceiver")
	if receiver != null:
		receiver.set("hit_mode", 2)
		receiver.set("max_health", 10)
		receiver.set("current_health", 10)
		receiver.set("max_stance", 1)
		receiver.set("current_stance", 1)
		receiver.set("regenerates_stance", false)
	return target


func _make_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "LightningSparkChainTestFloor"
	floor.position = Vector3(0.0, -0.1, 3.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20.0, 0.2, 20.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor


func _get_health(target: CombatTrainingTarget) -> int:
	var receiver: Node = target.get_node_or_null("HitReceiver")
	return int(receiver.get("current_health")) if receiver != null else -1


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
	push_error("LIGHTNING_SPARK_CHAIN_SMOKE_TEST: " + label)


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
		print("LIGHTNING_SPARK_CHAIN_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("LIGHTNING_SPARK_CHAIN_SMOKE_TEST: " + failure)
	get_tree().quit(1)
