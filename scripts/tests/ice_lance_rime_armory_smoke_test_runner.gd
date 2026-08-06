extends "res://scripts/tests/ice_lance_rime_armory_smoke_test.gd"

# The base file keeps the individual test cases readable. This runner owns the
# coroutine order so reset cleanup finishes before the trial is freed and the
# process exits.


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	original_completion_flag = GameState.get_flag(
		"rime_armory_spell_trial_complete"
	)
	_prepare_stats()

	var trial: PrototypeRimeArmorySpellTrial = (
		TrialScene.instantiate() as PrototypeRimeArmorySpellTrial
	)
	_expect(trial != null, "Rime Armory spell trial instantiates")
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
	trial.set_process(false)

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

	_test_ability_contract()
	await _test_caster_integration(trial, player, caster)
	await _test_three_target_pierce(trial, player)
	await _test_lodged_temporary_geometry(trial, player)
	await _test_mastery_and_reset(trial, player)

	trial.queue_free()
	await get_tree().process_frame
	_finish()
