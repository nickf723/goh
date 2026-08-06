extends Node

const TrialScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_asteroid_belt_spell_trial_v1.tscn"
)
const AsteroidBeltScene: PackedScene = preload(
	"res://scenes/actions/asteroid_belt.tscn"
)
const AsteroidBeltAbility: AbilityDefinition = preload(
	"res://data/abilities/asteroid_belt_ability.tres"
)
const AsteroidBeltPayload: DamagePayload = preload(
	"res://data/damage_payloads/asteroid_belt_payload.tres"
)
const CombatTargetScene: PackedScene = preload(
	"res://scenes/actors/testing/combat_training_target.tscn"
)
const PerformanceMonitorScript: Script = preload(
	"res://scripts/performance/runtime_performance_monitor.gd"
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
		"orbital_gallery_spell_trial_complete"
	)
	_prepare_stats()

	var trial: PrototypeAsteroidBeltSpellTrial = (
		TrialScene.instantiate() as PrototypeAsteroidBeltSpellTrial
	)
	_expect(trial != null, "Orbital Gallery spell trial instantiates")
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
	if player == null or caster == null:
		trial.queue_free()
		await get_tree().process_frame
		_finish()
		return

	_test_ability_contract()
	await _test_caster_and_recast_budget(trial, player, caster)
	await _test_exact_orbit_geometry(trial, player)
	await _test_contact_payload_and_force(trial, player)
	await _test_lifetime_and_monitor_ring(player)
	await _test_trial_progression_and_reset(trial, player)

	trial.queue_free()
	await get_tree().process_frame
	_finish()


func _test_ability_contract() -> void:
	_expect(AsteroidBeltAbility != null, "Asteroid Belt ability resource loads")
	_expect(AsteroidBeltAbility.mana_cost == 4, "Asteroid Belt costs four Mana")
	_expect(
		AsteroidBeltAbility.get_delivery_type() == "orbiting_satellites",
		"Asteroid Belt identifies its orbiting-satellite delivery"
	)
	_expect(
		AsteroidBeltAbility.get_targeting_style() == "self",
		"Asteroid Belt is a self-centered positional spell"
	)
	_expect(
		AsteroidBeltPayload.amount == 2,
		"Asteroid contacts deal deliberate health damage"
	)
	_expect(
		AsteroidBeltPayload.stance_damage == 3,
		"Asteroid contacts emphasize stance pressure"
	)
	_expect(
		AsteroidBeltPayload.tags.has("force"),
		"Asteroid contacts participate in the shared force grammar"
	)
	var icon_entry: Dictionary = SpellIcons.entry_from_ability(
		AsteroidBeltAbility
	)
	_expect(
		str(icon_entry.get("icon_path", "")).ends_with(
			"asteroid_belt.svg"
		),
		"Focus and quick slots resolve the authored Asteroid Belt symbol"
	)


func _test_caster_and_recast_budget(
	trial: PrototypeAsteroidBeltSpellTrial,
	player: CharacterBody3D,
	caster: Node
) -> void:
	trial.reset_trial()
	await _wait_frames(3)
	GameState.set_stat("mana", 20)
	_select_ability(caster, AsteroidBeltAbility)
	var mana_before: int = GameState.get_stat("mana")
	_expect(
		bool(caster.call("cast_from_player", player, 0.18, false)),
		"shared AbilityCaster creates Asteroid Belt"
	)
	await _wait_frames(3)
	var first_belt: AsteroidBelt = _find_latest_belt()
	_expect(first_belt != null, "casting spawns an AsteroidBelt action")
	if first_belt == null:
		return
	_expect(first_belt.belt_active, "spawned Asteroid Belt is active")
	_expect(first_belt.source_actor == player, "Asteroid Belt follows its caster")
	_expect(
		GameState.get_stat("mana") == mana_before - 4,
		"Asteroid Belt spends Mana exactly once"
	)
	_expect(
		first_belt.asteroid_visual is MultiMeshInstance3D,
		"all visible asteroids share one MultiMesh draw owner"
	)
	_expect(
		first_belt.asteroid_multimesh.instance_count == first_belt.asteroid_count,
		"MultiMesh contains exactly the authored asteroid count"
	)
	_expect(
		first_belt.get_node_or_null("Asteroid0") == null,
		"Asteroid Belt does not create one processing node per rock"
	)

	await _wait_frames(14)
	_expect(
		bool(caster.call("cast_from_player", player, 0.18, false)),
		"Asteroid Belt can be recast after the ordinary cast lock"
	)
	await _wait_frames(3)
	var active_belts: Array[Node] = get_tree().get_nodes_in_group(
		"asteroid_belt_effects"
	)
	var active_count: int = 0
	for node: Node in active_belts:
		if node is AsteroidBelt and (node as AsteroidBelt).belt_active:
			active_count += 1
	_expect(
		active_count == 1,
		"recasting replaces Grace's previous belt instead of stacking effects"
	)


