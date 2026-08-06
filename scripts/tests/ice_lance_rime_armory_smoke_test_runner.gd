extends "res://scripts/tests/ice_lance_rime_armory_smoke_test.gd"

const RunnerTrialScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_rime_armory_spell_trial_v1.tscn"
)
const RunnerUpgradeLabScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_upgrade_lab_v1.tscn"
)
const RunnerIceLanceScene: PackedScene = preload(
	"res://scenes/actions/ice_lance_projectile.tscn"
)
const RunnerIceLancePayload: DamagePayload = preload(
	"res://data/damage_payloads/ice_lance_payload.tres"
)
const RunnerCombatTargetScene: PackedScene = preload(
	"res://scenes/actors/testing/combat_training_target.tscn"
)

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
		RunnerTrialScene.instantiate() as PrototypeRimeArmorySpellTrial
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
	await _test_frozen_shatter(player)
	await _test_caster_integration(trial, player, caster)
	await _test_three_target_pierce(trial, player)
	await _test_lodged_temporary_geometry(trial, player)
	await _test_mastery_and_reset(trial, player)

	trial.queue_free()
	await get_tree().process_frame
	_finish()


func _test_ability_contract() -> void:
	super()

	var upgraded_payload: DamagePayload = (
		RunnerIceLancePayload.duplicate(true) as DamagePayload
	)
	var upgraded_tags: Array[String] = []
	for tag: String in upgraded_payload.tags:
		upgraded_tags.append(tag)
	for upgrade_tag: String in [
		"piercing",
		"upgrade",
		"ice_lance",
		"piercing_ice_lance",
	]:
		if not upgraded_tags.has(upgrade_tag):
			upgraded_tags.append(upgrade_tag)
	upgraded_payload.tags = upgraded_tags
	upgraded_payload.source_name = "Piercing Ice Lance"

	var upgraded_lance: IceLanceProjectile = (
		RunnerIceLanceScene.instantiate() as IceLanceProjectile
	)
	add_child(upgraded_lance)
	upgraded_lance.set_process(false)
	upgraded_lance.set_payload(upgraded_payload)
	_expect(
		upgraded_lance.hit_limit >= 4,
		"Piercing Ice Lance upgrade extends the rebuilt spear to a fourth target"
	)
	_expect(
		upgraded_lance.speed >= 24.0,
		"the existing upgrade still reinforces Ice Lance travel speed"
	)
	upgraded_lance.queue_free()

	var upgrade_lab: Node = RunnerUpgradeLabScene.instantiate()
	_expect(upgrade_lab != null, "upgrade compatibility lab still instantiates")
	if upgrade_lab != null:
		_expect(
			upgrade_lab.get_node_or_null(
				"TrainingTargets/IcePierceTargetD"
			) != null,
			"upgrade lab provides a fourth mark beyond the base three-target limit"
		)
		upgrade_lab.free()


func _test_frozen_shatter(player: Node3D) -> void:
	var target: CombatTrainingTarget = (
		RunnerCombatTargetScene.instantiate() as CombatTrainingTarget
	)
	target.name = "FrozenIceLanceTarget"
	target.position = Vector3(24.0, 1.0, 24.0)
	add_child(target)
	await get_tree().process_frame
	target.set_physics_process(false)

	var status_receiver: Node = target.get_node_or_null("StatusReceiver")
	var payload_receiver: PayloadReceiver = target.get_node_or_null(
		"PayloadReceiver"
	) as PayloadReceiver
	var force_receiver: ForceReceiver = target.get_node_or_null(
		"ForceReceiver"
	) as ForceReceiver
	_expect(status_receiver != null, "frozen-target test exposes StatusReceiver")
	_expect(payload_receiver != null, "frozen-target test exposes PayloadReceiver")
	_expect(force_receiver != null, "frozen-target test exposes ForceReceiver")
	if (
		status_receiver == null
		or payload_receiver == null
		or force_receiver == null
	):
		target.queue_free()
		await get_tree().process_frame
		return

	force_receiver.reset_forces()
	status_receiver.call(
		"apply_status",
		"frozen",
		5.0,
		1.0,
		"Ice Lance regression"
	)
	_expect(
		bool(status_receiver.call("has_status", "frozen")),
		"test target begins Frozen"
	)

	var lance: IceLanceProjectile = (
		RunnerIceLanceScene.instantiate() as IceLanceProjectile
	)
	add_child(lance)
	lance.set_process(false)
	lance.set_payload(RunnerIceLancePayload)
	lance.set_source_actor(player)
	lance.direction = Vector3.BACK
	lance.pierce_target(target, target.global_position)

	_expect(
		not bool(status_receiver.call("has_status", "frozen")),
		"Ice Lance force consumes Frozen through the shared Shatter reaction"
	)
	_expect(
		payload_receiver.last_reaction_summary.to_lower().contains("shatter"),
		"Ice Lance records Shatter rather than a bespoke spell-only exception"
	)
	_expect(
		force_receiver.external_velocity.z > 0.1
		and absf(force_receiver.external_velocity.x) < 0.05,
		"Ice Lance drives the target along the spear's authored travel direction"
	)

	lance.queue_free()
	target.queue_free()
	await get_tree().process_frame
