extends Node

const TrialScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_hollow_spire_spell_trial_v1.tscn"
)
const WindWellScene: PackedScene = preload(
	"res://scenes/actions/wind_well.tscn"
)
const WindWellPayload: DamagePayload = preload(
	"res://data/damage_payloads/wind_well_payload.tres"
)
const CombatTargetScene: PackedScene = preload(
	"res://scenes/actors/testing/combat_training_target.tscn"
)
const GroundSpells = preload(
	"res://scripts/abilities/ground_spell_registry.gd"
)
const SpellIcons = preload(
	"res://scripts/ui/spell_icon_factory.gd"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}
var original_completion_flag: bool = false


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	original_completion_flag = GameState.get_flag(
		"hollow_spire_spell_trial_complete"
	)
	_prepare_stats()

	var trial: PrototypeHollowSpireSpellTrial = (
		TrialScene.instantiate() as PrototypeHollowSpireSpellTrial
	)
	_expect(trial != null, "Hollow Spire spell trial instantiates")
	if trial == null:
		_finish()
		return
	add_child(trial)
	await _wait_frames(14)
	await get_tree().physics_frame

	var regenerator: LabResourceRegenerator = trial.get_node_or_null(
		"LabResourceRegenerator"
	) as LabResourceRegenerator
	if regenerator != null:
		regenerator.set_process(false)

	var player: CharacterBody3D = trial.player
	var caster: Node = (
		player.get_node_or_null("AbilityCaster")
		if player != null
		else null
	)
	_expect(player != null, "trial contains Grace")
	_expect(caster != null, "Grace retains the shared AbilityCaster")
	_expect(
		trial.get_node_or_null("AirflowManager") is AirflowManager,
		"trial contains the shared AirflowManager"
	)
	if player == null or caster == null:
		trial.queue_free()
		await get_tree().process_frame
		_finish()
		return

	var wind_well_ability: AbilityDefinition = _find_ability(
		caster,
		"wind_well"
	)
	var wind_gust_ability: AbilityDefinition = _find_ability(
		caster,
		"wind_gust"
	)
	_expect(
		wind_well_ability != null,
		"Wind Well is present in Grace's spell library"
	)
	if wind_well_ability == null:
		trial.queue_free()
		await get_tree().process_frame
		_finish()
		return

	_test_ability_contract(wind_well_ability, wind_gust_ability)
	await _test_ground_target_cast(
		trial,
		player,
		caster,
		wind_well_ability
	)
	await _test_mass_response(trial, player)
	await _test_player_lift_and_zero_damage(trial, player)
	await _test_lifetime(player)
	await _test_trial_progression_and_reset(trial, player)

	trial.queue_free()
	await get_tree().process_frame
	_finish()


func _test_ability_contract(
	ability: AbilityDefinition,
	gust_ability: AbilityDefinition
) -> void:
	_expect(ability.mana_cost == 3, "Wind Well costs three Mana")
	_expect(
		ability.get_delivery_type() == "updraft_field",
		"Wind Well identifies its persistent updraft delivery"
	)
	_expect(
		WindWellPayload.amount == 0,
		"Wind Well payload deals zero health damage"
	)
	_expect(
		WindWellPayload.stance_damage == 0,
		"Wind Well payload deals zero stance damage"
	)
	_expect(
		WindWellPayload.suppress_reactions,
		"Wind Well cannot create a damaging reaction through its payload"
	)
	var definition: Dictionary = GroundSpells.get_definition_for_ability(
		ability
	)
	_expect(
		not definition.is_empty(),
		"Wind Well is registered for ground targeting"
	)
	_expect(
		str(definition.get("post_spawn_method", "")) == "begin_well",
		"confirming the marker starts the persistent updraft"
	)
	_expect(
		is_equal_approx(
			GroundSpells.get_target_radius(definition, 0.0),
			2.8
		),
		"Wind Well targeting preview matches its field radius"
	)
	var well_glyph: String = SpellIcons.get_glyph(
		SpellIcons.entry_from_ability(ability)
	)
	_expect(well_glyph == "↑", "Wind Well uses its upward-current symbol")
	if gust_ability != null:
		var gust_glyph: String = SpellIcons.get_glyph(
			SpellIcons.entry_from_ability(gust_ability)
		)
		_expect(
			well_glyph != gust_glyph,
			"Wind Well and Wind Gust remain distinguishable in Focus and quick slots"
		)