func _test_exact_orbit_geometry(
	trial: PrototypeAsteroidBeltSpellTrial,
	player: CharacterBody3D
) -> void:
	_cleanup_belts()
	await get_tree().process_frame
	trial.reset_trial()
	await _wait_frames(2)
	player.global_position = Vector3(0.0, 1.0, 4.0)
	player.velocity = Vector3.ZERO

	var belt: AsteroidBelt = AsteroidBeltScene.instantiate() as AsteroidBelt
	trial.add_child(belt)
	belt.set_payload(AsteroidBeltPayload)
	belt.set_source_actor(player)
	belt.begin_belt()
	belt.set_process(false)

	var orbit_center: Vector3 = _target_center(trial.orbit_target)
	var inner_center: Vector3 = _target_center(trial.inner_witness)
	var outer_center: Vector3 = _target_center(trial.outer_witness)
	_expect(
		belt.find_contacting_asteroid(orbit_center) >= 0,
		"the target at 2.75 meters intersects the initial asteroid orbit"
	)
	_expect(
		belt.find_contacting_asteroid(inner_center) < 0,
		"the inner witness remains inside the belt's safe hollow"
	)
	_expect(
		belt.find_contacting_asteroid(outer_center) < 0,
		"the outer witness remains beyond the belt"
	)
	belt.finish_belt("geometry_test_complete")
	await get_tree().process_frame


func _test_contact_payload_and_force(
	trial: PrototypeAsteroidBeltSpellTrial,
	player: CharacterBody3D
) -> void:
	var target: CombatTrainingTarget = (
		CombatTargetScene.instantiate() as CombatTrainingTarget
	)
	target.name = "AsteroidContactTarget"
	target.target_label = "ASTEROID CONTACT TARGET"
	target.position = Vector3(2.75, 0.05, 40.0)
	trial.add_child(target)
	await get_tree().process_frame
	target.set_physics_process(false)
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	var force_receiver: ForceReceiver = target.get_node_or_null(
		"ForceReceiver"
	) as ForceReceiver
	if hit_receiver != null:
		hit_receiver.set("hit_mode", 2)
		hit_receiver.set("max_health", 12)
		hit_receiver.set("current_health", 12)
		hit_receiver.set("max_stance", 0)
		hit_receiver.set("current_stance", 0)
	if force_receiver != null:
		force_receiver.reset_forces()

	player.global_position = Vector3(0.0, 1.0, 40.0)
	var belt: AsteroidBelt = AsteroidBeltScene.instantiate() as AsteroidBelt
	trial.add_child(belt)
	belt.set_payload(AsteroidBeltPayload)
	belt.set_source_actor(player)
	belt.begin_belt()
	belt.set_process(false)
	var health_before: int = int(hit_receiver.get("current_health"))
	var first: Dictionary = belt.apply_contact_to_target(target, 0, true)
	_expect(bool(first.get("contact_applied", false)), "an orbiting asteroid delivers its contact payload")
	_expect(
		int(hit_receiver.get("current_health")) == health_before - 2,
		"one asteroid contact deals the authored two damage"
	)
	_expect(
		force_receiver != null and force_receiver.external_velocity.x > 0.1,
		"the asteroid pushes the target outward from Grace"
	)

	belt.apply_contact_to_target(target, 1, true)
	belt.apply_contact_to_target(target, 2, true)
	var fourth: Dictionary = belt.apply_contact_to_target(target, 3, true)
	_expect(
		not bool(fourth.get("contact_applied", false))
		and str(fourth.get("reason", "")) == "target_hit_limit",
		"one belt caps repeated contacts against the same target"
	)
	_expect(
		belt.total_contacts == 3,
		"contact accounting remains bounded and deterministic"
	)
	belt.finish_belt("contact_test_complete")
	target.queue_free()
	await get_tree().process_frame


func _test_lifetime_and_monitor_ring(player: CharacterBody3D) -> void:
	var belt: AsteroidBelt = AsteroidBeltScene.instantiate() as AsteroidBelt
	belt.duration_seconds = 0.2
	add_child(belt)
	belt.set_source_actor(player)
	belt.set_payload(AsteroidBeltPayload)
	belt.begin_belt()
	belt.set_process(false)
	belt._process(0.25)
	_expect(
		not belt.belt_active,
		"Asteroid Belt releases its processing node when duration ends"
	)
	await get_tree().process_frame

	var monitor := PerformanceMonitorScript.new() as RuntimePerformanceMonitor
	monitor.name = "AsteroidPerformanceMonitorFixture"
	monitor.maximum_history_samples = 8
	monitor.show_on_start = false
	add_child(monitor)
	monitor.set_process(false)
	await get_tree().process_frame
	for _index: int in range(20):
		monitor.record_frame_sample(0.016)
	_expect(
		monitor.frame_history_ms.size() == 8,
		"performance history remains at its fixed capacity"
	)
	_expect(
		monitor.frame_history_overwrite_count == 12,
		"full performance history overwrites one slot instead of shifting the Array"
	)
	var snapshot: Dictionary = monitor.sample_performance()
	_expect(
		int(snapshot.get("history_samples", 0)) == 8,
		"performance snapshot exposes the bounded history"
	)
	monitor.queue_free()
	await get_tree().process_frame


