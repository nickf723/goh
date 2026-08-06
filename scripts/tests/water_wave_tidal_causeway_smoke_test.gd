extends Node

const TrialScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_tidal_causeway_spell_trial_v1.tscn"
)
const WaveScene: PackedScene = preload(
	"res://scenes/actions/water_wave.tscn"
)
const WavePayload: DamagePayload = preload(
	"res://data/damage_payloads/water_wave_payload.tres"
)

var failures: Array[String] = []
var original_max_mana: int = 0
var original_mana: int = 0


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_max_mana = GameState.get_stat("max_mana")
	original_mana = GameState.get_stat("mana")
	GameState.reset_run()
	GameState.set_stat("max_mana", 20)
	GameState.set_stat("mana", 20)

	var trial: PrototypeTidalCausewaySpellTrial = (
		TrialScene.instantiate() as PrototypeTidalCausewaySpellTrial
	)
	_expect(trial != null, "Tidal Causeway spell trial instantiates")
	if trial == null:
		_finish()
		return
	add_child(trial)
	await _wait_frames(7)

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
	if player == null or caster == null:
		trial.queue_free()
		await get_tree().process_frame
		_finish()
		return

	var wave_ability: AbilityDefinition = _find_wave_ability(caster)
	_expect(wave_ability != null, "Wave is present in Grace's spell library")
	if wave_ability == null:
		trial.queue_free()
		await get_tree().process_frame
		_finish()
		return

	_expect(wave_ability.mana_cost == 2, "Wave uses a fixed two-Mana cast cost")
	_expect(
		wave_ability.get_delivery_type() == "expanding_wave",
		"Wave identifies its expanding-wave delivery"
	)
	_expect(WavePayload.amount == 0, "Wave payload deals zero health damage")
	_expect(
		WavePayload.stance_damage == 0,
		"Wave payload deals zero stance damage"
	)
	_expect(
		WavePayload.status_effect == "wet",
		"Wave remains a Water setup spell through Wet"
	)

	_disable_trial_actor_processes(trial)
	await _test_mana_cost_and_cast_creation(trial, player, caster, wave_ability)
	await _test_object_mass_response(trial, player)
	await _test_mob_push(trial, player)
	await _test_enemy_push_without_damage(trial, player)
	_test_trial_progression_and_reset(trial, player)

	trial.queue_free()
	await get_tree().process_frame
	_finish()


func _disable_trial_actor_processes(
	trial: PrototypeTidalCausewaySpellTrial
) -> void:
	if trial.player != null:
		trial.player.set_physics_process(false)
	if trial.cargo_light != null:
		trial.cargo_light.set_physics_process(false)
	if trial.cargo_heavy != null:
		trial.cargo_heavy.set_physics_process(false)
	if trial.sanctuary_mob != null:
		trial.sanctuary_mob.set_physics_process(false)
	if trial.containment_enemy != null:
		var brain: Node = trial.containment_enemy.get_node_or_null(
			"EnemyBrain"
		)
		if brain != null:
			brain.set_physics_process(false)


func _test_mana_cost_and_cast_creation(
	trial: PrototypeTidalCausewaySpellTrial,
	player: CharacterBody3D,
	caster: Node,
	ability: AbilityDefinition
) -> void:
	trial.reset_trial()
	_disable_trial_actor_processes(trial)
	GameState.set_stat("mana", 10)
	_select_ability(caster, ability)
	player.global_position = Vector3(0.0, 1.0, -3.5)
	player.rotation = Vector3(0.0, PI, 0.0)
	_aim_player_straight_ahead(player)
	await get_tree().physics_frame
	var mana_before: int = GameState.get_stat("mana")
	var cast_succeeded: bool = bool(
		caster.call("cast_from_player", player)
	)
	_expect(cast_succeeded, "AbilityCaster can launch Wave")
	_expect(
		GameState.get_stat("mana") == mana_before - ability.mana_cost,
		"Wave pays its fixed Mana cost exactly once"
	)
	var spawned_wave: WaterWave = null
	for node: Node in get_tree().get_nodes_in_group("water_wave_effects"):
		if node is WaterWave:
			spawned_wave = node as WaterWave
			break
	_expect(spawned_wave != null, "casting Wave creates the shared action scene")
	if spawned_wave != null:
		spawned_wave.set_physics_process(false)
		spawned_wave.finish_wave()
	await get_tree().process_frame


