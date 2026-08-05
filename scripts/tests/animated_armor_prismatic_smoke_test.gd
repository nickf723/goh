extends Node

const BossScene: PackedScene = preload(
	"res://scenes/actors/enemies/animated_armor_boss.tscn"
)
const GateScene: PackedScene = preload(
	"res://scenes/actors/interactables/readable_magic_gate.tscn"
)
const FinaleScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_church_trial_boss_finale_v1.tscn"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	GameState.reset_run()
	await _test_prismatic_boss_contract()
	await _test_signature_attack_geometry_and_payloads()
	await _test_boss_finale_mana_regeneration()
	_finish()


func _test_prismatic_boss_contract() -> void:
	var fixture := Node3D.new()
	fixture.name = "PrismaticBossFixture"
	add_child(fixture)

	var gate: Node3D = GateScene.instantiate() as Node3D
	gate.name = "BossExitGate"
	fixture.add_child(gate)

	var player: CharacterBody3D = _create_test_player()
	fixture.add_child(player)

	var boss: AnimatedArmorBoss = BossScene.instantiate() as AnimatedArmorBoss
	_expect(boss != null, "Animated Armor boss scene instantiates")
	if boss == null:
		fixture.queue_free()
		await get_tree().process_frame
		return
	boss.name = "AnimatedArmorBoss"
	boss.position = Vector3.ZERO
	fixture.add_child(boss)
	boss.set_physics_process(false)
	await _wait_frames(3)

	var receiver: Node = boss.get_node_or_null("HitReceiver")
	var visual: Node = boss.get_node_or_null("VisualRoot")
	_expect(receiver != null, "Prismatic boss retains the shared HitReceiver")
	_expect(visual != null, "Prismatic boss retains its procedural visual actor")
	if receiver == null:
		fixture.queue_free()
		await get_tree().process_frame
		return

	_expect(
		int(receiver.get("hit_mode")) == 3,
		"Animated Armor uses stance-then-health damage"
	)
	_expect(
		boss.current_judgment == AnimatedArmorBoss.Judgment.NEUTRAL,
		"boss begins in Neutral Judgment"
	)
	_expect(
		_has_all_strings(receiver.get("weak_elements"), ["fire", "lightning"]),
		"Neutral Judgment exposes Fire and Lightning weaknesses"
	)

	var break_payload := DamagePayload.new()
	break_payload.amount = 0
	break_payload.stance_damage = int(receiver.get("max_stance"))
	break_payload.element = "neutral"
	break_payload.source_name = "Prismatic Test Break"
	break_payload.hit_type = "melee"
	_assign_tags(break_payload, ["weapon", "melee", "test"])
	receiver.call("receive_payload", break_payload)
	await get_tree().process_frame
	_expect(boss.core_exposed, "breaking stance exposes the judgment core")
	_expect(boss.state == "exposed", "boss enters a non-attacking exposed state")
	if visual != null:
		_expect(
			bool(visual.get("core_exposed")),
			"visual actor enters its exposed-core posture"
		)
	_expect(
		_array_is_empty(receiver.get("weak_elements"))
		and _array_is_empty(receiver.get("resistant_elements")),
		"exposed core temporarily clears elemental shell modifiers"
	)

	var health_before_critical: int = int(receiver.get("current_health"))
	var critical_payload := DamagePayload.new()
	critical_payload.amount = 3
	critical_payload.stance_damage = 0
	critical_payload.element = "fire"
	critical_payload.source_name = "Prismatic Test Critical"
	critical_payload.hit_type = "melee"
	_assign_tags(critical_payload, ["weapon", "melee", "test"])
	critical_payload.critical_multiplier = 2.0
	receiver.call("receive_payload", critical_payload)
	await get_tree().process_frame
	_expect(
		int(receiver.get("current_health")) < health_before_critical - 3,
		"weapon melee receives amplified damage against the exposed core"
	)
	_expect(not boss.core_exposed, "critical strike closes the exposed-core window")
	_expect(
		boss.current_judgment == AnimatedArmorBoss.Judgment.SCARLET,
		"first repaired shell becomes Scarlet Judgment"
	)
	_expect(
		_has_all_strings(receiver.get("weak_elements"), ["water", "ice"]),
		"Scarlet shell is weak to Water and Ice"
	)

	receiver.call("open_critical_window")
	await get_tree().process_frame
	receiver.call("close_critical_window", true)
	await get_tree().process_frame
	_expect(
		boss.current_judgment == AnimatedArmorBoss.Judgment.AZURE,
		"second repaired shell becomes Azure Judgment"
	)
	_expect(
		_has_all_strings(receiver.get("weak_elements"), ["lightning", "ice"]),
		"Azure shell is weak to Lightning and Ice"
	)

	receiver.call("open_critical_window")
	await get_tree().process_frame
	receiver.call("close_critical_window", true)
	await get_tree().process_frame
	_expect(
		boss.current_judgment == AnimatedArmorBoss.Judgment.INDIGO,
		"third repaired shell becomes Indigo Judgment"
	)
	_expect(
		_has_all_strings(receiver.get("weak_elements"), ["earth", "metal"]),
		"Indigo shell is weak to Earth and Metal"
	)

	boss.set_judgment_stance(
		AnimatedArmorBoss.Judgment.SCARLET,
		"test_signature_selection",
		false
	)
	boss.attack_pattern_index = 0
	_expect(
		boss.choose_next_attack(6.0) == "scarlet_fissure",
		"Scarlet Judgment selects its line fissure at range"
	)
	boss.set_judgment_stance(
		AnimatedArmorBoss.Judgment.AZURE,
		"test_signature_selection",
		false
	)
	boss.attack_pattern_index = 0
	_expect(
		boss.choose_next_attack(6.0) == "azure_wave",
		"Azure Judgment selects its sweeping wave at range"
	)
	boss.set_judgment_stance(
		AnimatedArmorBoss.Judgment.INDIGO,
		"test_signature_selection",
		false
	)
	boss.attack_pattern_index = 0
	_expect(
		boss.choose_next_attack(8.0) == "indigo_mark",
		"Indigo Judgment selects its delayed position mark"
	)

	boss.call("_on_health_changed", 10, int(receiver.get("max_health")))
	_expect(boss.final_phase_active, "low health activates the accelerated final phase")
	_expect(
		boss.get_effective_attack_cooldown() < boss.attack_cooldown,
		"final phase shortens the attack cooldown"
	)
	_expect(
		boss.get_effective_move_speed() > boss.move_speed * boss.indigo_move_multiplier,
		"final phase accelerates judgment movement"
	)

	boss.call("_on_health_depleted")
	await get_tree().process_frame
	_expect(bool(gate.get("is_unlocked")), "boss defeat still unlocks the Judgment Gate")
	await get_tree().create_timer(
		boss.defeat_presentation_duration + 0.1
	).timeout

	fixture.queue_free()
	await get_tree().process_frame


