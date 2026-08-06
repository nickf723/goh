extends Node

const TrialScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_rime_armory_spell_trial_v1.tscn"
)
const IceLanceScene: PackedScene = preload(
	"res://scenes/actions/ice_lance_projectile.tscn"
)
const IceLanceAbility: AbilityDefinition = preload(
	"res://data/abilities/ice_lance_ability.tres"
)
const IceLancePayload: DamagePayload = preload(
	"res://data/damage_payloads/ice_lance_payload.tres"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}
var original_completion_flag: bool = false


func _ready() -> void:
	call_deferred("run_tests")


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
	_test_mastery_and_reset(trial, player)

	trial.queue_free()
	await get_tree().process_frame
	_finish()


func _test_ability_contract() -> void:
	_expect(IceLanceAbility != null, "Ice Lance ability resource loads")
	if IceLanceAbility == null:
		return
	_expect(IceLanceAbility.mana_cost == 2, "Ice Lance costs two Mana")
	_expect(
		IceLanceAbility.get_delivery_type() == "physical_lance",
		"Ice Lance identifies its dedicated physical-lance delivery"
	)
	_expect(
		IceLanceAbility.ability_scene == IceLanceScene,
		"Ice Lance uses the dedicated action scene instead of GenericProjectile"
	)
	_expect(IceLancePayload.amount == 3, "Ice Lance begins with strong point damage")
	_expect(
		IceLancePayload.stance_damage == 5,
		"Ice Lance begins with heavy stance pressure"
	)
	_expect(
		IceLancePayload.tags.has("force")
		and IceLancePayload.tags.has("line_pierce")
		and IceLancePayload.tags.has("temporary_geometry" ) == false,
		"Ice Lance payload carries force and line-pierce identity without pretending the target is terrain"
	)

	var lance: IceLanceProjectile = (
		IceLanceScene.instantiate() as IceLanceProjectile
	)
	add_child(lance)
	lance.set_process(false)
	lance.set_payload(IceLancePayload)
	var first_payload: DamagePayload = lance._make_pierce_payload(0)
	var second_payload: DamagePayload = lance._make_pierce_payload(1)
	var third_payload: DamagePayload = lance._make_pierce_payload(2)
	_expect(first_payload.amount >= second_payload.amount, "successive bodies do not increase Ice Lance damage")
	_expect(second_payload.amount >= third_payload.amount, "Ice Lance keeps losing energy along the line")
	_expect(third_payload.amount > 0, "the third pierced target still receives a real lance hit")
	lance.queue_free()


func _test_caster_integration(
	trial: PrototypeRimeArmorySpellTrial,
	player: CharacterBody3D,
	caster: Node
) -> void:
	trial.reset_trial()
	await _wait_frames(3)
	_select_ice_lance(caster)
	GameState.set_stat("mana", 20)
	var mana_before: int = GameState.get_stat("mana")
	var cast_result: bool = bool(
		caster.call("cast_from_player", player, 0.18, false)
	)
	_expect(cast_result, "shared AbilityCaster launches the rebuilt Ice Lance")
	_expect(
		GameState.get_stat("mana") == mana_before - 2,
		"casting the rebuilt Ice Lance spends two Mana once"
	)
	await _wait_frames(2)
	var active_lance: IceLanceProjectile = _find_latest_lance()
	_expect(
		active_lance != null,
		"casting creates the dedicated IceLanceProjectile runtime"
	)
	if active_lance != null:
		active_lance.shatter_lance("caster_integration_test")
	await get_tree().process_frame


func _test_three_target_pierce(
	trial: PrototypeRimeArmorySpellTrial,
	player: CharacterBody3D
) -> void:
	trial.reset_trial()
	await _wait_frames(3)
	for target: CombatTrainingTarget in trial.line_targets:
		target.set_physics_process(false)
	var lance: IceLanceProjectile = _spawn_test_lance(
		trial,
		player,
		Vector3(0.0, 0.9, 1.7),
		Vector3.BACK
	)
	lance.set_process(false)
	await get_tree().physics_frame
	lance.advance_lance(0.62)

	_expect(lance.hit_count == 3, "one Ice Lance pierces all three aligned marks")
	_expect(
		lance.pierced_target_names.size() == 3,
		"the lance records each unique body once"
	)
	var all_depleted: bool = true
	for target: CombatTrainingTarget in trial.line_targets:
		var hit_receiver: Node = target.get_node_or_null("HitReceiver")
		if hit_receiver == null or int(hit_receiver.get("current_health")) > 0:
			all_depleted = false
	_expect(all_depleted, "decaying pierce damage still clears the complete authored line")
	_expect(trial.line_gate.active, "three pierced targets open the Long Point gate")
	_expect(
		trial.stage == PrototypeRimeArmorySpellTrial.TrialStage.LODGED_EDGE,
		"line completion advances to the lodging lesson"
	)
	if is_instance_valid(lance):
		lance.shatter_lance("line_test_complete")
	await get_tree().process_frame


