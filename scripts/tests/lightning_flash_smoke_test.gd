extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const FlashAbility: AbilityDefinition = preload(
	"res://data/abilities/lightning_flash_ability.tres"
)
const SurfControllerScript = preload(
	"res://scripts/player/player_surf_controller.gd"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	_prepare_stats()
	_test_ability_contract()

	var floor: StaticBody3D = _make_floor()
	add_child(floor)
	var wall: StaticBody3D = _make_wall(Vector3(0.0, 2.0, -12.0))
	add_child(wall)
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "LightningFlashTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	for _frame: int in range(16):
		await get_tree().process_frame
	await get_tree().physics_frame

	var caster: Node = player.get_node_or_null("AbilityCaster")
	_expect(caster != null, "Flash test resolves AbilityCaster")
	_expect(caster is AbilityCasterFocusLibrary, "production player keeps the Focus-safe caster")
	if caster == null:
		_finish([player, wall, floor])
		return
	var flash_index: int = _find_flash_index(caster)
	_expect(flash_index >= 0, "Grace's runtime loadout contains Flash")
	if flash_index < 0:
		_finish([player, wall, floor])
		return

	var spell_effects_before: int = get_tree().get_node_count_in_group(
		"spell_effects"
	)
	var persistent_before: int = get_tree().get_node_count_in_group(
		"persistent_spell_effects"
	)
	var direct_flash: Node = FlashAbility.ability_scene.instantiate()
	add_child(direct_flash)
	direct_flash.call("set_source_actor", player)
	direct_flash.call("execute", player, Vector3(0.0, 0.0, -1.0))
	var direct_debug: Dictionary = direct_flash.call("get_debug_data") as Dictionary
	_expect(bool(direct_debug.get("contacted", false)), "Flash stops at the first solid wall")
	_expect(
		float(direct_debug.get("distance", 0.0)) > 9.5
		and float(direct_debug.get("distance", 0.0)) < 12.0,
		"Flash resolves the variable distance to first contact"
	)
	_expect(
		player.global_position.z < -9.5 and player.global_position.z > -11.5,
		"Flash places Grace immediately before the wall instead of inside it"
	)
	_expect(
		int(direct_debug.get("sweep_rays", 0)) == 9,
		"Flash uses one bounded nine-ray capsule-profile sweep"
	)
	_expect(
		int(direct_debug.get("visual_multimeshes", 0)) == 1
		and int(direct_debug.get("per_segment_nodes", -1)) == 0,
		"Flash renders the procedural bolt through one MultiMesh"
	)
	_expect(not player.visible, "Grace becomes visually absent inside the lightning bolt")
	_expect(
		get_tree().get_node_count_in_group("spell_effects")
		== spell_effects_before + 1,
		"active Flash registers one temporary spell effect"
	)
	_expect(
		get_tree().get_node_count_in_group("persistent_spell_effects")
		== persistent_before,
		"Flash never registers as a persistent spell"
	)
	direct_flash.call("_process", 0.06)
	_expect(player.visible, "Grace reappears at the destination after the bolt flash")
	direct_flash.call("_process", 0.2)
	await get_tree().process_frame
	_expect(
		get_tree().get_node_count_in_group("spell_effects") == spell_effects_before,
		"Flash removes its temporary spell effect after the trail fades"
	)

	player.global_position = Vector3(0.0, 0.96, 0.0)
	player.velocity = Vector3.ZERO
	var camera: Camera3D = player.get_node_or_null(
		"CameraPivot/SpringArm3D/Camera3D"
	) as Camera3D
	if camera != null:
		camera.global_rotation = Vector3.ZERO
		camera.current = true
	var starting_mana: int = GameState.get_stat("mana")
	var serial_before: int = int(player.get_meta("lightning_flash_serial", 0))
	caster.call("select_ability", flash_index, false)
	var cast_result: bool = bool(caster.call("cast_from_player", player, 0.0, false))
	_expect(cast_result, "Flash casts through the ordinary AbilityCaster path")
	_expect(
		GameState.get_stat("mana") == starting_mana - FlashAbility.mana_cost,
		"Flash spends its authored Mana cost"
	)
	_expect(
		int(player.get_meta("lightning_flash_serial", 0)) == serial_before + 1,
		"an ordinary Flash cast publishes one traversal result"
	)
	var caster_flash: Node = _find_flash_effect_for_player(player)
	_expect(caster_flash != null, "ordinary casting creates the Flash trail effect")
	if caster_flash != null:
		caster_flash.call("_process", 0.25)
	await get_tree().process_frame

	wall.collision_layer = 0
	wall.collision_mask = 0
	player.global_position = Vector3(0.0, 0.96, 0.0)
	player.velocity = Vector3.ZERO
	var open_flash: Node = FlashAbility.ability_scene.instantiate()
	add_child(open_flash)
	open_flash.call("set_source_actor", player)
	open_flash.call("execute", player, Vector3.RIGHT)
	var open_debug: Dictionary = open_flash.call("get_debug_data") as Dictionary
	_expect(not bool(open_debug.get("contacted", true)), "open-space Flash reaches its prototype cap")
	_expect(
		is_equal_approx(float(open_debug.get("distance", 0.0)), 24.0),
		"open-space Flash travels the complete twenty-four-meter line"
	)
	_expect(player.global_position.x > 23.5, "Flash moves horizontally without a safe-destination snap")
	open_flash.call("finish_flash", "test_cleanup")
	await get_tree().process_frame

	player.global_position = Vector3(0.0, 0.96, 0.0)
	player.velocity = Vector3.ZERO
	var upward_flash: Node = FlashAbility.ability_scene.instantiate()
	add_child(upward_flash)
	upward_flash.call("set_source_actor", player)
	upward_flash.call("execute", player, Vector3.UP)
	var upward_debug: Dictionary = upward_flash.call("get_debug_data") as Dictionary
	_expect(
		player.global_position.y > 24.0,
		"upward Flash deliberately leaves Grace high in open air"
	)
	_expect(
		not bool(upward_debug.get("contacted", true)),
		"Flash does not invent a safe landing when aimed into open sky"
	)
	_expect(
		float(upward_debug.get("upward_component", 0.0)) > 0.99,
		"Flash preserves the full upward aim component"
	)
	upward_flash.call("finish_flash", "test_cleanup")
	await get_tree().process_frame

	player.global_position = Vector3(0.0, 0.96, 0.0)
	player.velocity = Vector3.ZERO
	var surf: PlayerSurfController = SurfControllerScript.new() as PlayerSurfController
	surf.name = "SurfController"
	player.add_child(surf)
	await get_tree().process_frame
	surf.set_test_input_override(Vector2(0.0, -1.0), true)
	surf.activate_surf(Vector3(0.0, 0.0, -1.0))
	var surf_position_before: Vector3 = player.global_position
	var combo_flash: Node = FlashAbility.ability_scene.instantiate()
	add_child(combo_flash)
	combo_flash.call("set_source_actor", player)
	combo_flash.call("execute", player, Vector3.RIGHT)
	_expect(surf.is_surf_active(), "Flash preserves an active Surf state")
	_expect(
		player.global_position.distance_to(surf_position_before) > 20.0,
		"Flash relocates the active Surf rider along the aimed line"
	)
	combo_flash.call("finish_flash", "test_cleanup")
	surf.cancel_surf("test_cleanup")
	await get_tree().process_frame

	_expect(
		get_tree().get_node_count_in_group("persistent_spell_effects")
		== persistent_before,
		"Flash and Surf cleanup return persistent effects to baseline"
	)
	_finish([player, wall, floor])


func _find_flash_effect_for_player(player: Node) -> Node:
	for effect: Node in get_tree().get_nodes_in_group("lightning_flash_effects"):
		if (
			effect.has_method("belongs_to_source")
			and bool(effect.call("belongs_to_source", player))
		):
			return effect
	return null


func _test_ability_contract() -> void:
	_expect(FlashAbility.get_spell_id() == "flash", "Flash has a stable spell ID")
	_expect(FlashAbility.element == "lightning", "Flash belongs to Lightning")
	_expect(FlashAbility.mana_cost == 4, "Flash costs four Mana")
	_expect(
		FlashAbility.ability_scene != null
		and FlashAbility.ability_scene.resource_path
		== "res://scenes/actions/lightning_flash.tscn",
		"Flash uses its dedicated instant-travel action"
	)
	_expect(
		FlashAbility.get_targeting_style() == "directional_3d",
		"Flash advertises full three-dimensional aim"
	)
	_expect(
		FlashAbility.get_delivery_type() == "instant_travel",
		"Flash advertises instant-travel delivery"
	)
	_expect(
		FlashAbility.get_roles().has("evasion")
		and FlashAbility.get_roles().has("collision_stop"),
		"Flash exposes its dodge-alternative and first-contact identities"
	)


func _find_flash_index(caster: Node) -> int:
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return -1
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
	for ability_index: int in range(loadout.get_equipped_ability_count()):
		var ability: AbilityDefinition = loadout.get_equipped_ability(ability_index)
		if ability != null and ability.get_spell_id() == "flash":
			return ability_index
	return -1


func _make_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "LightningFlashTestFloor"
	floor.position = Vector3(0.0, -0.1, 0.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(80.0, 0.2, 80.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor


func _make_wall(position_value: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.name = "LightningFlashContactWall"
	wall.position = position_value
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(12.0, 6.0, 1.0)
	collision.shape = shape
	wall.add_child(collision)
	return wall


func _prepare_stats() -> void:
	GameState.set_stat("max_health", 100)
	GameState.set_stat("health", 100)
	GameState.set_stat("max_mana", 60)
	GameState.set_stat("mana", 60)
	GameState.set_stat("max_stamina", 40)
	GameState.set_stat("stamina", 40)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("LIGHTNING_FLASH_SMOKE_TEST: " + label)


func _restore_state() -> void:
	GameState.stats = original_stats.duplicate(true)
	for stat_value: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_value)
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_value]))


func _finish(nodes: Array) -> void:
	Engine.time_scale = 1.0
	_restore_state()
	for node_value: Variant in nodes:
		if node_value is Node and is_instance_valid(node_value as Node):
			(node_value as Node).queue_free()
	if failures.is_empty():
		print("LIGHTNING_FLASH_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("LIGHTNING_FLASH_SMOKE_TEST: " + failure)
	get_tree().quit(1)
