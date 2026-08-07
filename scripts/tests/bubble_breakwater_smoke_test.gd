extends Node

const TrialScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_bubble_breakwater_spell_trial_v1.tscn"
)
const BubbleAbility: AbilityDefinition = preload(
	"res://data/abilities/bubble_ability.tres"
)
const BubblePayload: DamagePayload = preload(
	"res://data/damage_payloads/bubble_burst_payload.tres"
)
const CombatTargetScene: PackedScene = preload(
	"res://scenes/actors/testing/combat_training_target.tscn"
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
		"bubble_breakwater_spell_trial_complete"
	)
	_prepare_stats()

	var trial: PrototypeBubbleBreakwaterSpellTrial = (
		TrialScene.instantiate() as PrototypeBubbleBreakwaterSpellTrial
	)
	_expect(trial != null, "Bubble Breakwater spell trial instantiates")
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
	var controller: PlayerBubbleShieldController = (
		player.get_node_or_null("BubbleShieldController")
		as PlayerBubbleShieldController
		if player != null
		else null
	)
	var defense: Node = (
		player.get_node_or_null("PlayerDefenseController")
		if player != null
		else null
	)
	var caster: Node = (
		player.get_node_or_null("AbilityCaster")
		if player != null
		else null
	)
	_expect(player != null, "trial contains Grace")
	_expect(controller != null, "Grace owns the reusable Bubble shield controller")
	_expect(defense != null, "Grace retains the shared defense controller")
	_expect(caster != null, "Grace retains the shared AbilityCaster")
	if player == null or controller == null or defense == null or caster == null:
		trial.queue_free()
		await get_tree().process_frame
		_finish()
		return

	_test_ability_contract()
	await _test_cast_and_recast(player, caster, controller)
	await _test_hit_negation_and_burst(trial, player, defense, controller)
	await _test_status_tick_and_expiration(player, controller)
	await _test_trial_progression_and_reset(trial, player, controller)

	trial.queue_free()
	await get_tree().process_frame
	_finish()


func _test_ability_contract() -> void:
	_expect(BubbleAbility != null, "Bubble ability resource loads")
	_expect(BubbleAbility.mana_cost == 3, "Bubble costs three Mana")
	_expect(
		BubbleAbility.get_targeting_style() == "self",
		"Bubble is a self-targeted ward"
	)
	_expect(
		BubbleAbility.get_delivery_type() == "one_hit_shield",
		"Bubble identifies its one-hit shield delivery"
	)
	_expect(BubblePayload.amount == 0, "Bubble Burst deals no health damage")
	_expect(BubblePayload.stance_damage == 0, "Bubble Burst deals no stance damage")
	_expect(
		BubblePayload.knockback_strength > 0.0,
		"Bubble Burst carries outward force"
	)
	var icon_entry: Dictionary = SpellIcons.entry_from_ability(BubbleAbility)
	_expect(
		str(icon_entry.get("icon_path", "")).ends_with("bubble.svg"),
		"Focus and quick slots resolve Bubble's authored icon"
	)


func _test_cast_and_recast(
	player: CharacterBody3D,
	caster: Node,
	controller: PlayerBubbleShieldController
) -> void:
	controller.reset_target()
	GameState.set_stat("mana", 20)
	_select_ability(caster, BubbleAbility)
	var mana_before: int = GameState.get_stat("mana")
	_expect(
		bool(caster.call("cast_from_player", player, 0.18, false)),
		"shared AbilityCaster creates Bubble"
	)
	await _wait_frames(3)
	_expect(controller.is_bubble_active(), "casting activates the personal ward")
	_expect(
		GameState.get_stat("mana") == mana_before - 3,
		"Bubble spends Mana once on cast"
	)
	_expect(controller.is_processing(), "active Bubble wakes its one controller")
	_expect(
		controller.is_in_group("persistent_spell_effects"),
		"active Bubble is visible to the F7 persistent-effect count"
	)
	var first_activation: int = controller.activation_count
	var remaining_before: float = controller.active_remaining
	await _wait_frames(14)
	_expect(
		bool(caster.call("cast_from_player", player, 0.18, false)),
		"Bubble can be recast after the ordinary cast lock"
	)
	await _wait_frames(3)
	_expect(
		controller.activation_count == first_activation + 1,
		"recasting refreshes the same shield controller"
	)
	_expect(
		controller.active_remaining >= remaining_before,
		"recasting refreshes Bubble's duration"
	)
	_expect(
		player.get_children().filter(
			func(child: Node) -> bool:
				return child.name == "BubbleShieldController"
		).size() == 1,
		"recasting does not stack duplicate shield nodes"
	)


