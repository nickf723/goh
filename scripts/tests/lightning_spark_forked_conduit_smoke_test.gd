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
const ControllerHapticPatternScript = preload(
	"res://scripts/input/controller_haptic_pattern.gd"
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
	var player := PlayerScene.instantiate() as CharacterBody3D
	player.name = "LightningSparkTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	player.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	player.set_meta("controller_vibration_scale", 0.5)
	add_child(player)

	var center: CombatTrainingTarget = _spawn_target(
		"CenterConeTarget",
		Vector3(0.0, 0.0, 3.5),
		10
	)
	var left: CombatTrainingTarget = _spawn_target(
		"LeftConeTarget",
		Vector3(-1.6, 0.0, 3.8),
		10
	)
	var outside: CombatTrainingTarget = _spawn_target(
		"OutsideConeTarget",
		Vector3(3.0, 0.0, 2.4),
		10
	)
	var far: CombatTrainingTarget = _spawn_target(
		"FarConeTarget",
		Vector3(0.0, 0.0, 6.0),
		10
	)

	for _frame: int in range(6):
		await get_tree().process_frame
	await get_tree().physics_frame

	var first_spark: LightningSparkBurst = _cast_spark(
		player,
		Vector3.BACK
	)
	_expect(first_spark != null, "Lightning Spark action instantiates")
	if first_spark != null:
		var debug: Dictionary = first_spark.get_debug_data()
		_expect(
			int(debug.get("hit_count", -1)) == 2,
			"one cone burst catches both exposed in-cone targets"
		)
		_expect(
			int(debug.get("visual_multimeshes", 0)) == 1,
			"procedural fan uses one MultiMesh"
		)
		_expect(
			int(debug.get("per_segment_nodes", -1)) == 0,
			"procedural branches create no per-segment nodes"
		)
		_expect(
			int(debug.get("visual_segments", 0)) > 0
			and int(debug.get("visual_segments", 0)) <= 56,
			"spark pattern stays inside its authored segment budget"
		)

	_expect(_get_health(center) == 8, "center target takes Lightning Spark damage")
	_expect(_get_health(left) == 8, "left target takes Lightning Spark damage")
	_expect(_get_health(outside) == 10, "target outside the cone remains untouched")
	_expect(_get_health(far) == 10, "target beyond short range remains untouched")
	_expect(_has_status(center, "stunned"), "cone hit applies Stunned")
	_expect(_has_status(left, "stunned"), "every exposed cone target is interrupted")

	for _frame: int in range(16):
		await get_tree().process_frame

	center.reset_target()
	left.reset_target()
	outside.reset_target()
	far.reset_target()
	var blocker: StaticBody3D = _make_blocker()
	add_child(blocker)
	center.global_position = Vector3(0.0, 0.0, 4.0)
	left.global_position = Vector3(-2.2, 0.0, 3.5)
	await get_tree().physics_frame

	var blocked_spark: LightningSparkBurst = _cast_spark(
		player,
		Vector3.BACK
	)
	_expect(blocked_spark != null, "second Lightning Spark action instantiates")
	_expect(
		_get_health(center) == 10,
		"solid architecture blocks the centerline target"
	)
	_expect(
		_get_health(left) == 8,
		"an exposed flanking target in the same cone is still struck"
	)

	_test_haptic_pattern(player)
	_finish([player, center, left, outside, far, blocker, floor])


func _test_ability_contract() -> void:
	_expect(
		LightningSparkAbility.ability_scene != null
		and LightningSparkAbility.ability_scene.resource_path
		== "res://scenes/actions/lightning_spark_burst.tscn",
		"Lightning Spark no longer uses the generic projectile scene"
	)
	_expect(
		LightningSparkAbility.category == AbilityDefinition.AbilityCategory.INSTANT,
		"Lightning Spark is categorized as an instant cast"
	)
	_expect(
		LightningSparkAbility.get_targeting_style() == "forward_cone",
		"Lightning Spark advertises forward-cone targeting"
	)
	_expect(
		LightningSparkAbility.get_delivery_type() == "instant_burst",
		"Lightning Spark advertises instant-burst delivery"
	)
	var payload: DamagePayload = (
		LightningSparkAbility.get_action_payload() as DamagePayload
	)
	_expect(payload != null, "Lightning Spark retains a DamagePayload")
	if payload != null:
		_expect(payload.hit_type == "cone_burst", "payload identifies cone-burst hits")
		_expect(not payload.tags.has("projectile"), "payload has no projectile tag")
		_expect(payload.tags.has("cone"), "payload exposes the cone tag")
		_expect(payload.status_effect == "stunned", "payload retains interrupt status")


func _test_haptic_pattern(source_actor: Node) -> void:
	var haptic: Node = ControllerHapticPatternScript.new()
	haptic.name = "LightningSparkHapticTest"
	haptic.set("native_output_enabled", false)
	add_child(haptic)
	var pattern: Array = [
		{"weak": 0.12, "strong": 0.78, "duration": 0.035},
		{"weak": 0.0, "strong": 0.0, "duration": 0.016},
		{"weak": 0.56, "strong": 0.2, "duration": 0.06},
		{"weak": 0.0, "strong": 0.0, "duration": 0.012},
		{"weak": 0.24, "strong": 0.44, "duration": 0.04},
	]
	var started: bool = bool(haptic.call(
		"play_pattern",
		"lightning_spark_test",
		pattern,
		source_actor,
		1.0,
		[7]
	))
	_expect(started, "virtual controller starts the haptic pattern")
	for _step: int in range(12):
		haptic.call("_process", 0.025)
	var debug: Dictionary = haptic.get_debug_data()
	_expect(
		is_equal_approx(float(debug.get("intensity_scale", -1.0)), 0.5),
		"haptic pattern respects the source vibration-scale hook"
	)
	_expect(
		int(debug.get("started_steps", 0)) == pattern.size(),
		"crack-buzz-snap pattern advances through every step"
	)
	_expect(
		int(debug.get("vibration_starts", 0)) == 3,
		"three powered pulses are separated by silent gaps"
	)
	_expect(
		int(debug.get("completed_patterns", 0)) == 1,
		"haptic pattern completes and stops cleanly"
	)


func _cast_spark(
	player: CharacterBody3D,
	direction: Vector3
) -> LightningSparkBurst:
	var spark := SparkScene.instantiate() as LightningSparkBurst
	add_child(spark)
	spark.set_source_actor(player)
	spark.set_payload(LightningSparkAbility.get_action_payload())
	spark.execute(player, direction)
	return spark


func _spawn_target(
	node_name: String,
	position_value: Vector3,
	health: int
) -> CombatTrainingTarget:
	var target := TargetScene.instantiate() as CombatTrainingTarget
	target.name = node_name
	target.target_label = node_name
	target.position = position_value
	add_child(target)
	var receiver: Node = target.get_node_or_null("HitReceiver")
	if receiver != null:
		receiver.set("max_health", health)
		receiver.set("current_health", health)
		receiver.set("max_stance", 12)
		receiver.set("current_stance", 12)
	return target


func _make_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "LightningSparkTestFloor"
	floor.position = Vector3(0.0, -0.1, 3.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20.0, 0.2, 20.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor


func _make_blocker() -> StaticBody3D:
	var blocker := StaticBody3D.new()
	blocker.name = "LightningSparkSightlineBlocker"
	blocker.position = Vector3(0.0, 1.0, 2.2)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.7, 2.2, 0.5)
	collision.shape = shape
	blocker.add_child(collision)
	return blocker


func _get_health(target: CombatTrainingTarget) -> int:
	var receiver: Node = target.get_node_or_null("HitReceiver")
	return int(receiver.get("current_health")) if receiver != null else -1


func _has_status(target: CombatTrainingTarget, status_name: String) -> bool:
	var receiver: Node = target.get_node_or_null("StatusReceiver")
	return (
		receiver != null
		and receiver.has_method("has_status")
		and bool(receiver.call("has_status", status_name))
	)


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
	push_error("LIGHTNING_SPARK_SMOKE_TEST: " + label)


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
		print("LIGHTNING_SPARK_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("LIGHTNING_SPARK_SMOKE_TEST: " + failure)
	get_tree().quit(1)
