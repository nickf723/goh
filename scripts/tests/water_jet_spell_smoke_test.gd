extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const WaterJetAbility: AbilityDefinition = preload(
	"res://data/abilities/water_jet_ability.tres"
)
const HitReceiverScript = preload(
	"res://scripts/combat/hit_receiver.gd"
)
const ForceReceiverScript = preload(
	"res://scripts/combat/force_receiver.gd"
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
	var wall: StaticBody3D = _make_wall()
	add_child(wall)
	var target: CharacterBody3D = _make_pressure_target()
	add_child(target)
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "WaterJetSpellTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	for _frame: int in range(18):
		await get_tree().process_frame
	await get_tree().physics_frame

	var caster: Node = player.get_node_or_null("AbilityCaster")
	_expect(caster != null, "Water Jet test resolves AbilityCaster")
	if caster == null:
		_finish([player, target, wall, floor])
		return
	var water_jet_index: int = _find_water_jet_index(caster)
	_expect(water_jet_index >= 0, "Grace's runtime loadout contains Water Jet")
	if water_jet_index < 0:
		_finish([player, target, wall, floor])
		return

	var spell_effects_before: int = get_tree().get_node_count_in_group(
		"spell_effects"
	)
	var persistent_before: int = get_tree().get_node_count_in_group(
		"persistent_spell_effects"
	)
	var starting_mana: int = GameState.get_stat("mana")
	caster.call("select_ability", water_jet_index, false)
	var cast_result: bool = bool(
		caster.call("cast_from_player", player, 0.0, false)
	)
	_expect(cast_result, "Water Jet casts through the ordinary AbilityCaster path")
	_expect(
		GameState.get_stat("mana") == starting_mana,
		"Water Jet pays no fixed upfront Mana cost"
	)
	var jet: WaterJetCast = _find_water_jet_for_player(player)
	_expect(jet != null, "ordinary casting creates one Water Jet channel")
	if jet == null:
		_finish([player, target, wall, floor])
		return
	jet.set_physics_process(false)
	jet.set_test_cast_held_override(true, true)
	jet.set_test_direction_override(Vector3(0.0, 0.0, -1.0), true)

	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	var force_receiver: ForceReceiver = target.get_node_or_null(
		"ForceReceiver"
	) as ForceReceiver
	var health_before: int = int(hit_receiver.get("current_health"))
	var stance_before: int = int(hit_receiver.get("current_stance"))
	for _tick: int in range(6):
		jet.advance_channel(0.12, true)
	var pressure_debug: Dictionary = jet.get_debug_data()
	var health_after: int = int(hit_receiver.get("current_health"))
	var stance_after: int = int(hit_receiver.get("current_stance"))
	var force_debug: Dictionary = force_receiver.get_debug_data()
	_expect(
		health_before - health_after >= 5,
		"Water Jet applies rapid one-point chip ticks"
	)
	_expect(
		stance_after == stance_before,
		"Water Jet chip pressure does not secretly damage stance"
	)
	_expect(
		float(force_debug.get("force", 0.0)) >= 3.0,
		"sustained Water Jet rapidly builds strong target knockback"
	)
	_expect(
		int(pressure_debug.get("chip_ticks", 0)) >= 6
		and int(pressure_debug.get("pressure_events", 0)) >= 6,
		"damage ticks and pressure scans remain separate rapid processes"
	)
	_expect(
		GameState.get_stat("mana") == starting_mana - 1,
		"continuous Water Jet drains Mana by elapsed channel time"
	)
	_expect(
		get_tree().get_node_count_in_group("spell_effects")
		== spell_effects_before + 1,
		"active Water Jet registers one temporary spell effect"
	)
	_expect(
		get_tree().get_node_count_in_group("persistent_spell_effects")
		== persistent_before,
		"Water Jet does not register as a lingering persistent field"
	)
	_expect(
		int(pressure_debug.get("visual_meshes", 0)) == 2
		and int(pressure_debug.get("splash_multimeshes", 0)) == 1
		and int(pressure_debug.get("per_splash_nodes", -1)) == 0,
		"Water Jet uses two stream meshes and one splash MultiMesh"
	)
	jet.finish_channel("pressure_test_complete")
	await get_tree().process_frame

	# Fractional debt survives short releases, preventing free rapid taps.
	player.set_meta("water_jet_mana_debt", 0.0)
	GameState.set_stat("mana", 10)
	var first_tap: WaterJetCast = _cast_manual_jet(caster, player, water_jet_index)
	_expect(first_tap != null, "first short Water Jet tap starts")
	if first_tap != null:
		first_tap.advance_channel(0.2, true)
		first_tap.finish_channel("tap_one")
		await get_tree().process_frame
	_expect(GameState.get_stat("mana") == 10, "sub-Mana first tap stores fractional debt")
	var debt_after_first_tap: float = float(
		player.get_meta("water_jet_mana_debt", 0.0)
	)
	_expect(
		debt_after_first_tap >= 0.49 and debt_after_first_tap <= 0.51,
		"first tap preserves half a Mana of channel debt"
	)
	var second_tap: WaterJetCast = _cast_manual_jet(caster, player, water_jet_index)
	_expect(second_tap != null, "second short Water Jet tap starts")
	if second_tap != null:
		second_tap.advance_channel(0.2, true)
		second_tap.finish_channel("tap_two")
		await get_tree().process_frame
	_expect(
		GameState.get_stat("mana") == 9,
		"repeated short taps eventually pay the accumulated Mana cost"
	)

	# Nearby ground contact turns nozzle pressure into player propulsion.
	target.collision_layer = 0
	target.collision_mask = 0
	player.global_position = Vector3(0.0, 0.96, 0.0)
	player.velocity = Vector3.ZERO
	player.set_meta("water_jet_self_launch_serial", 0)
	GameState.set_stat("mana", 20)
	var launch_jet: WaterJetCast = _cast_manual_jet(
		caster,
		player,
		water_jet_index
	)
	_expect(launch_jet != null, "self-launch Water Jet channel starts")
	if launch_jet != null:
		launch_jet.set_test_direction_override(Vector3.DOWN, true)
		for _tick: int in range(9):
			launch_jet.advance_channel(0.05, true)
		var launch_debug: Dictionary = launch_jet.get_debug_data()
		_expect(
			player.velocity.y >= 3.4,
			"aiming Water Jet into nearby ground launches Grace upward"
		)
		_expect(
			int(player.get_meta("water_jet_self_launch_serial", 0)) == 1,
			"Water Jet publishes one self-launch event for traversal rooms"
		)
		_expect(
			float(launch_debug.get("last_recoil_strength", 0.0)) > 0.0
			and float(launch_debug.get("self_recoil_seconds", 0.0)) > 0.0,
			"self-launch comes from sustained surface recoil rather than a teleport"
		)
		launch_jet.finish_channel("launch_test_complete")
		await get_tree().process_frame

	_expect(
		get_tree().get_node_count_in_group("spell_effects") == spell_effects_before,
		"all Water Jet channels return temporary spell effects to baseline"
	)
	_expect(
		get_tree().get_node_count_in_group("persistent_spell_effects")
		== persistent_before,
		"Water Jet leaves no persistent-effect leak"
	)
	_finish([player, target, wall, floor])


func _cast_manual_jet(
	caster: Node,
	player: CharacterBody3D,
	water_jet_index: int
) -> WaterJetCast:
	caster.call("select_ability", water_jet_index, false)
	if not bool(caster.call("cast_from_player", player, 0.0, false)):
		return null
	var jet: WaterJetCast = _find_water_jet_for_player(player)
	if jet == null:
		return null
	jet.set_physics_process(false)
	jet.set_test_cast_held_override(true, true)
	jet.set_test_direction_override(Vector3(0.0, 0.0, -1.0), true)
	return jet


func _find_water_jet_for_player(player: Node) -> WaterJetCast:
	for effect: Node in get_tree().get_nodes_in_group("water_jet_effects"):
		if (
			effect is WaterJetCast
			and effect.has_method("belongs_to_source")
			and bool(effect.call("belongs_to_source", player))
		):
			return effect as WaterJetCast
	return null


func _find_water_jet_index(caster: Node) -> int:
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return -1
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
	for ability_index: int in range(loadout.get_equipped_ability_count()):
		var ability: AbilityDefinition = loadout.get_equipped_ability(ability_index)
		if ability != null and ability.get_spell_id() == "water_jet":
			return ability_index
	return -1


func _test_ability_contract() -> void:
	_expect(WaterJetAbility.get_spell_id() == "water_jet", "Water Jet has a stable spell ID")
	_expect(WaterJetAbility.element == "water", "Water Jet belongs to Water")
	_expect(WaterJetAbility.mana_cost == 0, "Water Jet has no fixed upfront Mana cost")
	_expect(
		WaterJetAbility.ability_scene != null
		and WaterJetAbility.ability_scene.resource_path
		== "res://scenes/actions/water_jet_cast.tscn",
		"Water Jet uses its dedicated continuous action"
	)
	_expect(
		WaterJetAbility.get_delivery_type() == "channel",
		"Water Jet advertises channel delivery"
	)
	_expect(
		WaterJetAbility.get_roles().has("force")
		and WaterJetAbility.get_roles().has("self_propulsion"),
		"Water Jet exposes target pressure and traversal recoil roles"
	)
	var payload: DamagePayload = WaterJetAbility.get_action_payload() as DamagePayload
	_expect(
		payload != null
		and payload.amount == 1
		and payload.stance_damage == 0
		and payload.status_effect == "wet",
		"Water Jet payload is one-point Wet chip with zero stance damage"
	)


func _make_pressure_target() -> CharacterBody3D:
	var target := CharacterBody3D.new()
	target.name = "WaterJetPressureTarget"
	target.position = Vector3(0.0, 1.0, -4.0)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.55
	shape.height = 2.0
	collision.shape = shape
	target.add_child(collision)
	var hit_receiver: Node = HitReceiverScript.new()
	hit_receiver.name = "HitReceiver"
	hit_receiver.set("target_name", "Pressure Target")
	hit_receiver.set("hit_mode", 2)
	hit_receiver.set("max_health", 100)
	hit_receiver.set("current_health", 100)
	hit_receiver.set("max_stance", 20)
	hit_receiver.set("current_stance", 20)
	hit_receiver.set("regenerates_stance", false)
	target.add_child(hit_receiver)
	var force_receiver: ForceReceiver = ForceReceiverScript.new() as ForceReceiver
	force_receiver.name = "ForceReceiver"
	force_receiver.max_force_speed = 12.0
	target.add_child(force_receiver)
	return target


func _make_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "WaterJetSmokeFloor"
	floor.position = Vector3(0.0, -0.1, 0.0)
	floor.add_to_group("water_jet_recoil_surface")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(60.0, 0.2, 60.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor


func _make_wall() -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.name = "WaterJetSmokeWall"
	wall.position = Vector3(0.0, 2.0, -8.0)
	wall.add_to_group("water_jet_recoil_surface")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(8.0, 4.0, 0.5)
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
	push_error("WATER_JET_SPELL_SMOKE_TEST: " + label)


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
		print("WATER_JET_SPELL_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("WATER_JET_SPELL_SMOKE_TEST: " + failure)
	get_tree().quit(1)
