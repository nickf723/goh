extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const MetalNeedleAbility: AbilityDefinition = preload(
	"res://data/abilities/metal_needle_ability.tres"
)
const HitReceiverScript = preload(
	"res://scripts/combat/hit_receiver.gd"
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
	player.name = "MetalNeedleFanTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	for _frame: int in range(18):
		await get_tree().process_frame
	await get_tree().physics_frame

	var caster: Node = player.get_node_or_null("AbilityCaster")
	var needle_index: int = _find_ability_index(caster, "metal_needle")
	_expect(caster != null, "Metal Needle test resolves AbilityCaster")
	_expect(needle_index >= 0, "Grace's runtime loadout contains Metal Needle")
	if caster == null or needle_index < 0:
		_finish([player, floor])
		return

	var starting_mana: int = GameState.get_stat("mana")
	caster.call("select_ability", needle_index, false)
	_expect(
		bool(caster.call("cast_from_player", player, 0.0, false)),
		"Metal Needle casts through the ordinary AbilityCaster path"
	)
	_expect(
		GameState.get_stat("mana") == starting_mana - 2,
		"Metal Needle spends its two-Mana volley cost"
	)
	var ordinary_fan: MetalNeedleFan = _find_fan_for_player(player)
	_expect(ordinary_fan != null, "ordinary casting creates one fan controller")
	if ordinary_fan != null:
		ordinary_fan.finish_volley()
	await get_tree().process_frame

	var fan_targets: Array[CharacterBody3D] = []
	var selected_angles: Array[float] = [-27.0, -13.5, 0.0, 13.5, 27.0]
	for target_index: int in range(selected_angles.size()):
		var direction: Vector3 = Vector3.FORWARD.rotated(
			Vector3.UP,
			deg_to_rad(selected_angles[target_index])
		)
		var target: CharacterBody3D = _make_target(
			"FanWitness" + str(target_index + 1),
			direction * 8.0,
			0.76
		)
		fan_targets.append(target)
		add_child(target)
	await get_tree().physics_frame

	var effects_before: int = get_tree().get_node_count_in_group("spell_effects")
	var fan: MetalNeedleFan = _spawn_direct_fan(player, Vector3.FORWARD)
	_expect(fan != null, "direct fan fixture instantiates")
	if fan == null:
		_finish([player, floor] + fan_targets)
		return
	fan.set_physics_process(false)
	for _tick: int in range(24):
		fan.advance_volley(0.02)
		await get_tree().physics_frame

	var fan_debug: Dictionary = fan.get_debug_data()
	var shared_serial: int = 0
	for target: CharacterBody3D in fan_targets:
		var serial: int = int(
			target.get_meta("metal_needle_fan_last_serial", 0)
		)
		_expect(serial > 0, str(target.name) + " is struck by the fan")
		if shared_serial == 0:
			shared_serial = serial
		else:
			_expect(
				serial == shared_serial,
				"every separated target records the same volley serial"
			)
	_expect(
		int(fan_debug.get("needle_count", 0)) == 9,
		"Metal Needle launches nine authored needles"
	)
	_expect(
		int(fan_debug.get("unique_targets", 0)) >= 5,
		"one fan reaches at least five separated targets"
	)
	_expect(
		int(fan_debug.get("multimeshes", 0)) == 1
		and int(fan_debug.get("needle_instances", 0)) == 9
		and int(fan_debug.get("per_needle_nodes", -1)) == 0,
		"all nine needles render through one MultiMesh"
	)
	_expect(
		not bool(fan_debug.get("persistent", true)),
		"Metal Needle is a temporary burst, not a persistent effect"
	)
	fan.finish_volley()
	await get_tree().process_frame
	for target: CharacterBody3D in fan_targets:
		target.queue_free()
	await get_tree().process_frame

	var close_target: CharacterBody3D = _make_target(
		"ClosePressWitness",
		Vector3.FORWARD * 2.8,
		1.18
	)
	add_child(close_target)
	await get_tree().physics_frame
	var close_fan: MetalNeedleFan = _spawn_direct_fan(player, Vector3.FORWARD)
	_expect(close_fan != null, "close-pressure fan fixture instantiates")
	if close_fan != null:
		close_fan.set_physics_process(false)
		for _tick: int in range(18):
			close_fan.advance_volley(0.02)
			await get_tree().physics_frame
		var close_hits: int = int(
			close_target.get_meta("metal_needle_fan_hits_from_serial", 0)
		)
		_expect(
			close_hits == 3,
			"a close target receives the authored three-needle multihit cap"
		)
		_expect(
			int(close_fan.get_debug_data().get("total_hits", 0)) == 3,
			"extra intersecting needles stop without exceeding the damage cap"
		)
		close_fan.finish_volley()
	await get_tree().process_frame
	_expect(
		get_tree().get_node_count_in_group("spell_effects") == effects_before,
		"all Metal Needle fan effects cleanly return to baseline"
	)

	_finish([player, close_target, floor])


func _test_ability_contract() -> void:
	_expect(
		MetalNeedleAbility.get_spell_id() == "metal_needle",
		"Metal Needle keeps its stable spell ID"
	)
	_expect(MetalNeedleAbility.element == "metal", "Metal Needle belongs to Metal")
	_expect(MetalNeedleAbility.mana_cost == 2, "Metal Needle costs two Mana")
	_expect(
		MetalNeedleAbility.ability_scene != null
		and MetalNeedleAbility.ability_scene.resource_path
		== "res://scenes/actions/metal_needle_fan.tscn",
		"Metal Needle uses its dedicated fan action"
	)
	_expect(
		MetalNeedleAbility.get_delivery_type() == "projectile_fan",
		"Metal Needle advertises projectile-fan delivery"
	)
	var payload: DamagePayload = MetalNeedleAbility.get_action_payload() as DamagePayload
	_expect(
		payload != null
		and payload.amount == 1
		and payload.stance_damage == 1
		and payload.tags.has("volley"),
		"each needle carries one-point metal puncture pressure"
	)


func _spawn_direct_fan(
	player: CharacterBody3D,
	direction: Vector3
) -> MetalNeedleFan:
	var fan: MetalNeedleFan = (
		MetalNeedleAbility.ability_scene.instantiate() as MetalNeedleFan
	)
	if fan == null:
		return null
	fan.set_payload(MetalNeedleAbility.get_action_payload())
	fan.set_source_actor(player)
	add_child(fan)
	fan.execute(player, direction)
	return fan


func _find_fan_for_player(player: Node) -> MetalNeedleFan:
	for effect: Node in get_tree().get_nodes_in_group("metal_needle_fan_effects"):
		if (
			effect is MetalNeedleFan
			and (effect as MetalNeedleFan).belongs_to_source(player)
		):
			return effect as MetalNeedleFan
	return null


func _find_ability_index(caster: Node, spell_id: String) -> int:
	if caster == null:
		return -1
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return -1
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
	for ability_index: int in range(loadout.get_equipped_ability_count()):
		var ability: AbilityDefinition = loadout.get_equipped_ability(ability_index)
		if ability != null and ability.get_spell_id() == spell_id:
			return ability_index
	return -1


func _make_target(
	node_name: String,
	position_value: Vector3,
	radius: float
) -> CharacterBody3D:
	var target := CharacterBody3D.new()
	target.name = node_name
	target.position = position_value + Vector3.UP * 1.0
	target.collision_layer = 1
	target.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = 2.0
	collision.shape = shape
	target.add_child(collision)
	var hit_receiver: Node = HitReceiverScript.new()
	hit_receiver.name = "HitReceiver"
	hit_receiver.set("target_name", node_name)
	hit_receiver.set("hit_mode", 2)
	hit_receiver.set("max_health", 40)
	hit_receiver.set("current_health", 40)
	hit_receiver.set("max_stance", 20)
	hit_receiver.set("current_stance", 20)
	hit_receiver.set("regenerates_stance", false)
	target.add_child(hit_receiver)
	return target


func _make_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "MetalNeedleFanTestFloor"
	floor.position = Vector3(0.0, -0.1, -5.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40.0, 0.2, 40.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor


func _prepare_stats() -> void:
	GameState.set_stat("max_health", 100)
	GameState.set_stat("health", 100)
	GameState.set_stat("max_mana", 80)
	GameState.set_stat("mana", 80)
	GameState.set_stat("max_stamina", 40)
	GameState.set_stat("stamina", 40)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("METAL_NEEDLE_FAN_SMOKE_TEST: " + label)


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
		print("METAL_NEEDLE_FAN_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("METAL_NEEDLE_FAN_SMOKE_TEST: " + failure)
	get_tree().quit(1)