func _test_hit_negation_and_burst(
	trial: PrototypeBubbleBreakwaterSpellTrial,
	player: CharacterBody3D,
	defense: Node,
	controller: PlayerBubbleShieldController
) -> void:
	var target: CombatTrainingTarget = (
		CombatTargetScene.instantiate() as CombatTrainingTarget
	)
	target.name = "BubbleBurstTarget"
	target.target_label = "BUBBLE BURST TARGET"
	target.global_position = player.global_position + Vector3(2.4, 0.0, 0.0)
	trial.add_child(target)
	await get_tree().process_frame
	target.set_physics_process(false)
	var target_hit_receiver: Node = target.get_node_or_null("HitReceiver")
	var force_receiver: ForceReceiver = target.get_node_or_null(
		"ForceReceiver"
	) as ForceReceiver
	if target_hit_receiver != null:
		target_hit_receiver.set("hit_mode", 2)
		target_hit_receiver.set("max_health", 30)
		target_hit_receiver.set("current_health", 30)
		target_hit_receiver.set("max_stance", 0)
		target_hit_receiver.set("current_stance", 0)
	if force_receiver != null:
		force_receiver.reset_forces()

	controller.activate_bubble(BubblePayload)
	var health_before: int = GameState.get_stat("health")
	var stance_before: int = GameState.get_stat("stance")
	var target_health_before: int = int(
		target_hit_receiver.get("current_health")
	) if target_hit_receiver != null else -1
	var attack := DamagePayload.new()
	attack.amount = 9
	attack.stance_damage = 8
	attack.element = "death"
	attack.source_name = "Regression Hammer"
	attack.hit_type = "melee"
	attack.tags = ["enemy", "melee", "heavy"]
	var attacker := Node3D.new()
	attacker.name = "BubbleRegressionAttacker"
	attacker.global_position = player.global_position + Vector3(-2.0, 0.0, 0.0)
	trial.add_child(attacker)

	var result: Dictionary = defense.call(
		"resolve_incoming_attack",
		attack,
		attacker
	) as Dictionary
	_expect(
		str(result.get("outcome", "")) == "bubble_absorbed",
		"the first incoming hit is claimed by Bubble"
	)
	_expect(
		GameState.get_stat("health") == health_before,
		"Bubble negates all health damage from the absorbed hit"
	)
	_expect(
		GameState.get_stat("stance") == stance_before,
		"Bubble negates all stance damage from the absorbed hit"
	)
	_expect(
		not controller.is_bubble_active(),
		"one absorbed hit consumes the shield"
	)
	_expect(
		int(result.get("burst_targets", 0)) >= 1,
		"consuming Bubble performs one outward burst query"
	)
	_expect(
		force_receiver != null and force_receiver.external_velocity.x > 0.1,
		"Bubble Burst pushes a nearby target away from Grace"
	)
	_expect(
		target_hit_receiver == null
		or int(target_hit_receiver.get("current_health")) == target_health_before,
		"Bubble Burst knockback does not damage the nearby target"
	)

	controller._process(0.5)
	_expect(
		not controller.is_processing(),
		"Bubble releases processing after its short burst visual"
	)
	_expect(
		not controller.is_in_group("persistent_spell_effects"),
		"consumed Bubble leaves the persistent-effect count"
	)

	var second_health_before: int = GameState.get_stat("health")
	var second_result: Dictionary = defense.call(
		"resolve_incoming_attack",
		attack,
		attacker
	) as Dictionary
	_expect(
		str(second_result.get("outcome", "")) == "hit",
		"a second hit reaches ordinary defense after Bubble is gone"
	)
	_expect(
		GameState.get_stat("health") < second_health_before,
		"the post-Bubble hit deals normal health damage"
	)

	GameState.set_stat("health", GameState.get_stat("max_health"))
	GameState.set_stat("stance", GameState.get_stat("max_stance"))
	if defense.has_method("reset_defense"):
		defense.call("reset_defense")
	attacker.queue_free()
	target.queue_free()
	await get_tree().process_frame