func _test_signature_attack_geometry_and_payloads() -> void:
	var fixture := Node3D.new()
	fixture.name = "PrismaticAttackFixture"
	add_child(fixture)

	var player: CharacterBody3D = _create_test_player()
	fixture.add_child(player)
	var defense: PlayerDefenseController = player.get_node_or_null(
		"PlayerDefenseController"
	) as PlayerDefenseController

	var boss: AnimatedArmorBoss = BossScene.instantiate() as AnimatedArmorBoss
	boss.name = "AttackGeometryBoss"
	boss.position = Vector3.ZERO
	boss.rotation = Vector3.ZERO
	fixture.add_child(boss)
	boss.set_physics_process(false)
	await _wait_frames(3)

	GameState.set_stat("max_health", 30)
	GameState.set_stat("health", 30)
	GameState.set_stat("max_stance", 20)
	GameState.set_stat("stance", 20)

	player.global_position = Vector3(0.0, 0.0, -5.0)
	_expect(
		boss.is_position_inside_scarlet_fissure(player.global_position),
		"Scarlet fissure contains the telegraphed forward lane"
	)
	player.global_position = Vector3(2.2, 0.0, -5.0)
	_expect(
		not boss.is_position_inside_scarlet_fissure(player.global_position),
		"Scarlet fissure can be escaped laterally"
	)

	player.global_position = Vector3(0.0, 0.0, -5.0)
	var health_before: int = GameState.get_stat("health")
	boss.perform_scarlet_fissure()
	_expect(
		GameState.get_stat("health") < health_before,
		"Scarlet fissure delivers a Fire payload through player defense"
	)
	GameState.set_stat("health", 30)
	GameState.set_stat("stance", 20)

	_expect(
		boss.is_position_inside_azure_wave(Vector3(0.0, 0.0, -5.0)),
		"Azure wave covers its broad forward sweep"
	)
	_expect(
		not boss.is_position_inside_azure_wave(Vector3(0.0, 0.0, 5.0)),
		"Azure wave leaves a readable opening behind the armor"
	)
	if defense != null:
		defense.reset_defense()
	player.global_position = Vector3(0.0, 0.0, -5.0)
	boss.perform_azure_wave()
	_expect(
		defense != null and defense.is_hit_reaction_active(),
		"Azure wave applies its push through the existing hit-reaction controller"
	)
	GameState.set_stat("health", 30)
	GameState.set_stat("stance", 20)
	if defense != null:
		defense.reset_defense()

	player.global_position = Vector3(0.0, 0.0, -5.0)
	boss.lock_indigo_target()
	var locked_position: Vector3 = boss.locked_target_position
	_expect(
		boss.is_position_inside_indigo_mark(locked_position),
		"Indigo mark stores the targeted ground position"
	)
	player.global_position = Vector3(3.0, 0.0, -5.0)
	health_before = GameState.get_stat("health")
	boss.perform_indigo_mark()
	_expect(
		GameState.get_stat("health") == health_before,
		"moving away after Indigo lock avoids the delayed strike"
	)
	player.global_position = locked_position
	boss.lock_indigo_target()
	health_before = GameState.get_stat("health")
	boss.perform_indigo_mark()
	_expect(
		GameState.get_stat("health") < health_before,
		"remaining on the Indigo rune receives Lightning damage"
	)

	fixture.queue_free()
	await get_tree().process_frame