func _test_object_mass_response(
	trial: PrototypeTidalCausewaySpellTrial,
	player: CharacterBody3D
) -> void:
	trial.reset_trial()
	_disable_trial_actor_processes(trial)
	player.global_position = Vector3(0.0, 1.0, -3.5)
	player.rotation = Vector3(0.0, PI, 0.0)
	trial.cargo_light.velocity = Vector3.ZERO
	trial.cargo_heavy.velocity = Vector3.ZERO
	var light_force: ForceReceiver = trial.cargo_light.get_node_or_null(
		"ForceReceiver"
	) as ForceReceiver
	var heavy_force: ForceReceiver = trial.cargo_heavy.get_node_or_null(
		"ForceReceiver"
	) as ForceReceiver
	_expect(light_force != null, "light cargo exposes ForceReceiver")
	_expect(heavy_force != null, "heavy anchor exposes ForceReceiver")
	await get_tree().physics_frame
	var wave: WaterWave = _spawn_test_wave(player, Vector3(0.0, 0.0, 1.0))
	_advance_wave_to(wave, 8.75)
	var light_speed: float = (
		light_force.external_velocity.length()
		if light_force != null
		else 0.0
	)
	var heavy_speed: float = (
		heavy_force.external_velocity.length()
		if heavy_force != null
		else 0.0
	)
	_expect(light_speed > 0.1, "Wave pushes the light cargo")
	_expect(heavy_speed > 0.1, "Wave also moves the heavy anchor")
	_expect(
		light_speed > heavy_speed,
		"the same Wave moves the light cargo faster than the heavy anchor"
	)
	_expect(
		wave.hit_target_ids.has(trial.cargo_light.get_instance_id()),
		"the moving Wave front discovers cargo through physics"
	)
	_expect(
		wave.hit_target_ids.has(trial.cargo_heavy.get_instance_id()),
		"the broad Wave front can catch multiple objects"
	)
	wave.finish_wave()
	await get_tree().process_frame


func _test_mob_push(
	trial: PrototypeTidalCausewaySpellTrial,
	player: CharacterBody3D
) -> void:
	trial.reset_trial()
	_disable_trial_actor_processes(trial)
	player.global_position = Vector3(0.0, 1.0, 16.0)
	player.rotation = Vector3(0.0, PI, 0.0)
	trial.sanctuary_mob.velocity = Vector3.ZERO
	await get_tree().physics_frame
	var wave: WaterWave = _spawn_test_wave(player, Vector3(0.0, 0.0, 1.0))
	_advance_wave_to(wave, 6.0)
	_expect(
		trial.sanctuary_mob.velocity.z > 0.1,
		"Wave pushes a living mob through CharacterBody velocity"
	)
	_expect(
		wave.hit_target_ids.has(trial.sanctuary_mob.get_instance_id()),
		"Wave records the capybara exactly as a valid mob target"
	)
	wave.finish_wave()
	await get_tree().process_frame


func _test_enemy_push_without_damage(
	trial: PrototypeTidalCausewaySpellTrial,
	player: CharacterBody3D
) -> void:
	trial.reset_trial()
	_disable_trial_actor_processes(trial)
	player.global_position = Vector3(0.0, 1.0, 32.0)
	player.rotation = Vector3(0.0, PI, 0.0)
	var hit_receiver: Node = trial.containment_enemy.get_node_or_null(
		"HitReceiver"
	)
	var force_receiver: ForceReceiver = trial.containment_enemy.get_node_or_null(
		"ForceReceiver"
	) as ForceReceiver
	var status_receiver: Node = trial.containment_enemy.get_node_or_null(
		"StatusReceiver"
	)
	var health_before: int = int(hit_receiver.get("current_health"))
	var stance_before: int = int(hit_receiver.get("current_stance"))
	await get_tree().physics_frame
	var wave: WaterWave = _spawn_test_wave(player, Vector3(0.0, 0.0, 1.0))
	_advance_wave_to(wave, 6.2)
	_expect(
		force_receiver != null and force_receiver.external_velocity.length() > 0.1,
		"Wave pushes an enemy through ForceReceiver"
	)
	_expect(
		int(hit_receiver.get("current_health")) == health_before,
		"Wave leaves enemy health unchanged"
	)
	_expect(
		int(hit_receiver.get("current_stance")) == stance_before,
		"Wave leaves enemy stance unchanged"
	)
	if (
		status_receiver != null
		and status_receiver.has_method("get_active_status_names")
	):
		var statuses: Array = status_receiver.call(
			"get_active_status_names"
		)
		_expect(statuses.has("wet"), "Wave still applies Wet setup to enemies")
	_expect(
		wave.hit_target_ids.has(trial.containment_enemy.get_instance_id()),
		"Wave records the enemy only once"
	)
	wave.finish_wave()
	await get_tree().process_frame


