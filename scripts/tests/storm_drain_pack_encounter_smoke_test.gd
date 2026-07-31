extends Node


const EncounterScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_storm_drain_pack_encounter_v1.tscn"
)
const MireSpitAttack: Resource = preload(
	"res://data/enemy_attacks/storm_drain_mire_spit_attack.tres"
)
const SparkPounceAttack: Resource = preload(
	"res://data/enemy_attacks/storm_drain_spark_pounce_attack.tres"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var encounter_value: Variant = EncounterScene.instantiate()
	_expect(encounter_value is Node3D, "Dedicated encounter scene instantiates")
	if not encounter_value is Node3D:
		_finish()
		return
	var encounter: Node3D = encounter_value as Node3D
	encounter.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(encounter)
	await get_tree().process_frame
	await get_tree().process_frame

	var enemy_root: Node = encounter.get_node_or_null("EnemyRoot")
	_expect(enemy_root != null, "Encounter exposes EnemyRoot")
	if enemy_root != null:
		_expect(enemy_root.get_child_count() == 4, "Encounter spawns four pack members")

	_test_member(
		enemy_root,
		"MireGremlin",
		"primer",
		"cautious",
		["Mire Spit", "Gremlin Bite", "Backstep"]
	)
	_test_member(
		enemy_root,
		"SparkGremlin",
		"payoff_specialist",
		"bold",
		["Spark Pounce", "Gremlin Bite", "Backstep"]
	)
	_test_member(
		enemy_root,
		"ShieldGremlin",
		"protector",
		"brute",
		["Guard Screech", "Gremlin Bite", "Backstep"]
	)
	_test_member(
		enemy_root,
		"RunnerGremlin",
		"skirmisher",
		"skittish",
		["Hookstep", "Gremlin Pounce", "Gremlin Bite"]
	)

	_expect(
		encounter.get_node_or_null("WaterChannel") != null,
		"Encounter includes the shallow reactive water channel"
	)
	_expect(
		encounter.get_node_or_null("TacticalDecisionOverlay") != null,
		"Encounter includes tactical telemetry"
	)
	_expect(
		encounter.get_node_or_null("LabResourceRegenerator") != null,
		"Encounter regenerates testing resources"
	)
	_expect(
		str(MireSpitAttack.call("get_action_id")) == "storm_drain_mire_spit",
		"Mire Spit exposes a stable action id"
	)
	_expect(
		MireSpitAttack.has_method("is_projectile_delivery")
		and bool(MireSpitAttack.call("is_projectile_delivery")),
		"Mire Spit uses projectile delivery"
	)
	_expect(
		MireSpitAttack.get("projectile_scene") is PackedScene,
		"Mire Spit owns a projectile scene"
	)
	_expect(
		str(SparkPounceAttack.call("get_action_id")) == "storm_drain_spark_pounce",
		"Spark Pounce exposes a stable action id"
	)
	_expect(
		SparkPounceAttack.has_method("is_projectile_delivery")
		and not bool(SparkPounceAttack.call("is_projectile_delivery")),
		"Spark Pounce remains a contact payoff"
	)
	_test_guard_support(enemy_root)

	if encounter.has_method("reset_lab"):
		encounter.call("reset_lab")
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		_expect(
			enemy_root != null and enemy_root.get_child_count() == 4,
			"Reset creates a fresh four-member pack"
		)
	else:
		_expect(false, "Encounter exposes reset_lab")

	encounter.queue_free()
	await get_tree().process_frame
	_finish()


func _test_member(
	enemy_root: Node,
	member_name: String,
	expected_role: String,
	expected_personality: String,
	expected_actions: Array[String]
) -> void:
	if enemy_root == null:
		return
	var member: Node = enemy_root.get_node_or_null(member_name)
	_expect(member != null, member_name + " exists")
	if member == null:
		return
	var brain: Node = member.get_node_or_null("EnemyBrain")
	_expect(brain != null, member_name + " has a tactical brain")
	if brain == null:
		return
	_expect(
		str(brain.get("tactical_squad_role_id")) == expected_role,
		member_name + " keeps its authored squad role"
	)
	_expect(
		str(brain.get("personality_id")) == expected_personality,
		member_name + " keeps its personality"
	)
	var action_names: Array[String] = []
	var options_value: Variant = brain.get("action_options")
	if options_value is Array:
		for option_value: Variant in options_value as Array:
			if not option_value is Resource:
				continue
			var option: Resource = option_value as Resource
			if not option.has_method("get_action"):
				continue
			var action_value: Variant = option.call("get_action")
			if not action_value is Resource:
				continue
			var action: Resource = action_value as Resource
			if action.has_method("get_display_name"):
				action_names.append(str(action.call("get_display_name")))
	action_names.sort()
	var expected_sorted: Array[String] = expected_actions.duplicate()
	expected_sorted.sort()
	_expect(
		action_names == expected_sorted,
		member_name + " receives its intended action library"
	)


func _test_guard_support(enemy_root: Node) -> void:
	if enemy_root == null:
		return
	var shield: Node = enemy_root.get_node_or_null("ShieldGremlin")
	var mire: Node = enemy_root.get_node_or_null("MireGremlin")
	if shield == null or mire == null:
		return
	var brain: Node = shield.get_node_or_null("EnemyBrain")
	var hit_receiver: Node = mire.get_node_or_null("HitReceiver")
	_expect(brain != null and hit_receiver != null, "Guard support test components exist")
	if brain == null or hit_receiver == null:
		return
	hit_receiver.set("current_stance", 1)
	_expect(
		int(brain.call("get_nearby_missing_stance")) > 0,
		"Protector detects damaged allied stance"
	)
	var restored: bool = bool(brain.call("_restore_ally_stance", mire))
	_expect(restored, "Guard Screech restores allied stance")
	_expect(int(hit_receiver.get("current_stance")) > 1, "Guard support changes stance state")


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("STORM_DRAIN_PACK_ENCOUNTER_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("STORM_DRAIN_PACK_ENCOUNTER_SMOKE_TEST: " + failure)
	get_tree().quit(1)
