extends Node

const TrialScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_cold_forge_spell_trial_v1.tscn"
)
const FireboltPayload: DamagePayload = preload(
	"res://data/damage_payloads/firebolt_payload.tres"
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
	GameState.set_stat("max_mana", 30)
	GameState.set_stat("mana", 30)

	var trial: PrototypeColdForgeSpellTrial = (
		TrialScene.instantiate() as PrototypeColdForgeSpellTrial
	)
	_expect(trial != null, "Cold Forge spell trial instantiates")
	if trial == null:
		_finish()
		return
	add_child(trial)
	await _wait_frames(6)

	var regenerator: LabResourceRegenerator = trial.get_node_or_null(
		"LabResourceRegenerator"
	) as LabResourceRegenerator
	if regenerator != null:
		regenerator.set_process(false)

	var player: CharacterBody3D = trial.get_node_or_null(
		"Player"
	) as CharacterBody3D
	var caster: Node = player.get_node_or_null("AbilityCaster") if player != null else null
	var controller: PlayerFlamethrowerController = (
		player.get_node_or_null("FlamethrowerController") as PlayerFlamethrowerController
		if player != null
		else null
	)
	var action_state: PlayerActionState = (
		player.get_node_or_null("PlayerActionState") as PlayerActionState
		if player != null
		else null
	)
	_expect(player != null, "trial contains Grace")
	_expect(caster != null, "Grace retains the shared AbilityCaster")
	_expect(controller != null, "Grace installs the Flamethrower channel controller")
	_expect(action_state != null, "Grace retains the shared action-state authority")
	if player == null or caster == null or controller == null or action_state == null:
		trial.queue_free()
		await get_tree().process_frame
		_finish()
		return

	var ability: AbilityDefinition = _find_flamethrower_ability(caster)
	_expect(ability != null, "Flamethrower is present in Grace's equipped spell library")
	if ability == null:
		trial.queue_free()
		await get_tree().process_frame
		_finish()
		return
	_expect(ability.mana_cost == 0, "Flamethrower has no fixed upfront Mana cost")
	_expect(
		ability.get_delivery_type() == "channel",
		"Flamethrower identifies itself as a channel delivery"
	)
	_expect(
		controller.get_effective_mana_rate() > 0.0,
		"Flamethrower owns a positive continuous Mana drain"
	)

	controller.set_process(false)
	trial.fading_thermal.set_process(false)
	trial.fading_requirement.set_process(false)
	trial.boiler_thermal.set_process(false)

	_test_firebolt_cools_before_unlock(trial)
	_test_sustained_channel_unlocks(trial, player, caster, controller, action_state, ability)
	_test_boiler_value_drives_lift(trial)
	_test_fractional_mana_debt_prevents_free_taps(
		trial,
		player,
		caster,
		controller,
		action_state,
		ability
	)

	trial.queue_free()
	await get_tree().process_frame
	_finish()


func _test_firebolt_cools_before_unlock(
	trial: PrototypeColdForgeSpellTrial
) -> void:
	trial.reset_trial()
	trial.fading_thermal.set_process(false)
	trial.fading_requirement.set_process(false)
	var receiver: PayloadReceiver = trial.fading_target.get_node_or_null(
		"PayloadReceiver"
	) as PayloadReceiver
	_expect(receiver != null, "frozen seal accepts shared payload delivery")
	if receiver == null:
		return
	var payload: DamagePayload = FireboltPayload.duplicate(true) as DamagePayload
	receiver.receive_payload(payload)
	var peak_temperature: float = trial.fading_thermal.temperature_c
	for _index: int in range(20):
		trial.fading_thermal._process(0.1)
		trial.fading_requirement._process(0.1)
	_expect(
		peak_temperature > trial.fading_thermal.temperature_c,
		"the frozen seal cools after a Firebolt impulse"
	)
	_expect(
		not trial.fading_requirement.completed,
		"one Firebolt cannot satisfy the sustained heat lock"
	)
	_expect(
		trial.fading_thermal.temperature_c < trial.fading_required_temperature_c,
		"Firebolt heat falls below the lock threshold"
	)


func _test_sustained_channel_unlocks(
	trial: PrototypeColdForgeSpellTrial,
	player: CharacterBody3D,
	caster: Node,
	controller: PlayerFlamethrowerController,
	action_state: PlayerActionState,
	ability: AbilityDefinition
) -> void:
	trial.reset_trial()
	trial.fading_thermal.set_process(false)
	trial.fading_requirement.set_process(false)
	trial.boiler_thermal.set_process(false)
	GameState.set_stat("max_mana", 30)
	GameState.set_stat("mana", 30)
	_select_ability(caster, ability)
	player.global_position = Vector3(0.0, 1.0, 1.2)
	player.rotation = Vector3(0.0, PI, 0.0)
	_aim_player_straight_ahead(player)
	var mana_before: int = GameState.get_stat("mana")
	_expect(
		controller.begin_ability_channel(player, ability),
		"holding Cast can begin the Flamethrower channel"
	)
	_expect(
		action_state.is_cast_channel_active(),
		"the action state remains casting for the persistent channel"
	)

	for _index: int in range(90):
		controller.advance_channel(0.1, true)
		trial.fading_thermal._process(0.1)
		trial.fading_requirement._process(0.1)
		if trial.fading_requirement.completed:
			break
	controller.cancel_ability_channel("test_release")

	_expect(
		trial.fading_thermal.temperature_c >= trial.fading_required_temperature_c,
		"continuous flame overcomes the seal's active cooling"
	)
	_expect(
		trial.fading_requirement.completed,
		"sustained heat completes the authored hold requirement"
	)
	_expect(trial.fading_gate.active, "the sustained heat signal opens the inner gate")
	_expect(
		trial.stage == PrototypeColdForgeSpellTrial.TrialStage.BOILER_LIFT,
		"unlocking the seal advances the trial to the boiler lift"
	)
	_expect(
		GameState.get_stat("mana") < mana_before,
		"Mana drains while the stream remains active"
	)
	_expect(
		not action_state.is_cast_channel_active(),
		"releasing Flamethrower clears the persistent cast lock"
	)


func _test_boiler_value_drives_lift(
	trial: PrototypeColdForgeSpellTrial
) -> void:
	trial.boiler_thermal.set_process(false)
	trial.boiler_thermal.set_temperature(
		trial.boiler_full_height_temperature_c,
		"Regression Heat"
	)
	_expect(
		trial.boiler_elevator.current_fraction >= 0.99,
		"boiler temperature drives the proportional lift to full height"
	)
	trial.call("_on_completion_area_body_entered", trial.player)
	_expect(trial.trial_complete, "reaching the upper landing completes the trial")
	_expect(
		GameState.get_flag(trial.completion_flag),
		"Cold Forge completion records its mastery flag"
	)
	trial.boiler_thermal.set_temperature(
		trial.boiler_minimum_temperature_c,
		"Regression Cooling"
	)
	_expect(
		trial.boiler_elevator.current_fraction <= 0.01,
		"cooling the boiler returns the lift to the floor"
	)


func _test_fractional_mana_debt_prevents_free_taps(
	trial: PrototypeColdForgeSpellTrial,
	player: CharacterBody3D,
	caster: Node,
	controller: PlayerFlamethrowerController,
	_action_state: PlayerActionState,
	ability: AbilityDefinition
) -> void:
	trial.reset_trial()
	trial.fading_thermal.set_process(false)
	trial.fading_requirement.set_process(false)
	trial.boiler_thermal.set_process(false)
	controller.mana_fractional_cost = 0.0
	GameState.set_stat("max_mana", 20)
	GameState.set_stat("mana", 20)
	_select_ability(caster, ability)
	player.global_position = Vector3(0.0, 1.0, 1.2)
	player.rotation = Vector3(0.0, PI, 0.0)
	_aim_player_straight_ahead(player)
	for _index: int in range(4):
		controller.begin_ability_channel(player, ability)
		controller.advance_channel(0.1, true)
		controller.cancel_ability_channel("micro_tap")
	_expect(
		GameState.get_stat("mana") == 19,
		"four short taps still pay their accumulated continuous Mana cost"
	)
	_expect(
		controller.mana_fractional_cost > 0.0,
		"sub-Mana channel debt survives between short bursts"
	)


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


func _find_flamethrower_ability(caster: Node) -> AbilityDefinition:
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return null
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
	for ability: AbilityDefinition in loadout.equipped_abilities:
		if ability != null and ability.get_spell_id() == "flamethrower":
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


func _wait_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("FLAMETHROWER_COLD_FORGE_SMOKE_TEST: " + label)


func _finish() -> void:
	GameState.set_stat("max_mana", original_max_mana)
	GameState.set_stat("mana", mini(original_mana, original_max_mana))
	if failures.is_empty():
		print("FLAMETHROWER_COLD_FORGE_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("FLAMETHROWER_COLD_FORGE_SMOKE_TEST: " + failure)
	get_tree().quit(1)
