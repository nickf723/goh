extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const BoulderScene: PackedScene = preload(
	"res://scenes/actions/earth_boulder.tscn"
)
const BoulderAbility: AbilityDefinition = preload(
	"res://data/abilities/boulder_ability.tres"
)
const PressurePlateScene: PackedScene = preload(
	"res://scenes/mechanisms/pressure_plate_switch.tscn"
)
const HitReceiverScript = preload(
	"res://scripts/combat/hit_receiver.gd"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}
var original_quick_spell_loadouts: Dictionary = {}
var original_quick_spell_selected_slots: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	original_quick_spell_loadouts = GameState.quick_spell_loadouts.duplicate(true)
	original_quick_spell_selected_slots = (
		GameState.quick_spell_selected_slots.duplicate(true)
	)
	_prepare_stats()
	_test_ability_contract()

	var floor: StaticBody3D = _make_floor()
	add_child(floor)
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "BoulderSpellTestPlayer"
	player.position = Vector3(0.0, 1.0, 0.0)
	player.add_to_group("player")
	add_child(player)
	await _wait_frames(18)
	await get_tree().physics_frame

	var caster: Node = player.get_node_or_null("AbilityCaster")
	var boulder_index: int = _find_ability_index(caster, "boulder")
	_expect(caster != null, "Boulder test resolves AbilityCaster")
	_expect(boulder_index >= 0, "Grace's runtime loadout contains Boulder")
	if caster == null or boulder_index < 0:
		_finish([player, floor])
		return

	var baseline_effects: int = get_tree().get_node_count_in_group(
		"earth_boulder_effects"
	)
	var starting_mana: int = GameState.get_stat("mana")
	caster.call("select_ability", boulder_index, false)
	_expect(
		bool(caster.call("cast_from_player", player, 0.0, false)),
		"Boulder casts through the ordinary AbilityCaster path"
	)
	_expect(
		GameState.get_stat("mana") == starting_mana - 3,
		"Boulder spends its three-Mana formation cost"
	)
	var ordinary_boulder: Node = _find_boulder_for_source(player)
	_expect(ordinary_boulder != null, "ordinary casting creates one rolling RigidBody")
	if ordinary_boulder != null:
		var ordinary_debug: Dictionary = ordinary_boulder.call("get_debug_data") as Dictionary
		_expect(
			is_equal_approx(float(ordinary_debug.get("mass_kg", 0.0)), 160.0),
			"Boulder exposes its authored 160 kg physical mass"
		)
		_expect(
			str(ordinary_debug.get("lifetime_mode", "")) == "motion_settle"
			and not bool(ordinary_debug.get("has_fixed_lifetime", true)),
			"Boulder lifetime is controlled by motion instead of a timer"
		)
		ordinary_boulder.call("reset_target")
	await get_tree().process_frame

	var impact_target: CharacterBody3D = _make_impact_target(
		"BoulderImpactWitness",
		Vector3(0.0, 1.0, 6.0)
	)
	add_child(impact_target)
	await get_tree().physics_frame
	var impact_boulder: Node = _spawn_direct_boulder(
		player,
		Vector3.FORWARD
	)
	_expect(impact_boulder != null, "direct Boulder fixture instantiates")
	if impact_boulder != null:
		for _frame: int in range(180):
			if int(impact_target.get_meta("boulder_last_cast_serial", 0)) > 0:
				break
			await get_tree().physics_frame
		var impact_serial: int = int(
			impact_target.get_meta("boulder_last_cast_serial", 0)
		)
		var impact_speed: float = float(
			impact_target.get_meta("boulder_last_impact_speed", 0.0)
		)
		var impact_energy: float = float(
			impact_target.get_meta("boulder_last_impact_energy", 0.0)
		)
		var hit_receiver: Node = impact_target.get_node_or_null("HitReceiver")
		_expect(impact_serial > 0, "rolling Boulder records its cast serial on impact")
		_expect(impact_speed >= 1.8, "rolling Boulder reaches damaging impact speed")
		_expect(impact_energy > 0.0, "rolling Boulder records physical impact energy")
		_expect(
			hit_receiver != null and int(hit_receiver.get("current_health")) < 80,
			"Boulder impact deals Earth health damage"
		)
		_expect(
			hit_receiver != null and int(hit_receiver.get("current_stance")) < 50,
			"Boulder impact applies heavy stance pressure"
		)
		if is_instance_valid(impact_boulder):
			impact_boulder.call("reset_target")
	impact_target.queue_free()
	await get_tree().process_frame

	player.position = Vector3(8.0, 1.0, -10.0)
	player.velocity = Vector3.ZERO
	var motion_boulder: Node = _spawn_direct_boulder(
		player,
		Vector3.FORWARD
	)
	_expect(motion_boulder != null, "motion-lifetime Boulder fixture instantiates")
	if motion_boulder != null:
		var motion_body: RigidBody3D = motion_boulder as RigidBody3D
		motion_body.linear_damp = 0.0
		motion_body.angular_damp = 0.0
		var frictionless := PhysicsMaterial.new()
		frictionless.friction = 0.0
		frictionless.bounce = 0.0
		motion_body.physics_material_override = frictionless
		motion_boulder.set("settle_confirmation_seconds", 0.22)
		motion_boulder.set("dissolve_seconds", 0.1)
		for _frame: int in range(240):
			if not is_instance_valid(motion_boulder):
				break
			motion_body.sleeping = false
			motion_body.linear_velocity = Vector3.FORWARD * 3.5
			motion_body.angular_velocity = Vector3.LEFT * 3.2
			await get_tree().physics_frame
		_expect(
			is_instance_valid(motion_boulder),
			"Boulder remains present after four seconds when motion continues"
		)
		if is_instance_valid(motion_boulder):
			var moving_debug: Dictionary = motion_boulder.call("get_debug_data") as Dictionary
			_expect(
				float(moving_debug.get("age_seconds", 0.0)) >= 3.5,
				"moving Boulder outlives ordinary projectile durations"
			)
			_expect(
				float(moving_debug.get("distance_travelled", 0.0)) >= 10.0,
				"moving Boulder accumulates a long physical route"
			)
			var plate: PressurePlateSwitch = (
				PressurePlateScene.instantiate() as PressurePlateSwitch
			)
			plate.name = "BoulderMassContractPlate"
			plate.position = Vector3(12.0, 0.0, 12.0)
			add_child(plate)
			await get_tree().process_frame
			_expect(
				is_equal_approx(plate.get_body_mass_kg(motion_body), 160.0),
				"weighted pressure plates read the Boulder as 160 kg"
			)
			plate.queue_free()
			motion_body.linear_velocity = Vector3.ZERO
			motion_body.angular_velocity = Vector3.ZERO
			motion_body.sleeping = true
			for _frame: int in range(120):
				if not is_instance_valid(motion_boulder):
					break
				await get_tree().process_frame
				await get_tree().physics_frame
			_expect(
				not is_instance_valid(motion_boulder),
				"Boulder dissipates after supported linear and rolling motion settle"
			)

	await _wait_frames(3)
	_expect(
		get_tree().get_node_count_in_group("earth_boulder_effects")
		== baseline_effects,
		"all Boulder effects return to baseline after cleanup"
	)
	_finish([player, floor])


