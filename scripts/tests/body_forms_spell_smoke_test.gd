extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const GrowAbility: AbilityDefinition = preload(
	"res://data/abilities/grow_ability.tres"
)
const ShrinkAbility: AbilityDefinition = preload(
	"res://data/abilities/shrink_ability.tres"
)
const GameplayEffectAccessScript = preload(
	"res://scripts/effects/gameplay_effect_access.gd"
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
	_prepare_stats()
	_test_ability_contracts()

	var floor: StaticBody3D = _make_box(
		"BodyFormsFloor",
		Vector3(0.0, -0.5, 0.0),
		Vector3(30.0, 1.0, 30.0)
	)
	add_child(floor)
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "BodyFormsTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	player.add_to_group("player")
	add_child(player)
	await _wait_frames(20)
	await get_tree().physics_frame

	var caster: Node = player.get_node_or_null("AbilityCaster")
	var weapon: SafeWeaponController = player.get_node_or_null(
		"WeaponController"
	) as SafeWeaponController
	var grow_index: int = _find_ability_index(caster, "grow")
	var shrink_index: int = _find_ability_index(caster, "shrink")
	_expect(caster != null, "body form test resolves AbilityCaster")
	_expect(weapon != null, "body form test resolves the safe weapon controller")
	_expect(grow_index >= 0, "Grace's complete library contains Grow")
	_expect(shrink_index >= 0, "Grace's complete library contains Shrink")
	if caster == null or weapon == null or grow_index < 0 or shrink_index < 0:
		_finish([player, floor])
		return

	var baseline_spell_effects: int = get_tree().get_node_count_in_group(
		"spell_effects"
	)
	var baseline_persistent: int = get_tree().get_node_count_in_group(
		"persistent_spell_effects"
	)
	var baseline_attack_speed: float = weapon.get_attack_speed()
	var attack_fixture := WeaponAttackDefinition.new()
	attack_fixture.attack_range = 2.0
	var baseline_range: float = weapon.get_effective_attack_range(
		attack_fixture
	)

	var mana_before_grow: int = GameState.get_stat("mana")
	caster.call("select_ability", grow_index, false)
	_expect(
		bool(caster.call("cast_from_player", player, 0.0, false)),
		"Grow casts through the ordinary AbilityCaster path"
	)
	await _wait_frames(5)
	var controller: PlayerBodyFormController = player.get_node_or_null(
		"BodyFormController"
	) as PlayerBodyFormController
	_expect(controller != null, "Grow installs one reusable body-form controller")
	if controller == null:
		_finish([player, floor])
		return
	var grown_debug: Dictionary = controller.get_debug_data()
	_expect(controller.is_grown(), "Grow enters the grown form")
	_expect(
		GameState.get_stat("mana") == mana_before_grow - GrowAbility.mana_cost,
		"Grow spends its authored three-Mana cost"
	)
	_expect(
		float(grown_debug.get("scale", 0.0)) > 1.5
		and float(grown_debug.get("collision_height", 0.0)) > 2.9,
		"Grow enlarges both Grace's visible scale and physical capsule"
	)
	_expect(
		is_equal_approx(
			float(player.get_meta("mechanism_mass_kg", 0.0)),
			150.0
		),
		"Grow gives pressure plates a 150 kg mechanism mass"
	)
	_expect(
		GameplayEffectAccessScript.modify_float("movement_speed", 5.0) < 4.0,
		"Grow slows ordinary movement through the shared effect channel"
	)
	_expect(
		weapon.get_attack_speed() < baseline_attack_speed,
		"Grow slows weapon cadence"
	)
	_expect(
		weapon.get_effective_attack_range(attack_fixture) > baseline_range,
		"Grow increases weapon reach"
	)
	_expect(
		get_tree().get_node_count_in_group("spell_effects")
		== baseline_spell_effects + 1
		and get_tree().get_node_count_in_group("persistent_spell_effects")
		== baseline_persistent + 1,
		"one grown form registers one persistent spell effect"
	)

	var mana_before_shrink: int = GameState.get_stat("mana")
	caster.call("select_ability", shrink_index, false)
	_expect(
		bool(caster.call("cast_from_player", player, 0.0, false)),
		"Shrink replaces Grow through the ordinary casting path"
	)
	await _wait_frames(5)
	var shrunk_debug: Dictionary = controller.get_debug_data()
	_expect(controller.is_shrunk(), "Shrink replaces the grown form")
	_expect(
		GameState.get_stat("mana") == mana_before_shrink - ShrinkAbility.mana_cost,
		"Shrink spends its authored two-Mana cost"
	)
	_expect(
		float(shrunk_debug.get("scale", 2.0)) < 0.6
		and float(shrunk_debug.get("collision_height", 2.0)) < 1.2,
		"Shrink reduces both Grace's visible scale and physical capsule"
	)
	_expect(
		is_equal_approx(
			float(player.get_meta("mechanism_mass_kg", 0.0)),
			24.0
		),
		"Shrink lowers Grace's mechanism mass to 24 kg"
	)
	_expect(
		GameplayEffectAccessScript.modify_float("movement_speed", 5.0) > 6.5,
		"Shrink increases ordinary movement speed"
	)
	_expect(
		weapon.get_attack_speed() > baseline_attack_speed,
		"Shrink increases weapon cadence"
	)
	_expect(
		weapon.get_effective_attack_range(attack_fixture) < baseline_range,
		"Shrink trades away weapon reach"
	)
	_expect(
		get_tree().get_node_count_in_group("persistent_spell_effects")
		== baseline_persistent + 1,
		"switching forms replaces the persistent effect instead of stacking it"
	)

	var mana_before_toggle: int = GameState.get_stat("mana")
	caster.call("select_ability", shrink_index, false)
	caster.call("cast_from_player", player, 0.0, false)
	await _wait_frames(5)
	_expect(
		controller.get_current_form() == "normal",
		"casting Shrink while already shrunk returns Grace to normal"
	)
	_expect(
		GameState.get_stat("mana") == mana_before_toggle,
		"returning to normal refunds the second Shrink cost"
	)
	_expect(
		get_tree().get_node_count_in_group("spell_effects")
		== baseline_spell_effects
		and get_tree().get_node_count_in_group("persistent_spell_effects")
		== baseline_persistent,
		"normal form removes every body-form performance counter"
	)

	controller.force_form("shrunk", true, false)
	var ceiling: StaticBody3D = _make_box(
		"BodyFormsLowCeiling",
		Vector3(0.0, 1.55, 0.0),
		Vector3(5.0, 0.5, 5.0)
	)
	add_child(ceiling)
	await get_tree().physics_frame
	var mana_before_rejected_expand: int = GameState.get_stat("mana")
	caster.call("select_ability", shrink_index, false)
	caster.call("cast_from_player", player, 0.0, false)
	await _wait_frames(5)
	_expect(
		controller.is_shrunk(),
		"returning to normal is rejected when the larger capsule cannot fit"
	)
	_expect(
		GameState.get_stat("mana") == mana_before_rejected_expand,
		"a clearance-rejected expansion refunds its Mana"
	)
	_expect(
		str(controller.get_debug_data().get("last_rejection", ""))
		.contains("not enough room"),
		"the controller records a readable clearance rejection"
	)

	ceiling.queue_free()
	await _wait_frames(3)
	controller.reset_target()
	await _wait_frames(2)
	_expect(
		controller.get_current_form() == "normal"
		and get_tree().get_node_count_in_group("persistent_spell_effects")
		== baseline_persistent,
		"reset restores normal size and removes the persistent form"
	)

	_finish([player, floor])


func _test_ability_contracts() -> void:
	_expect(GrowAbility.get_spell_id() == "grow", "Grow has a stable spell ID")
	_expect(ShrinkAbility.get_spell_id() == "shrink", "Shrink has a stable spell ID")
	_expect(
		GrowAbility.element == "body" and ShrinkAbility.element == "body",
		"both transformations belong to Body"
	)
	_expect(GrowAbility.mana_cost == 3, "Grow costs three Mana")
	_expect(ShrinkAbility.mana_cost == 2, "Shrink costs two Mana")
	_expect(
		GrowAbility.get_delivery_type() == "persistent_body_form"
		and ShrinkAbility.get_delivery_type() == "persistent_body_form",
		"both spells advertise persistent body-form delivery"
	)
	_expect(
		GrowAbility.get_ui_label() == "⇧+"
		and ShrinkAbility.get_ui_label() == "⇩-",
		"Grow and Shrink have distinct Focus badges"
	)


func _find_ability_index(caster: Node, spell_id: String) -> int:
	if caster == null:
		return -1
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return -1
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
	for ability_index: int in range(loadout.get_equipped_ability_count()):
		var ability: AbilityDefinition = loadout.get_equipped_ability(ability_index)
		if ability != null and ability.get_spell_id() == spell_id:
			return ability_index
	return -1


func _make_box(
	node_name: String,
	position_value: Vector3,
	size_value: Vector3
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.collision_layer = 1
	body.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	return body


func _prepare_stats() -> void:
	GameState.set_stat("max_health", 100)
	GameState.set_stat("health", 100)
	GameState.set_stat("max_mana", 100)
	GameState.set_stat("mana", 100)
	GameState.set_stat("max_stamina", 40)
	GameState.set_stat("stamina", 40)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)


func _wait_frames(frame_count: int) -> void:
	for _frame: int in range(maxi(frame_count, 0)):
		await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("BODY_FORMS_SPELL_SMOKE_TEST: " + label)


func _restore_state() -> void:
	GameState.stats = original_stats.duplicate(true)
	for stat_value: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_value)
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_value]))
	GameState.quick_spell_loadouts = original_quick_spell_loadouts.duplicate(true)
	GameState.quick_spell_selected_slots = (
		original_quick_spell_selected_slots.duplicate(true)
	)


func _finish(nodes: Array) -> void:
	Engine.time_scale = 1.0
	_restore_state()
	for node_value: Variant in nodes:
		if node_value is Node and is_instance_valid(node_value as Node):
			(node_value as Node).queue_free()
	if failures.is_empty():
		print("BODY_FORMS_SPELL_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("BODY_FORMS_SPELL_SMOKE_TEST: " + failure)
	get_tree().quit(1)
