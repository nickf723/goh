extends Node

const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")
const DuplicateAbility: AbilityDefinition = preload("res://data/abilities/duplicate_ability.tres")
const FireboltAbility: AbilityDefinition = preload("res://data/abilities/firebolt_ability.tres")
const RainAbility: AbilityDefinition = preload("res://data/abilities/rain_weather_ability.tres")
const GrowAbility: AbilityDefinition = preload("res://data/abilities/grow_ability.tres")
const FamiliarAbility: AbilityDefinition = preload("res://data/abilities/spectral_familiar_ability.tres")
const RepeatDefinition: Resource = preload("res://data/concentration/repeat_concentration.tres")
const Semantics = preload("res://scripts/abilities/spell_clone_semantics.gd")

var failures: Array[String] = []
var original_stats: Dictionary = {}

class DuplicateHitTarget:
	extends StaticBody3D
	var hits: int = 0
	var duplicate_hits: int = 0
	func receive_damage_payload(payload: DamagePayload) -> Dictionary:
		hits += 1
		if payload.tags.has("duplicate") or payload.tags.has("live_clone"):
			duplicate_hits += 1
		return {"received": true, "damage": payload.amount}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	_prepare_stats()
	_test_semantics()
	var floor := _make_floor()
	add_child(floor)
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "DuplicateSmokePlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	player.add_to_group("player")
	add_child(player)
	await _wait_frames(20)
	await get_tree().physics_frame

	var caster: Node = player.get_node_or_null("AbilityCaster")
	var duplicate_index: int = _find_ability_index(caster, "duplicate")
	_expect(duplicate_index >= 0, "Duplicate appears in Grace's complete Focus/runtime library")
	if caster == null or duplicate_index < 0:
		_finish([player, floor])
		return
	caster.call("select_ability", duplicate_index, false)
	_expect(bool(caster.call("cast_from_player", player, 0.0, false)), "Duplicate casts through AbilityCaster")
	await _wait_frames(8)

	var manager: Node = get_tree().get_first_node_in_group("concentration_manager")
	var controller: SoulDuplicateControllerReady = get_tree().get_first_node_in_group("soul_duplicate_controller") as SoulDuplicateControllerReady
	var duplicate: SoulDuplicateActorReady = get_tree().get_first_node_in_group("soul_duplicates") as SoulDuplicateActorReady
	_expect(manager != null and manager.has_method("has_effect") and bool(manager.call("has_effect", "duplicate_concentration")), "Duplicate owns a 25% concentration reservation")
	_expect(controller != null, "Duplicate installs one live mirror controller")
	_expect(duplicate != null, "Duplicate creates one Soul Grace")
	if manager == null or controller == null or duplicate == null:
		_finish([player, floor])
		return
	_expect(duplicate is CharacterBody3D, "Soul Grace is a physical CharacterBody3D")
	_expect(duplicate.global_position.distance_to(player.global_position) > 1.0, "Soul Grace begins spatially separate from Grace")
	_expect(duplicate.get_node_or_null("CollisionShape3D") != null, "Soul Grace owns independent collision")
	_expect(duplicate.get_node_or_null("AbilityCaster") is SoulDuplicateAbilityProxy, "Soul Grace uses a tiny casting proxy rather than a second player HUD stack")
	_expect(int(manager.call("get_reservation_percent")) == 25, "Duplicate reserves exactly 25 percent Mana")

	_expect(bool(manager.call("activate_effect", RepeatDefinition, caster)), "Repeat can stack beside Duplicate")
	_expect(bool(manager.call("has_effect", "duplicate_concentration")) and bool(manager.call("has_effect", "repeat_concentration")), "Duplicate and Repeat coexist in the concentration budget")
	_expect(int(manager.call("get_reservation_percent")) == 45, "Duplicate plus Repeat reserves 45 percent")
	manager.call("deactivate_effect_by_id", "repeat_concentration", false)

	controller.call("_mirror_ability", GrowAbility, null)
	await _wait_frames(2)
	_expect(duplicate.current_form == "grown" and duplicate.form_scale > 1.5, "Grow independently enlarges Soul Grace")
	controller.call("_mirror_ability", GrowAbility, null)
	await _wait_frames(2)
	_expect(duplicate.current_form == "normal", "casting Grow again returns Soul Grace to normal")

	var target := DuplicateHitTarget.new()
	target.name = "DuplicateMeleeTarget"
	target.position = duplicate.global_position + Vector3(0.0, 0.0, 1.55)
	target.collision_layer = 1
	var target_collision := CollisionShape3D.new()
	var target_shape := SphereShape3D.new()
	target_shape.radius = 0.55
	target_collision.shape = target_shape
	target.add_child(target_collision)
	add_child(target)
	var attack := WeaponAttackDefinition.new()
	attack.attack_id = "duplicate_smoke_attack"
	attack.startup_time = 0.01
	attack.attack_range = 2.2
	attack.attack_center_forward_offset = 0.8
	attack.cone_angle_degrees = 140.0
	var test_payload := DamagePayload.new()
	test_payload.amount = 3
	test_payload.stance_damage = 2
	attack.payload = test_payload
	duplicate.mirror_weapon_attack(attack, null)
	await _wait_frames(5)
	_expect(target.hits >= 1 and target.duplicate_hits >= 1, "Soul Grace resolves its own duplicate-tagged melee hit")

	var firebolt_index: int = _find_ability_index(caster, "firebolt")
	if firebolt_index >= 0:
		caster.call("select_ability", firebolt_index, false)
		var clone_count_before: int = _count_live_clone_spell_nodes()
		controller.call("_mirror_ability", FireboltAbility, null)
		await _wait_frames(2)
		_expect(_count_live_clone_spell_nodes() > clone_count_before, "a clone-safe projectile creates a second live spell instance")

	var noop_before: int = controller.world_state_noop_count
	controller.call("_mirror_ability", RainAbility, null)
	_expect(controller.world_state_noop_count == noop_before + 1, "weather is a Duplicate world-state no-op")
	_expect(Semantics.get_duplicate_mode(DuplicateAbility) == Semantics.DUPLICATE_SUPPRESS, "Duplicate cannot recursively duplicate itself")
	_expect(Semantics.get_duplicate_mode(FamiliarAbility) == Semantics.DUPLICATE_SUPPRESS, "summon ownership remains suppressed")

	manager.call("deactivate_effect_by_id", "duplicate_concentration", false)
	await _wait_frames(4)
	_expect(get_tree().get_node_count_in_group("soul_duplicates") == 0, "releasing Duplicate removes Soul Grace")
	_expect(get_tree().get_first_node_in_group("soul_duplicate_controller") == null, "releasing Duplicate removes its live mirror controller")
	_finish([target, player, floor])