func _test_lodged_temporary_geometry(
	trial: PrototypeRimeArmorySpellTrial,
	player: CharacterBody3D
) -> void:
	# Preserve the completed first gate, then fire directly into the authored
	# anchor surface in the second room.
	trial.stage = PrototypeRimeArmorySpellTrial.TrialStage.LODGED_EDGE
	trial.line_gate.set_gate_open(true, true, {"reason": "test_setup"})
	var lance: IceLanceProjectile = _spawn_test_lance(
		trial,
		player,
		Vector3(0.0, 2.2, 17.0),
		Vector3.BACK
	)
	lance.set_process(false)
	await get_tree().physics_frame
	lance.advance_lance(0.35)

	_expect(lance.lodged, "Ice Lance embeds instead of disappearing on hard architecture")
	_expect(
		lance.lodged_surface_name == trial.anchor_plate.name,
		"the embedded lance records its actual Rime Anchor surface"
	)
	_expect(
		lance.lodged_collision_shape != null
		and not lance.lodged_collision_shape.disabled,
		"a lodged Ice Lance becomes temporary solid collision geometry"
	)
	_expect(
		lance.is_in_group("ice_lance_lodged"),
		"lodged lances expose a reusable world-state group"
	)
	trial._scan_for_anchor_lance()
	_expect(trial.mastery_gate.active, "lodging in the marked anchor opens the mastery gate")
	_expect(
		trial.stage == PrototypeRimeArmorySpellTrial.TrialStage.MASTERY,
		"anchor lodging advances to mastery"
	)
	var before_expiry: float = lance.lodged_remaining
	lance.advance_lance(0.25)
	_expect(
		lance.lodged_remaining < before_expiry,
		"lodged terrain has a finite authored lifetime"
	)


func _test_mastery_and_reset(
	trial: PrototypeRimeArmorySpellTrial,
	player: CharacterBody3D
) -> void:
	trial._on_mastery_goal_body_entered(player)
	_expect(trial.trial_complete, "mastery seal completes the Rime Armory")
	_expect(
		GameState.get_flag(trial.completion_flag),
		"Rime Armory records its Ice Lance mastery flag"
	)
	trial.reset_trial()
	await get_tree().process_frame
	_expect(
		trial.stage == PrototypeRimeArmorySpellTrial.TrialStage.LONG_POINT,
		"reset restores the first Ice Lance lesson"
	)
	_expect(
		not trial.line_gate.active and not trial.mastery_gate.active,
		"reset closes both Rime Armory gates"
	)
	_expect(
		not GameState.get_flag(trial.completion_flag),
		"reset clears the Ice Lance mastery flag"
	)
	_expect(
		get_tree().get_nodes_in_group("ice_lance_lodged").is_empty(),
		"reset removes temporary lodged-lance terrain"
	)


func _spawn_test_lance(
	parent: Node,
	player: Node3D,
	position_value: Vector3,
	cast_direction: Vector3
) -> IceLanceProjectile:
	var lance: IceLanceProjectile = (
		IceLanceScene.instantiate() as IceLanceProjectile
	)
	parent.add_child(lance)
	lance.global_position = position_value
	lance.set_payload(IceLancePayload)
	lance.set_source_actor(player)
	lance.launch(cast_direction)
	return lance


func _find_latest_lance() -> IceLanceProjectile:
	var nodes: Array[Node] = get_tree().get_nodes_in_group(
		"ice_lance_projectiles"
	)
	for index: int in range(nodes.size() - 1, -1, -1):
		if nodes[index] is IceLanceProjectile:
			return nodes[index] as IceLanceProjectile
	return null


func _select_ice_lance(caster: Node) -> void:
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
	for index: int in range(loadout.equipped_abilities.size()):
		var ability: AbilityDefinition = loadout.equipped_abilities[index]
		if ability != null and ability.get_spell_id() == "ice_lance":
			caster.call("select_ability", index, false)
			return


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
	GameState.set_flag("rime_armory_spell_trial_complete", false)


func _wait_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("ICE_LANCE_RIME_ARMORY_SMOKE_TEST: " + label)


func _restore_state() -> void:
	GameState.stats = original_stats.duplicate(true)
	for stat_value: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_value)
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_value]))
	GameState.set_flag(
		"rime_armory_spell_trial_complete",
		original_completion_flag
	)


func _finish() -> void:
	Engine.time_scale = 1.0
	_restore_state()
	if failures.is_empty():
		print("ICE_LANCE_RIME_ARMORY_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("ICE_LANCE_RIME_ARMORY_SMOKE_TEST: " + failure)
	get_tree().quit(1)
