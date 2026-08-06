extends Node

const TrialScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_storm_observatory_spell_trial_v1.tscn"
)
const StrikeScene: PackedScene = preload(
	"res://scenes/actions/lightning_bolt_strike.tscn"
)
const BoltPayload: DamagePayload = preload(
	"res://data/damage_payloads/lightning_bolt_payload.tres"
)
const GroundSpells = preload(
	"res://scripts/abilities/ground_spell_registry.gd"
)
const SpellIcons = preload(
	"res://scripts/ui/spell_icon_factory.gd"
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
	GameState.quick_spell_loadouts.clear()
	GameState.quick_spell_selected_slots.clear()
	_prepare_stats()

	var trial: PrototypeStormObservatorySpellTrial = (
		TrialScene.instantiate() as PrototypeStormObservatorySpellTrial
	)
	_expect(trial != null, "Storm Observatory spell trial instantiates")
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
	trial.set_physics_process(false)

	var player: CharacterBody3D = trial.player
	var caster: Node = (
		player.get_node_or_null("AbilityCaster")
		if player != null
		else null
	)
	var router: Node = (
		player.get_node_or_null("PlayerControlRouter")
		if player != null
		else null
	)
	var belt: Node = (
		player.get_node_or_null("QuickSpellBeltPresentation")
		if player != null
		else null
	)
	_expect(player != null, "trial contains Grace")
	_expect(caster != null, "Grace retains the shared AbilityCaster")
	_expect(router != null, "Grace retains the quick-spell router")
	_expect(belt != null, "Grace installs the permanent quick-spell belt")
	if player == null or caster == null or router == null or belt == null:
		trial.queue_free()
		await get_tree().process_frame
		_finish()
		return

	var ability: AbilityDefinition = _find_ability(caster, "lightning_bolt")
	_expect(ability != null, "Lightning Bolt is present in Grace's spell library")
	if ability == null:
		trial.queue_free()
		await get_tree().process_frame
		_finish()
		return

	_test_ability_contract(ability)
	_test_quick_belt_symbol_parity(caster, router, belt, ability)
	await _test_ground_target_cast(trial, player, caster, ability)
	await _test_direct_center_and_peripheral_ring(trial, player)
	await _test_delayed_moving_target_prediction(trial, player)
	_test_trial_progression_and_reset(trial, player)

	trial.queue_free()
	await get_tree().process_frame
	_finish()


func _test_ability_contract(ability: AbilityDefinition) -> void:
	_expect(ability.mana_cost == 4, "Lightning Bolt costs four Mana")
	_expect(
		ability.get_delivery_type() == "sky_strike",
		"Lightning Bolt identifies its sky-strike delivery"
	)
	_expect(BoltPayload.amount == 5, "direct Lightning Bolt impact has high health damage")
	_expect(BoltPayload.stance_damage == 4, "direct Lightning Bolt impact has strong stance damage")
	var definition: Dictionary = GroundSpells.get_definition_for_ability(ability)
	_expect(not definition.is_empty(), "Lightning Bolt is registered for ground targeting")
	_expect(
		GroundSpells.get_target_radius(definition, 0.0) > 1.0,
		"Lightning Bolt exposes an outer AoE targeting ring"
	)
	_expect(
		str(definition.get("post_spawn_method", "")) == "begin_strike",
		"confirming the ground mark begins the delayed sky strike"
	)


func _test_quick_belt_symbol_parity(
	caster: Node,
	router: Node,
	belt: Node,
	ability: AbilityDefinition
) -> void:
	_select_ability(caster, ability)
	if caster.has_method("align_focus_menu_to_current_ability"):
		caster.call("align_focus_menu_to_current_ability")
	_expect(
		bool(router.call("assign_selected_focus_spell_to_slot", 0)),
		"Focus selection can assign Lightning Bolt to quick slot one"
	)
	belt.call("_process", 0.2)
	var debug_data: Dictionary = belt.call("get_debug_data") as Dictionary
	_expect(
		int(debug_data.get("slot_icon_badge_count", 0)) == 10,
		"quick belt renders one real icon badge for every spell slot"
	)
	_expect(
		bool(debug_data.get("focus_symbol_parity", false)),
		"quick belt reports Focus symbol parity"
	)
	var glyphs_value: Variant = debug_data.get("slot_icon_glyphs", [])
	var glyphs: Array = glyphs_value as Array if glyphs_value is Array else []
	var expected_glyph: String = SpellIcons.get_glyph(
		SpellIcons.entry_from_ability(ability, 0, true)
	)
	_expect(
		glyphs.size() == 10 and str(glyphs[0]) == expected_glyph,
		"assigned quick slot uses the exact same Lightning Bolt symbol as Focus"
	)


func _test_ground_target_cast(
	trial: PrototypeStormObservatorySpellTrial,
	player: CharacterBody3D,
	caster: Node,
	ability: AbilityDefinition
) -> void:
	trial.reset_trial()
	trial.set_physics_process(false)
	GameState.set_stat("mana", 20)
	_select_ability(caster, ability)
	player.global_position = Vector3(0.0, 1.0, 2.0)
	player.rotation = Vector3(0.0, PI, 0.0)
	_aim_player_straight_ahead(player)
	await get_tree().physics_frame

	var mana_before: int = GameState.get_stat("mana")
	var targeting_started: bool = bool(
		caster.call("cast_from_player", player, 0.18, false)
	)
	_expect(targeting_started, "first Cast enters Lightning Bolt ground targeting")
	_expect(
		bool(caster.call("is_ground_targeting")),
		"Lightning Bolt owns the AoE ground marker before confirmation"
	)
	_expect(
		GameState.get_stat("mana") == mana_before,
		"placing the marker does not spend Mana before confirmation"
	)
	var controller: RefCounted = caster.call(
		"get_ground_targeting_controller"
	) as RefCounted
	var marker_position: Vector3 = controller.call("get_target_position") as Vector3
	var flat_offset: Vector3 = marker_position - trial.still_target.global_position
	flat_offset.y = 0.0
	_expect(
		flat_offset.length() <= 0.35,
		"the initial storm mark resolves onto the still rod"
	)

	var health_before: int = _get_health(trial.still_target)
	_expect(
		bool(caster.call("cast_from_player", player, 0.18, false)),
		"second Cast confirms Lightning Bolt"
	)
	_expect(
		GameState.get_stat("mana") == mana_before - ability.mana_cost,
		"confirmed Lightning Bolt spends its Mana exactly once"
	)
	await _wait_frames(3)
	var strike: LightningBoltStrike = _find_latest_strike()
	_expect(strike != null, "confirmation spawns the Lightning Bolt strike scene")
	if strike == null:
		return
	strike.set_process(false)
	strike.advance_strike(maxf(strike.warning_seconds - 0.06, 0.01))
	_expect(
		_get_health(trial.still_target) == health_before,
		"the warning interval deals no early damage"
	)
	_expect(not strike.struck, "the bolt remains pending during its warning flash")
	strike.advance_strike(0.1)
	_expect(strike.struck, "the bolt lands after the authored delay")
	_expect(
		_get_health(trial.still_target) == 0,
		"the direct center bolt defeats the five-health storm rod"
	)
	_expect(trial.still_gate.active, "direct impact opens the first trial gate")
	strike.finish_strike()
	await get_tree().process_frame


func _test_direct_center_and_peripheral_ring(
	trial: PrototypeStormObservatorySpellTrial,
	player: CharacterBody3D
) -> void:
	trial.reset_trial()
	trial.set_physics_process(false)
	var center_health: int = _get_health(trial.precision_target)
	var left_health: int = _get_health(trial.left_bystander)
	var right_health: int = _get_health(trial.right_bystander)
	var strike: LightningBoltStrike = _spawn_test_strike(
		player,
		trial.precision_target.global_position
	)
	await get_tree().physics_frame
	strike.advance_strike(strike.warning_seconds + 0.02)
	_expect(
		_get_health(trial.precision_target) == center_health - BoltPayload.amount,
		"bright center target receives the direct Lightning Bolt payload"
	)
	_expect(
		_get_health(trial.left_bystander) == left_health
		and _get_health(trial.right_bystander) == right_health,
		"targets inside the outer ring but outside the bolt remain unharmed in v1"
	)
	var debug_data: Dictionary = strike.get_debug_data()
	_expect(
		int(debug_data.get("peripheral_effect_count", -1)) == 0,
		"peripheral AoE effect remains explicitly deferred"
	)
	_expect(
		bool(debug_data.get("peripheral_upgrade_reserved", false)),
		"outer ring remains reserved for a future Lightning Bolt upgrade"
	)
	strike.finish_strike()
	await get_tree().process_frame


func _test_delayed_moving_target_prediction(
	trial: PrototypeStormObservatorySpellTrial,
	player: CharacterBody3D
) -> void:
	trial.reset_trial()
	trial.set_physics_process(false)
	var relay: CombatTrainingTarget = trial.moving_target
	var start_health: int = _get_health(relay)
	var original_position: Vector3 = relay.global_position
	var missed_strike: LightningBoltStrike = _spawn_test_strike(
		player,
		original_position
	)
	await get_tree().physics_frame
	missed_strike.advance_strike(missed_strike.warning_seconds * 0.5)
	relay.global_position = original_position + Vector3(3.0, 0.0, 0.0)
	missed_strike.advance_strike(missed_strike.warning_seconds * 0.6)
	_expect(
		_get_health(relay) == start_health,
		"a relay that leaves the center before impact avoids the delayed bolt"
	)
	missed_strike.finish_strike()
	await get_tree().process_frame

	relay.reset_target()
	relay.set_physics_process(false)
	relay.global_position = original_position
	var predicted_position: Vector3 = original_position + Vector3(2.4, 0.0, 0.0)
	var led_strike: LightningBoltStrike = _spawn_test_strike(
		player,
		predicted_position
	)
	await get_tree().physics_frame
	led_strike.advance_strike(led_strike.warning_seconds * 0.5)
	relay.global_position = predicted_position
	led_strike.advance_strike(led_strike.warning_seconds * 0.6)
	_expect(
		_get_health(relay) == 0,
		"leading the relay lets it enter the center before the bolt lands"
	)
	led_strike.finish_strike()
	await get_tree().process_frame


func _test_trial_progression_and_reset(
	trial: PrototypeStormObservatorySpellTrial,
	player: CharacterBody3D
) -> void:
	trial.reset_trial()
	trial.call("_on_still_target_depleted")
	_expect(trial.still_gate.active, "still-rod completion opens the first gate")
	_expect(
		trial.stage == PrototypeStormObservatorySpellTrial.TrialStage.MOVING_RELAY,
		"still rod advances to moving relay"
	)
	trial.call("_on_moving_target_depleted")
	_expect(trial.moving_gate.active, "moving-relay completion opens the second gate")
	_expect(
		trial.stage == PrototypeStormObservatorySpellTrial.TrialStage.PRECISION_RING,
		"moving relay advances to precision ring"
	)
	trial.call("_on_precision_target_depleted")
	_expect(trial.precision_gate.active, "precision completion opens the final gate")
	_expect(
		trial.stage == PrototypeStormObservatorySpellTrial.TrialStage.MASTERY,
		"precision ring advances to mastery"
	)
	trial.call("_on_mastery_area_body_entered", player)
	_expect(trial.trial_complete, "mastery seal completes the trial")
	_expect(
		GameState.get_flag(trial.completion_flag),
		"Storm Observatory records its mastery flag"
	)
	trial.reset_trial()
	_expect(
		trial.stage == PrototypeStormObservatorySpellTrial.TrialStage.STILL_ROD,
		"reset restores the still-rod stage"
	)
	_expect(
		not trial.still_gate.active
		and not trial.moving_gate.active
		and not trial.precision_gate.active,
		"reset closes every Storm Observatory gate"
	)
	_expect(
		not GameState.get_flag(trial.completion_flag),
		"reset clears the Lightning Bolt mastery flag"
	)
	_expect(
		_get_health(trial.left_bystander) == 12
		and _get_health(trial.right_bystander) == 12,
		"reset restores both peripheral sensors"
	)


func _spawn_test_strike(
	player: CharacterBody3D,
	position_value: Vector3
) -> LightningBoltStrike:
	var strike: LightningBoltStrike = (
		StrikeScene.instantiate() as LightningBoltStrike
	)
	add_child(strike)
	strike.set_payload(BoltPayload)
	strike.set_source_actor(player)
	strike.global_position = position_value
	strike.begin_strike()
	strike.set_process(false)
	return strike


func _find_latest_strike() -> LightningBoltStrike:
	for node: Node in get_tree().get_nodes_in_group("lightning_bolt_strikes"):
		if node is LightningBoltStrike:
			return node as LightningBoltStrike
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


func _get_health(target: CombatTrainingTarget) -> int:
	if target == null:
		return -1
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	return int(hit_receiver.get("current_health")) if hit_receiver != null else -1


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


func _wait_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("LIGHTNING_BOLT_STORM_OBSERVATORY_SMOKE_TEST: " + label)


func _restore_state() -> void:
	GameState.stats = original_stats.duplicate(true)
	for stat_value: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_value)
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_value]))
	GameState.quick_spell_loadouts = original_quick_spell_loadouts.duplicate(true)
	GameState.quick_spell_selected_slots = (
		original_quick_spell_selected_slots.duplicate(true)
	)


func _finish() -> void:
	Engine.time_scale = 1.0
	_restore_state()
	if failures.is_empty():
		print("LIGHTNING_BOLT_STORM_OBSERVATORY_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("LIGHTNING_BOLT_STORM_OBSERVATORY_SMOKE_TEST: " + failure)
	get_tree().quit(1)