func _test_trial_progression_and_reset(
	trial: PrototypeAsteroidBeltSpellTrial,
	player: CharacterBody3D
) -> void:
	_cleanup_belts()
	trial.reset_trial()
	await _wait_frames(2)
	player.global_position = Vector3(0.0, 1.0, 4.0)

	var first_belt: AsteroidBelt = AsteroidBeltScene.instantiate() as AsteroidBelt
	trial.add_child(first_belt)
	first_belt.set_payload(AsteroidBeltPayload)
	first_belt.set_source_actor(player)
	first_belt.begin_belt()
	first_belt.set_process(false)
	for asteroid_index: int in range(3):
		first_belt.apply_contact_to_target(
			trial.orbit_target,
			asteroid_index,
			true
		)
	_expect(trial.spacing_gate.active, "defeating the exact-orbit target opens the first gate")
	_expect(
		trial.stage
		== PrototypeAsteroidBeltSpellTrial.TrialStage.ORBITAL_DRIFT,
		"exact spacing advances to the moving-target lesson"
	)
	_expect(
		trial.get_target_health(trial.inner_witness) == 30
		and trial.get_target_health(trial.outer_witness) == 30,
		"inner and outer witnesses remain unharmed"
	)

	player.global_position = Vector3(0.0, 1.0, 18.0)
	var second_belt: AsteroidBelt = AsteroidBeltScene.instantiate() as AsteroidBelt
	trial.add_child(second_belt)
	second_belt.set_payload(AsteroidBeltPayload)
	second_belt.set_source_actor(player)
	second_belt.begin_belt()
	second_belt.set_process(false)
	second_belt.apply_contact_to_target(trial.moving_target, 0, true)
	second_belt.apply_contact_to_target(trial.moving_target, 1, true)
	_expect(trial.mastery_gate.active, "catching the Drifting Moon opens the mastery route")
	_expect(
		trial.stage
		== PrototypeAsteroidBeltSpellTrial.TrialStage.MASTERY,
		"moving-orbit lesson advances to mastery"
	)
	trial.call("_on_mastery_goal_body_entered", player)
	_expect(trial.trial_complete, "mastery seal completes the Orbital Gallery")
	_expect(
		GameState.get_flag(trial.completion_flag),
		"Orbital Gallery records its mastery flag"
	)

	var active_belt: AsteroidBelt = second_belt
	trial.reset_trial()
	await get_tree().process_frame
	_expect(
		trial.stage
		== PrototypeAsteroidBeltSpellTrial.TrialStage.EXACT_ORBIT,
		"reset restores the exact-orbit lesson"
	)
	_expect(not trial.spacing_gate.active, "reset closes the first gate")
	_expect(not trial.mastery_gate.active, "reset closes the mastery gate")
	_expect(
		not GameState.get_flag(trial.completion_flag),
		"reset clears Asteroid Belt mastery"
	)
	_expect(
		active_belt == null
		or not is_instance_valid(active_belt)
		or not active_belt.belt_active,
		"reset removes active orbit processing"
	)


func _select_ability(caster: Node, ability: AbilityDefinition) -> void:
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
	var index: int = loadout.equipped_abilities.find(ability)
	if index >= 0:
		caster.call("select_ability", index, false)


func _find_latest_belt() -> AsteroidBelt:
	var nodes: Array[Node] = get_tree().get_nodes_in_group(
		"asteroid_belt_effects"
	)
	for index: int in range(nodes.size() - 1, -1, -1):
		if nodes[index] is AsteroidBelt:
			return nodes[index] as AsteroidBelt
	return null


func _cleanup_belts() -> void:
	for node: Node in get_tree().get_nodes_in_group("asteroid_belt_effects"):
		if node != null and is_instance_valid(node):
			if node.has_method("finish_belt"):
				node.call("finish_belt", "test_cleanup")
			else:
				node.queue_free()


func _target_center(target: Node) -> Vector3:
	if target == null:
		return Vector3.ZERO
	var collision: CollisionShape3D = target.get_node_or_null(
		"CollisionShape3D"
	) as CollisionShape3D
	if collision != null:
		return collision.global_position
	return (target as Node3D).global_position if target is Node3D else Vector3.ZERO


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
	GameState.set_flag("orbital_gallery_spell_trial_complete", false)


func _wait_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("ASTEROID_BELT_ORBITAL_GALLERY_SMOKE_TEST: " + label)


func _restore_state() -> void:
	GameState.stats = original_stats.duplicate(true)
	for stat_value: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_value)
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_value]))
	GameState.set_flag(
		"orbital_gallery_spell_trial_complete",
		original_completion_flag
	)


func _finish() -> void:
	Engine.time_scale = 1.0
	_restore_state()
	if failures.is_empty():
		print("ASTEROID_BELT_ORBITAL_GALLERY_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("ASTEROID_BELT_ORBITAL_GALLERY_SMOKE_TEST: " + failure)
	get_tree().quit(1)