func _test_status_tick_and_expiration(
	player: CharacterBody3D,
	controller: PlayerBubbleShieldController
) -> void:
	var status_receiver: Node = player.get_node_or_null("StatusReceiver")
	_expect(status_receiver != null, "Grace exposes her status receiver")
	if status_receiver != null and status_receiver.has_method("deliver_status_tick"):
		controller.activate_bubble(BubblePayload)
		var health_before: int = GameState.get_stat("health")
		var tick := DamagePayload.new()
		tick.amount = 3
		tick.stance_damage = 0
		tick.element = "poison"
		tick.source_name = "Poison Tick"
		tick.hit_type = "status"
		tick.tags = ["poison", "status"]
		status_receiver.call("deliver_status_tick", tick)
		_expect(
			GameState.get_stat("health") == health_before,
			"Bubble can spend itself to negate one damaging status tick"
		)
		_expect(
			not controller.is_bubble_active(),
			"absorbing a status tick still consumes exactly one Bubble"
		)
		controller._process(0.5)

	controller.activate_bubble(BubblePayload, 0.1)
	controller._process(0.15)
	_expect(
		controller.state == PlayerBubbleShieldController.ShieldState.BURSTING,
		"an unused Bubble enters a harmless fade when its duration expires"
	)
	controller._process(0.5)
	_expect(
		controller.state == PlayerBubbleShieldController.ShieldState.INACTIVE,
		"expired Bubble returns to its sleeping state"
	)
	_expect(not controller.is_processing(), "inactive Bubble performs no per-frame work")


func _test_trial_progression_and_reset(
	trial: PrototypeBubbleBreakwaterSpellTrial,
	player: CharacterBody3D,
	controller: PlayerBubbleShieldController
) -> void:
	trial.reset_trial()
	await _wait_frames(2)
	trial.set_process(false)
	player.global_position = PrototypeBubbleBreakwaterSpellTrial.FIRST_CENTER + Vector3.UP
	controller.activate_bubble(BubblePayload)
	trial.call("_fire_pressure_hit", trial.first_impact_source)
	_expect(trial.impact_gate.active, "absorbing the first pressure pulse opens the impact gate")
	_expect(
		trial.stage == PrototypeBubbleBreakwaterSpellTrial.TrialStage.REBOUND,
		"one clean hit advances to the rebound lesson"
	)

	player.global_position = PrototypeBubbleBreakwaterSpellTrial.SECOND_CENTER + Vector3.UP
	controller.activate_bubble(BubblePayload)
	trial.call("_fire_pressure_hit", trial.second_impact_source)
	trial.rebound_target.global_position = (
		PrototypeBubbleBreakwaterSpellTrial.SECOND_CENTER
		+ Vector3(trial.rebound_required_distance + 0.2, 0.05, 0.0)
	)
	trial.call("_check_rebound_completion")
	_expect(trial.rebound_gate.active, "pushing the target beyond the ring opens the mastery gate")
	_expect(
		trial.stage == PrototypeBubbleBreakwaterSpellTrial.TrialStage.MASTERY,
		"the rebound lesson advances to mastery"
	)
	trial.call("_on_mastery_goal_body_entered", player)
	_expect(trial.trial_complete, "mastery seal completes the Bubble Breakwater")
	_expect(
		GameState.get_flag(trial.completion_flag),
		"Bubble Breakwater records its mastery flag"
	)

	trial.reset_trial()
	await get_tree().process_frame
	_expect(
		trial.stage == PrototypeBubbleBreakwaterSpellTrial.TrialStage.ONE_HIT,
		"reset returns to the one-hit lesson"
	)
	_expect(not trial.impact_gate.active, "reset closes the impact gate")
	_expect(not trial.rebound_gate.active, "reset closes the rebound gate")
	_expect(not controller.is_bubble_active(), "reset removes the active ward")
	_expect(
		not GameState.get_flag(trial.completion_flag),
		"reset clears Bubble mastery"
	)


func _select_ability(caster: Node, ability: AbilityDefinition) -> void:
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
	var index: int = loadout.equipped_abilities.find(ability)
	if index >= 0:
		caster.call("select_ability", index, false)


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
	GameState.set_flag("bubble_breakwater_spell_trial_complete", false)


func _wait_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("BUBBLE_BREAKWATER_SMOKE_TEST: " + label)


func _restore_state() -> void:
	GameState.stats = original_stats.duplicate(true)
	for stat_value: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_value)
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_value]))
	GameState.set_flag(
		"bubble_breakwater_spell_trial_complete",
		original_completion_flag
	)


func _finish() -> void:
	Engine.time_scale = 1.0
	_restore_state()
	if failures.is_empty():
		print("BUBBLE_BREAKWATER_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("BUBBLE_BREAKWATER_SMOKE_TEST: " + failure)
	get_tree().quit(1)