func _test_ground_target_cast(
	trial: PrototypeHollowSpireSpellTrial,
	player: CharacterBody3D,
	caster: Node,
	ability: AbilityDefinition
) -> void:
	trial.reset_trial()
	await _wait_frames(3)
	GameState.set_stat("mana", 20)
	_select_ability(caster, ability)
	player.global_position = Vector3(0.0, 1.0, -3.5)
	player.rotation = Vector3(0.0, PI, 0.0)
	_aim_player_straight_ahead(player)
	await get_tree().physics_frame

	var mana_before: int = GameState.get_stat("mana")
	var targeting_started: bool = bool(
		caster.call("cast_from_player", player, 0.18, false)
	)
	_expect(
		targeting_started,
		"first Cast enters Wind Well ground targeting"
	)
	_expect(
		bool(caster.call("is_ground_targeting")),
		"Wind Well owns the ground marker before confirmation"
	)
	_expect(
		GameState.get_stat("mana") == mana_before,
		"positioning Wind Well does not spend Mana"
	)
	_expect(
		bool(caster.call("cast_from_player", player, 0.18, false)),
		"second Cast confirms Wind Well"
	)
	_expect(
		GameState.get_stat("mana") == mana_before - ability.mana_cost,
		"confirmed Wind Well spends its Mana exactly once"
	)
	await _wait_frames(4)
	var well: WindWell = _find_latest_well()
	_expect(well != null, "confirming the marker spawns Wind Well")
	if well == null:
		return
	_expect(well.well_running and well.active, "spawned Wind Well is active")
	var manager: AirflowManager = trial.get_node_or_null(
		"AirflowManager"
	) as AirflowManager
	_expect(
		manager != null and manager.registered_fields.has(well),
		"Wind Well registers with the shared airflow field manager"
	)
	well.finish_well()
	await get_tree().process_frame


func _test_mass_response(
	trial: PrototypeHollowSpireSpellTrial,
	player: CharacterBody3D
) -> void:
	trial.reset_trial()
	await _wait_frames(2)
	var well: WindWell = _spawn_test_well(
		trial,
		player,
		Vector3(0.0, 0.05, 6.5)
	)
	await get_tree().process_frame
	var light_response: AirflowResponse = trial.featherstone.get_node_or_null(
		"AirflowResponse"
	) as AirflowResponse
	var heavy_response: AirflowResponse = trial.anchorstone.get_node_or_null(
		"AirflowResponse"
	) as AirflowResponse
	_expect(light_response != null, "Featherstone exposes AirflowResponse")
	_expect(heavy_response != null, "Anchor stone exposes AirflowResponse")
	if light_response != null and heavy_response != null:
		var light_acceleration: Vector3 = light_response.get_airflow_acceleration(
			trial.featherstone.global_position,
			Vector3.ZERO,
			2.0
		)
		var heavy_acceleration: Vector3 = heavy_response.get_airflow_acceleration(
			trial.anchorstone.global_position,
			Vector3.ZERO,
			18.0
		)
		_expect(
			light_acceleration.y > heavy_acceleration.y,
			"the same updraft accelerates the light stone more strongly"
		)
		_expect(
			light_acceleration.y > trial.featherstone.gravity_strength,
			"Featherstone receives enough airflow acceleration to rise"
		)
		_expect(
			heavy_acceleration.y < trial.anchorstone.gravity_strength,
			"the 18 kg anchor remains too heavy for the base Wind Well"
		)
	_expect(
		well.get_volume_weight(Vector3.ZERO) > 0.95,
		"Wind Well begins at ground level instead of fading out at its base"
	)
	_expect(
		well.get_volume_weight(
			Vector3(0.0, well.cylinder_height + 0.1, 0.0)
		) <= 0.001,
		"Wind Well ends above its authored column height"
	)
	well.finish_well()
	await get_tree().process_frame