func _test_ability_contract() -> void:
	_expect(BoulderAbility.get_spell_id() == "boulder", "Boulder keeps its stable spell ID")
	_expect(BoulderAbility.element == "earth", "Boulder belongs to Earth")
	_expect(BoulderAbility.mana_cost == 3, "Boulder costs three Mana")
	_expect(
		BoulderAbility.category == AbilityDefinition.AbilityCategory.PROJECTILE,
		"Boulder remains selectable as a projectile spell"
	)
	_expect(
		BoulderAbility.get_targeting_style() == "forward",
		"Boulder exposes a forward ground route"
	)
	_expect(
		BoulderAbility.get_delivery_type() == "rolling_rigid_body",
		"Boulder advertises real rolling-body delivery"
	)
	_expect(
		BoulderAbility.ability_scene != null
		and BoulderAbility.ability_scene.resource_path
		== "res://scenes/actions/earth_boulder.tscn",
		"Boulder uses its dedicated physical action scene"
	)
	var payload: DamagePayload = BoulderAbility.get_action_payload() as DamagePayload
	_expect(
		payload != null
		and payload.amount == 5
		and payload.stance_damage == 11
		and payload.tags.has("heavy_impact"),
		"Boulder carries heavy Earth impact pressure"
	)


func _spawn_direct_boulder(
	player: CharacterBody3D,
	direction: Vector3
) -> Node:
	var boulder: Node = BoulderScene.instantiate()
	if boulder == null:
		return null
	if boulder.has_method("set_payload"):
		boulder.call("set_payload", BoulderAbility.get_action_payload())
	if boulder.has_method("set_source_actor"):
		boulder.call("set_source_actor", player)
	add_child(boulder)
	if boulder.has_method("execute"):
		boulder.call("execute", player, direction)
	return boulder


func _find_boulder_for_source(player: Node) -> Node:
	for boulder: Node in get_tree().get_nodes_in_group("earth_boulder_effects"):
		if (
			boulder != null
			and is_instance_valid(boulder)
			and boulder.has_method("belongs_to_source")
			and bool(boulder.call("belongs_to_source", player))
		):
			return boulder
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


func _make_impact_target(
	node_name: String,
	position_value: Vector3
) -> CharacterBody3D:
	var target := CharacterBody3D.new()
	target.name = node_name
	target.position = position_value
	target.collision_layer = 1
	target.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.85
	shape.height = 2.1
	collision.shape = shape
	target.add_child(collision)
	var hit_receiver: Node = HitReceiverScript.new()
	hit_receiver.name = "HitReceiver"
	hit_receiver.set("target_name", node_name)
	hit_receiver.set("hit_mode", 2)
	hit_receiver.set("max_health", 80)
	hit_receiver.set("current_health", 80)
	hit_receiver.set("max_stance", 50)
	hit_receiver.set("current_stance", 50)
	hit_receiver.set("regenerates_stance", false)
	target.add_child(hit_receiver)
	return target


func _make_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "BoulderSpellTestFloor"
	floor.position = Vector3(0.0, -0.5, 20.0)
	floor.collision_layer = 1
	floor.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40.0, 1.0, 100.0)
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


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("BOULDER_SPELL_SMOKE_TEST: " + label)


func _restore_state() -> void:
	GameState.stats = original_stats.duplicate(true)
	for stat_value: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_value)
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_value]))
	GameState.quick_spell_loadouts = original_quick_spell_loadouts.duplicate(true)
	GameState.quick_spell_selected_slots = (
		original_quick_spell_selected_slots.duplicate(true)
	)


func _finish(nodes: Array) -> void:
	Engine.time_scale = 1.0
	_restore_state()
	for node_value: Variant in nodes:
		if node_value is Node and is_instance_valid(node_value as Node):
			(node_value as Node).queue_free()
	if failures.is_empty():
		print("BOULDER_SPELL_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("BOULDER_SPELL_SMOKE_TEST: " + failure)
	get_tree().quit(1)