func _test_semantics() -> void:
	_expect(Semantics.get_duplicate_mode(FireboltAbility) == Semantics.DUPLICATE_LIVE, "projectiles are live second simulations")
	_expect(Semantics.get_duplicate_mode(GrowAbility) == Semantics.DUPLICATE_SOURCE_STATE, "body transformations are live duplicate source state")
	_expect(Semantics.get_duplicate_mode(RainAbility) == Semantics.DUPLICATE_WORLD_STATE, "weather remains one shared world state")


func _count_live_clone_spell_nodes() -> int:
	var count: int = 0
	_count_clone_nodes_recursive(get_tree().current_scene, count)
	return count


func _count_clone_nodes_recursive(node: Node, counter: int) -> int:
	if node == null:
		return counter
	if bool(node.get_meta("clone_live_simulation", false)):
		counter += 1
	for child: Node in node.get_children():
		counter = _count_clone_nodes_recursive(child, counter)
	return counter


func _find_ability_index(caster: Node, spell_id: String) -> int:
	if caster == null:
		return -1
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return -1
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
	for index: int in range(loadout.get_equipped_ability_count()):
		var ability: AbilityDefinition = loadout.get_equipped_ability(index)
		if ability != null and ability.get_spell_id() == spell_id:
			return index
	return -1


func _make_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "DuplicateSmokeFloor"
	floor.position = Vector3(0, -0.5, 0)
	floor.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40, 1, 40)
	collision.shape = shape
	floor.add_child(collision)
	return floor


func _prepare_stats() -> void:
	GameState.set_stat("max_health", 100)
	GameState.set_stat("health", 100)
	GameState.set_stat("max_mana", 100)
	GameState.set_stat("mana", 100)
	GameState.set_stat("max_stamina", 40)
	GameState.set_stat("stamina", 40)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)


func _wait_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures.append(label)
		push_error("DUPLICATE_SPELL_SMOKE_TEST: " + label)


func _restore_state() -> void:
	GameState.stats = original_stats.duplicate(true)
	for key: Variant in GameState.stats.keys():
		GameState.stat_changed.emit(str(key), int(GameState.stats[key]))


func _finish(nodes: Array) -> void:
	_restore_state()
	for value: Variant in nodes:
		if value is Node and is_instance_valid(value as Node):
			(value as Node).queue_free()
	if failures.is_empty():
		print("DUPLICATE_SPELL_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