func _test_player_lift_and_zero_damage(
	trial: PrototypeHollowSpireSpellTrial,
	player: CharacterBody3D
) -> void:
	trial.reset_trial()
	await _wait_frames(2)
	var well: WindWell = _spawn_test_well(
		trial,
		player,
		Vector3(0.0, 0.05, 22.5)
	)
	player.global_position = Vector3(0.0, 1.0, 22.5)
	player.velocity = Vector3.ZERO
	var health_before: int = GameState.get_stat("health")
	_expect(
		well.apply_lift_step_to_target(player, 0.25, 1.0),
		"Wind Well directly supports Grace's traversal motion"
	)
	_expect(player.velocity.y > 0.1, "Wind Well gives Grace upward velocity")
	_expect(
		GameState.get_stat("health") == health_before,
		"Wind Well never damages Grace"
	)

	var target: CombatTrainingTarget = (
		CombatTargetScene.instantiate() as CombatTrainingTarget
	)
	target.name = "WindWellZeroDamageTarget"
	target.global_position = Vector3(0.0, 0.05, 22.5)
	trial.add_child(target)
	await get_tree().process_frame
	target.set_physics_process(false)
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	var target_health_before: int = int(hit_receiver.get("current_health"))
	var target_stance_before: int = int(hit_receiver.get("current_stance"))
	_expect(
		well.apply_lift_step_to_target(target, 0.25, 1.0),
		"Wind Well can lift a combat-capable CharacterBody"
	)
	_expect(target.velocity.y > 0.1, "combat target receives upward motion")
	_expect(
		int(hit_receiver.get("current_health")) == target_health_before,
		"Wind Well leaves target health unchanged"
	)
	_expect(
		int(hit_receiver.get("current_stance")) == target_stance_before,
		"Wind Well leaves target stance unchanged"
	)
	target.queue_free()
	well.finish_well()
	await get_tree().process_frame


func _test_lifetime(player: CharacterBody3D) -> void:
	var well: WindWell = WindWellScene.instantiate() as WindWell
	well.duration_seconds = 0.2
	add_child(well)
	well.global_position = Vector3(20.0, 0.05, 20.0)
	well.set_source_actor(player)
	well.begin_well()
	well.set_process(false)
	_expect(well.advance_well(0.1), "Wind Well remains active before duration expires")
	_expect(
		not well.advance_well(0.15),
		"Wind Well ends after its authored duration"
	)
	_expect(
		not well.well_running and not well.active,
		"expired Wind Well stops contributing airflow"
	)
	await get_tree().process_frame