func _test_boss_finale_mana_regeneration() -> void:
	GameState.set_stat("max_mana", 20)
	GameState.set_stat("mana", 0)
	var finale: Node = FinaleScene.instantiate()
	_expect(finale != null, "dedicated Animated Armor finale scene instantiates")
	if finale == null:
		return
	finale.name = "PrismaticFinaleLabFixture"
	finale.set("apply_save_on_ready", false)
	finale.set("add_guard_test_enemy", false)
	add_child(finale)
	await _wait_frames(5)

	var finale_boss: Node = finale.get_node_or_null("AnimatedArmorBoss")
	if finale_boss != null:
		finale_boss.set_physics_process(false)
	var regenerator: LabResourceRegenerator = finale.get_node_or_null(
		"LabResourceRegenerator"
	) as LabResourceRegenerator
	_expect(
		finale.is_in_group("lab_resource_regeneration"),
		"dedicated boss finale opts into the laboratory resource policy"
	)
	_expect(regenerator != null, "boss finale installs an explicit resource regenerator")
	if regenerator != null:
		regenerator.set_process(false)
		_expect(regenerator.mana_per_second > 0.0, "boss finale enables mana regeneration")
		_expect(
			not regenerator.refill_on_ready,
			"boss finale avoids the shared all-resource entry refill"
		)
		_expect(
			is_zero_approx(regenerator.stamina_per_second)
			and is_zero_approx(regenerator.focus_per_second),
			"boss finale regeneration remains mana-only"
		)
		GameState.set_stat("mana", 0)
		regenerator._process(0.5)
		_expect(
			GameState.get_stat("mana") > 0,
			"mana recovers during an unattended boss-lab interval"
		)

	var installer: LabResourceRegeneratorInstaller = finale.get_node_or_null(
		"GameUI/LabResourceRegeneratorInstaller"
	) as LabResourceRegeneratorInstaller
	_expect(installer != null, "shared GameUI retains the laboratory installer")
	if installer != null and regenerator != null:
		var resolved: LabResourceRegenerator = installer.install_for_scene(finale)
		_expect(
			resolved == regenerator,
			"automatic installation reuses the authored mana regenerator"
		)
		_expect(
			not installer.matches_lab_identity(
				"res://scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn",
				"PrototypeBossDungeonChain",
				[]
			),
			"production Church Trial does not inherit laboratory regeneration"
		)

	finale.queue_free()
	await get_tree().process_frame


func _create_test_player() -> CharacterBody3D:
	var player := CharacterBody3D.new()
	player.name = "PlayerFixture"
	player.add_to_group("player")
	var defense := PlayerDefenseControllerElemental.new()
	defense.name = "PlayerDefenseController"
	player.add_child(defense)
	return player


func _assign_tags(payload: DamagePayload, values: Array) -> void:
	payload.tags.clear()
	for value: Variant in values:
		payload.tags.append(str(value))


func _array_is_empty(value: Variant) -> bool:
	return value is Array and (value as Array).is_empty()


func _has_all_strings(value: Variant, expected: Array) -> bool:
	if not value is Array:
		return false
	var values: Array = value as Array
	for expected_value: Variant in expected:
		if not values.has(str(expected_value)):
			return false
	return true


func _wait_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("ANIMATED_ARMOR_PRISMATIC_SMOKE_TEST: " + label)


func _finish() -> void:
	if failures.is_empty():
		print("ANIMATED_ARMOR_PRISMATIC_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("ANIMATED_ARMOR_PRISMATIC_SMOKE_TEST: " + failure)
	get_tree().quit(1)
