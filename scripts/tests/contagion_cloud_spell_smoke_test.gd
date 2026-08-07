extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const ContagionAbility: AbilityDefinition = preload(
	"res://data/abilities/contagion_cloud_ability.tres"
)
const StatusReceiverScript = preload(
	"res://scripts/combat/status_receiver.gd"
)
const HitReceiverScript = preload(
	"res://scripts/combat/hit_receiver.gd"
)
const GasManagerScript = preload(
	"res://scripts/gas/gas_manager.gd"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	_prepare_stats()
	_test_ability_contract()

	var gas_manager: Node = GasManagerScript.new()
	gas_manager.name = "ContagionCloudTestGasManager"
	add_child(gas_manager)
	var floor: StaticBody3D = _make_floor()
	add_child(floor)
	var wall: StaticBody3D = _make_wall()
	add_child(wall)
	var targets: Array[CharacterBody3D] = [
		_make_target("ContagionWitnessA", Vector3(0.0, 1.0, 5.0)),
		_make_target("ContagionWitnessB", Vector3(0.0, 1.0, 9.0)),
		_make_target("ContagionWitnessC", Vector3(0.0, 1.0, 13.0)),
	]
	for target: CharacterBody3D in targets:
		add_child(target)
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "ContagionCloudTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	player.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	add_child(player)
	for _frame: int in range(18):
		await get_tree().process_frame
	await get_tree().physics_frame

	var caster: Node = player.get_node_or_null("AbilityCaster")
	var cloud_index: int = _find_contagion_index(caster)
	_expect(caster != null, "Contagion Cloud test resolves AbilityCaster")
	_expect(cloud_index >= 0, "Grace's runtime loadout contains Contagion Cloud")
	if caster == null or cloud_index < 0:
		_finish([player, wall, floor, gas_manager] + targets)
		return

	var spell_effects_before: int = get_tree().get_node_count_in_group(
		"spell_effects"
	)
	var persistent_before: int = get_tree().get_node_count_in_group(
		"persistent_spell_effects"
	)
	var starting_mana: int = GameState.get_stat("mana")
	caster.call("select_ability", cloud_index, false)
	var cloud: ContagionCloud = _spawn_direct_cloud(
		player,
		Vector3(0.0, 0.0, 1.0)
	)
	_expect(cloud != null, "Contagion Cloud action instantiates")
	if cloud == null:
		_finish([player, wall, floor, gas_manager] + targets)
		return
	_expect(
		GameState.get_stat("mana") == starting_mana,
		"direct fixture does not mutate Mana outside AbilityCaster"
	)
	_expect(
		cloud.travel_speed < float(player.get("move_speed")),
		"Grace's ordinary run speed can outpace the cloud"
	)
	_expect(
		get_tree().get_node_count_in_group("spell_effects")
		== spell_effects_before + 1,
		"active cloud registers one spell effect"
	)
	_expect(
		get_tree().get_node_count_in_group("persistent_spell_effects")
		== persistent_before + 1,
		"active cloud registers one timed persistent effect"
	)
	_expect(
		get_tree().get_node_count_in_group("gas_volumes") >= 1,
		"Contagion Cloud registers as a shared gas volume"
	)
	_expect(
		float(gas_manager.call("sample_density", cloud.global_position, "poison")) > 0.8,
		"GasManager samples dense poison at the cloud center"
	)
	_expect(
		float(gas_manager.call(
			"sample_density",
			cloud.global_position + Vector3.RIGHT * 12.0,
			"poison"
		)) <= 0.001,
		"gas density falls to zero outside the cloud radius"
	)

	cloud.set_physics_process(false)
	for _tick: int in range(65):
		cloud.advance_cloud(0.1)
		await get_tree().physics_frame

	var contact_debug: Dictionary = cloud.get_debug_data()
	var cloud_serial: int = int(contact_debug.get("cast_serial", 0))
	_expect(cloud_serial > 0, "Contagion Cloud publishes a cast serial")
	_expect(
		int(contact_debug.get("unique_infected", 0)) >= 3,
		"one moving cloud infects all three separated witnesses"
	)
	for target: CharacterBody3D in targets:
		_expect(
			int(target.get_meta("contagion_cloud_last_serial", 0))
			== cloud_serial,
			str(target.name) + " records the same passing cloud serial"
		)
	_expect(
		bool(contact_debug.get("active", false)),
		"contact with targets and architecture does not dissipate the cloud"
	)
	_expect(
		not bool(contact_debug.get("movement_active", true)),
		"solid architecture stops cloud movement"
	)
	_expect(
		str(contact_debug.get("movement_stop_reason", ""))
		== "solid_contact",
		"the stopped cloud reports solid contact rather than impact destruction"
	)
	_expect(
		int(contact_debug.get("movement_contacts", 0)) == 1,
		"the cloud records one bounded architecture stop"
	)
	_expect(
		float(contact_debug.get("life_remaining", 0.0)) > 0.5,
		"a wall-stopped cloud retains substantial timed life"
	)
	_expect(
		int(contact_debug.get("puff_multimeshes", 0)) == 1
		and int(contact_debug.get("puff_instances", 0)) >= 20
		and int(contact_debug.get("per_puff_nodes", -1)) == 0,
		"the large gas ball uses one MultiMesh with no per-puff nodes"
	)

	var stopped_position: Vector3 = cloud.global_position
	var life_before_linger: float = float(
		contact_debug.get("life_remaining", 0.0)
	)
	cloud.advance_cloud(0.4)
	await get_tree().physics_frame
	var linger_debug: Dictionary = cloud.get_debug_data()
	_expect(
		cloud.global_position.distance_to(stopped_position) < 0.01,
		"a blocked cloud lingers in place rather than tunneling through the wall"
	)
	_expect(
		float(linger_debug.get("life_remaining", 0.0))
		< life_before_linger,
		"blocked cloud lifetime continues counting down"
	)

	var remaining: float = float(linger_debug.get("life_remaining", 0.0))
	cloud.advance_cloud(remaining + 0.1)
	await get_tree().process_frame
	_expect(
		get_tree().get_node_count_in_group("spell_effects") == spell_effects_before,
		"time expiration removes the cloud from temporary spell effects"
	)
	_expect(
		get_tree().get_node_count_in_group("persistent_spell_effects")
		== persistent_before,
		"time expiration removes the cloud from persistent effects"
	)

	# Ordinary casting still pays the authored upfront cost and creates one cloud.
	GameState.set_stat("mana", starting_mana)
	caster.call("select_ability", cloud_index, false)
	var cast_result: bool = bool(
		caster.call("cast_from_player", player, 0.0, false)
	)
	_expect(cast_result, "Contagion Cloud casts through the ordinary AbilityCaster path")
	_expect(
		GameState.get_stat("mana") == starting_mana - ContagionAbility.mana_cost,
		"ordinary Contagion Cloud casting spends three Mana"
	)
	var ordinary_cloud: ContagionCloud = _find_cloud_for_player(player)
	_expect(ordinary_cloud != null, "ordinary casting creates one active moving cloud")
	if ordinary_cloud != null:
		ordinary_cloud.finish_cloud("test_cleanup")
	await get_tree().process_frame

	_finish([player, wall, floor, gas_manager] + targets)


func _test_ability_contract() -> void:
	_expect(
		ContagionAbility.get_spell_id() == "contagion_cloud",
		"Contagion Cloud has a stable spell ID"
	)
	_expect(ContagionAbility.element == "poison", "Contagion Cloud belongs to Poison")
	_expect(ContagionAbility.mana_cost == 3, "Contagion Cloud costs three Mana")
	_expect(
		ContagionAbility.ability_scene != null
		and ContagionAbility.ability_scene.resource_path
		== "res://scenes/actions/contagion_cloud.tscn",
		"Contagion Cloud uses its dedicated moving-field action"
	)
	_expect(
		ContagionAbility.get_delivery_type() == "moving_field",
		"Contagion Cloud advertises moving-field delivery"
	)
	_expect(
		ContagionAbility.get_roles().has("damage_over_time")
		and ContagionAbility.get_roles().has("area_control"),
		"Contagion Cloud exposes poison-over-time and area-control roles"
	)
	var payload: DamagePayload = ContagionAbility.get_action_payload() as DamagePayload
	_expect(
		payload != null
		and payload.amount == 0
		and payload.status_effect == "poisoned",
		"the cloud applies Poisoned without impact damage"
	)


func _spawn_direct_cloud(
	player: CharacterBody3D,
	direction: Vector3
) -> ContagionCloud:
	var cloud: ContagionCloud = (
		ContagionAbility.ability_scene.instantiate() as ContagionCloud
	)
	if cloud == null:
		return null
	cloud.set_payload(ContagionAbility.get_action_payload())
	cloud.set_source_actor(player)
	add_child(cloud)
	cloud.execute(player, direction)
	return cloud


func _find_cloud_for_player(player: Node) -> ContagionCloud:
	for candidate: Node in get_tree().get_nodes_in_group(
		"contagion_cloud_effects"
	):
		if (
			candidate is ContagionCloud
			and (candidate as ContagionCloud).belongs_to_source(player)
		):
			return candidate as ContagionCloud
	return null


func _find_contagion_index(caster: Node) -> int:
	if caster == null:
		return -1
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return -1
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
	for ability_index: int in range(loadout.get_equipped_ability_count()):
		var ability: AbilityDefinition = loadout.get_equipped_ability(ability_index)
		if ability != null and ability.get_spell_id() == "contagion_cloud":
			return ability_index
	return -1


func _make_target(
	node_name: String,
	position_value: Vector3
) -> CharacterBody3D:
	var target := CharacterBody3D.new()
	target.name = node_name
	target.position = position_value
	target.collision_layer = 1
	target.collision_mask = 1
	target.add_to_group("contagion_cloud_pass_through")
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.5
	shape.height = 2.0
	collision.shape = shape
	target.add_child(collision)
	var hit_receiver: Node = HitReceiverScript.new()
	hit_receiver.name = "HitReceiver"
	hit_receiver.set("target_name", node_name)
	hit_receiver.set("hit_mode", 2)
	hit_receiver.set("max_health", 30)
	hit_receiver.set("current_health", 30)
	hit_receiver.set("max_stance", 10)
	hit_receiver.set("current_stance", 10)
	hit_receiver.set("regenerates_stance", false)
	target.add_child(hit_receiver)
	var status_receiver: Node = StatusReceiverScript.new()
	status_receiver.name = "StatusReceiver"
	target.add_child(status_receiver)
	return target


func _make_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "ContagionCloudTestFloor"
	floor.position = Vector3(0.0, -0.1, 8.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20.0, 0.2, 40.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor


func _make_wall() -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.name = "ContagionCloudTestWall"
	wall.position = Vector3(0.0, 2.0, 18.0)
	wall.add_to_group("contagion_cloud_blocker")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(10.0, 5.0, 0.5)
	collision.shape = shape
	wall.add_child(collision)
	return wall


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
	push_error("CONTAGION_CLOUD_SPELL_SMOKE_TEST: " + label)


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
		print("CONTAGION_CLOUD_SPELL_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("CONTAGION_CLOUD_SPELL_SMOKE_TEST: " + failure)
	get_tree().quit(1)