func _test_trial_progression_and_reset(
	trial: PrototypeHollowSpireSpellTrial,
	player: CharacterBody3D
) -> void:
	trial.reset_trial()
	await _wait_frames(2)
	trial.call("_on_feather_goal_body_entered", trial.anchorstone)
	_expect(
		trial.stage
		== PrototypeHollowSpireSpellTrial.TrialStage.FEATHER_AND_STONE,
		"the heavy anchor cannot satisfy the Featherstone catch"
	)
	trial.call("_on_feather_goal_body_entered", trial.featherstone)
	_expect(trial.feather_gate.active, "lifting Featherstone opens the first gate")
	_expect(
		trial.stage
		== PrototypeHollowSpireSpellTrial.TrialStage.RIDE_CURRENT,
		"Featherstone delivery advances to the traversal room"
	)
	trial.call("_on_mastery_goal_body_entered", player)
	_expect(trial.trial_complete, "upper landing completes the Wind Well trial")
	_expect(
		GameState.get_flag(trial.completion_flag),
		"Hollow Spire records its mastery flag"
	)

	var active_well: WindWell = _spawn_test_well(
		trial,
		player,
		Vector3(0.0, 0.05, 22.5)
	)
	trial.reset_trial()
	await get_tree().process_frame
	_expect(
		trial.stage
		== PrototypeHollowSpireSpellTrial.TrialStage.FEATHER_AND_STONE,
		"reset restores the first trial stage"
	)
	_expect(not trial.feather_gate.active, "reset closes the Featherstone gate")
	_expect(
		not GameState.get_flag(trial.completion_flag),
		"reset clears the Wind Well mastery flag"
	)
	_expect(
		active_well == null
		or not is_instance_valid(active_well)
		or not active_well.active,
		"reset removes active Wind Well airflow"
	)
	_expect(
		trial.featherstone.global_position.distance_to(
			Vector3(-1.0, 0.05, 6.5)
		) < 0.05,
		"reset restores Featherstone to its authored start"
	)
	_expect(
		trial.anchorstone.global_position.distance_to(
			Vector3(1.0, 0.05, 6.5)
		) < 0.05,
		"reset restores the anchor stone to its authored start"
	)


func _spawn_test_well(
	parent: Node,
	player: Node3D,
	position_value: Vector3
) -> WindWell:
	var well: WindWell = WindWellScene.instantiate() as WindWell
	parent.add_child(well)
	well.global_position = position_value
	well.set_payload(WindWellPayload)
	well.set_source_actor(player)
	well.begin_well()
	return well


func _find_latest_well() -> WindWell:
	var nodes: Array[Node] = get_tree().get_nodes_in_group("wind_well_effects")
	for index: int in range(nodes.size() - 1, -1, -1):
		if nodes[index] is WindWell:
			return nodes[index] as WindWell
	return null


func _find_ability(caster: Node, spell_id: String) -> AbilityDefinition:
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return null
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
	for ability: AbilityDefinition in loadout.equipped_abilities:
		if ability != null and ability.get_spell_id() == spell_id:
			return ability
	return null


func _select_ability(caster: Node, ability: AbilityDefinition) -> void:
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
	var index: int = loadout.equipped_abilities.find(ability)
	if index >= 0:
		caster.call("select_ability", index, false)


func _aim_player_straight_ahead(player: CharacterBody3D) -> void:
	var camera_pivot: Node3D = player.get_node_or_null(
		"CameraPivot"
	) as Node3D
	if camera_pivot != null:
		camera_pivot.rotation = Vector3.ZERO
	var spring_arm: Node3D = player.get_node_or_null(
		"CameraPivot/SpringArm3D"
	) as Node3D
	if spring_arm != null:
		spring_arm.rotation = Vector3.ZERO


func _prepare_stats() -> void:
	GameState.set_stat("max_health", 100)
	GameState.set_stat("health", 100)
	GameState.set_stat("max_mana", 40)
	GameState.set_stat("mana", 40)
	GameState.set_stat("max_stamina", 40)
	GameState.set_stat("stamina", 40)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)
	GameState.set_stat("max_focus", 40)
	GameState.set_stat("focus", 40)
	GameState.set_flag("hollow_spire_spell_trial_complete", false)


func _wait_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("WIND_WELL_HOLLOW_SPIRE_SMOKE_TEST: " + label)


func _restore_state() -> void:
	GameState.stats = original_stats.duplicate(true)
	for stat_value: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_value)
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_value]))
	GameState.set_flag(
		"hollow_spire_spell_trial_complete",
		original_completion_flag
	)


func _finish() -> void:
	Engine.time_scale = 1.0
	_restore_state()
	if failures.is_empty():
		print("WIND_WELL_HOLLOW_SPIRE_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("WIND_WELL_HOLLOW_SPIRE_SMOKE_TEST: " + failure)
	get_tree().quit(1)