func _test_trial_progression_and_reset(
	trial: PrototypeTidalCausewaySpellTrial,
	player: CharacterBody3D
) -> void:
	trial.reset_trial()
	trial.call("_on_cargo_goal_body_entered", trial.cargo_heavy)
	_expect(
		trial.stage == PrototypeTidalCausewaySpellTrial.TrialStage.CARGO,
		"the heavy anchor cannot satisfy the cargo basin"
	)
	trial.call("_on_cargo_goal_body_entered", trial.cargo_light)
	_expect(trial.cargo_gate.active, "delivered cargo opens the first gate")
	_expect(
		trial.stage == PrototypeTidalCausewaySpellTrial.TrialStage.MOB,
		"cargo delivery advances to mob guidance"
	)
	trial.call("_on_mob_goal_body_entered", trial.sanctuary_mob)
	_expect(trial.mob_gate.active, "guided mob opens the second gate")
	_expect(
		trial.stage == PrototypeTidalCausewaySpellTrial.TrialStage.ENEMY,
		"mob guidance advances to enemy displacement"
	)
	var hit_receiver: Node = trial.containment_enemy.get_node_or_null(
		"HitReceiver"
	)
	var health_before: int = int(hit_receiver.get("current_health"))
	trial.call("_on_enemy_goal_body_entered", trial.containment_enemy)
	_expect(trial.enemy_gate.active, "contained enemy opens the final gate")
	_expect(
		int(hit_receiver.get("current_health")) == health_before,
		"trial progression never requires damaging the Goblin"
	)
	_expect(
		trial.stage == PrototypeTidalCausewaySpellTrial.TrialStage.MASTERY,
		"enemy displacement advances to mastery"
	)
	trial.call("_on_mastery_goal_body_entered", player)
	_expect(trial.trial_complete, "mastery basin completes the Wave trial")
	_expect(
		GameState.get_flag(trial.completion_flag),
		"Wave trial completion records its mastery flag"
	)
	trial.reset_trial()
	_expect(
		trial.stage == PrototypeTidalCausewaySpellTrial.TrialStage.CARGO,
		"reset restores the first trial stage"
	)
	_expect(
		not trial.cargo_gate.active
		and not trial.mob_gate.active
		and not trial.enemy_gate.active,
		"reset closes all three causeway gates"
	)
	_expect(
		not GameState.get_flag(trial.completion_flag),
		"reset clears the Wave mastery flag"
	)


func _spawn_test_wave(
	player: CharacterBody3D,
	direction: Vector3
) -> WaterWave:
	var wave: WaterWave = WaveScene.instantiate() as WaterWave
	add_child(wave)
	wave.set_payload(WavePayload)
	wave.set_source_actor(player)
	wave.execute(player, direction)
	wave.set_physics_process(false)
	return wave


func _advance_wave_to(wave: WaterWave, target_distance: float) -> void:
	if wave == null:
		return
	while wave.active and wave.distance_travelled < target_distance:
		wave.advance_wave(0.04)


func _find_wave_ability(caster: Node) -> AbilityDefinition:
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return null
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
	for ability: AbilityDefinition in loadout.equipped_abilities:
		if ability != null and ability.get_spell_id() == "wave":
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


func _wait_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("WATER_WAVE_TIDAL_CAUSEWAY_SMOKE_TEST: " + label)


func _finish() -> void:
	GameState.set_stat("max_mana", original_max_mana)
	GameState.set_stat("mana", mini(original_mana, original_max_mana))
	if failures.is_empty():
		print("WATER_WAVE_TIDAL_CAUSEWAY_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("WATER_WAVE_TIDAL_CAUSEWAY_SMOKE_TEST: " + failure)
	get_tree().quit(1)
