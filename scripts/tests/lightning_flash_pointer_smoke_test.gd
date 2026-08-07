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
	player.name = "LightningFlashPointerTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	for _frame: int in range(18):
		await get_tree().process_frame
	await get_tree().physics_frame

	var caster: Node = player.get_node_or_null("AbilityCaster")
	var pointer: PlayerSpellAimPointer = player.get_node_or_null(
		"SpellAimPointer"
	) as PlayerSpellAimPointer
	var aim_controller: PlayerFlashAimController = player.get_node_or_null(
		"FlashAimController"
	) as PlayerFlashAimController
	_expect(caster != null, "Flash test resolves AbilityCaster")
	_expect(caster is AbilityCasterFocusLibrary, "production player keeps the Focus-safe caster")
	_expect(pointer != null, "production player exposes the reusable spell pointer")
	_expect(aim_controller != null, "production player exposes the Flash aim controller")
	if caster == null or pointer == null or aim_controller == null:
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

	var direct_flash: Node = _spawn_direct_flash(player, Vector3(0.0, 0.0, -1.0))
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
	direct_flash.call("finish_flash", "test_cleanup")
	await get_tree().process_frame
	_expect(player.visible, "Grace reappears when the Flash trail resolves")

	wall.collision_layer = 0
	wall.collision_mask = 0
	player.global_position = Vector3(0.0, 0.96, 0.0)
	player.velocity = Vector3.ZERO
	var open_flash: Node = _spawn_direct_flash(player, Vector3.RIGHT)
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
	var upward_flash: Node = _spawn_direct_flash(player, Vector3.UP)
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
	caster.call("select_ability", flash_index, false)
	aim_controller.set_test_cast_held_override(true, true)
	var starting_mana: int = GameState.get_stat("mana")
	var serial_before: int = int(player.get_meta("lightning_flash_serial", 0))
	var aim_started: bool = bool(caster.call("cast_from_player", player, 0.0, false))
	_expect(aim_started, "pressing Cast begins Flash's pointer-aim state")
	_expect(aim_controller.is_flash_aiming(), "Flash remains in aim mode while Cast is held")
	_expect(pointer.is_owned_by(aim_controller), "Flash aim owns the shared pointer")
	_expect(
		GameState.get_stat("mana") == starting_mana,
		"Flash spends no Mana before the aimed line is committed"
	)

	pointer.set_logical_position_for_test(Vector2(0.5, 0.5))
	var center_direction: Vector3 = pointer.get_ray_direction()
	pointer.set_logical_position_for_test(Vector2(0.5, -1.4))
	var pointer_up: Vector3 = pointer.get_ray_direction()
	pointer.set_logical_position_for_test(Vector2(0.5, 2.4))
	var pointer_down: Vector3 = pointer.get_ray_direction()
	_expect(
		pointer_up.y > center_direction.y + 0.3,
		"Flash pointer extends upward beyond the camera-center pitch"
	)
	_expect(
		pointer_down.y < center_direction.y - 0.3,
		"Flash pointer extends downward beyond the camera-center pitch"
	)

	pointer.recenter()
	var committed: bool = aim_controller.commit_flash_for_test(Vector3.RIGHT)
	_expect(committed, "releasing the aimed Flash commits one instant traversal")
	_expect(not aim_controller.is_flash_aiming(), "Flash exits aim mode after commitment")
	_expect(not pointer.is_aim_active(), "Flash returns camera-look input after commitment")
	_expect(
		GameState.get_stat("mana") == starting_mana - FlashAbility.mana_cost,
		"committed Flash spends its authored Mana cost"
	)
	_expect(
		int(player.get_meta("lightning_flash_serial", 0)) == serial_before + 1,
		"pointer-aimed Flash publishes one traversal result"
	)
	_expect(player.global_position.x > 23.5, "pointer-aimed Flash obeys the committed direction")
	_cleanup_flash_effects()
	for _frame: int in range(8):
		await get_tree().process_frame

	player.global_position = Vector3(0.0, 0.96, 0.0)
	player.velocity = Vector3.ZERO
	var mana_before_cancel: int = GameState.get_stat("mana")
	aim_controller.set_test_cast_held_override(true, true)
	_expect(
		bool(caster.call("cast_from_player", player, 0.0, false)),
		"Flash can enter a second pointer-aim state"
	)
	aim_controller.cancel_ability_channel("test_cancel")
	_expect(not pointer.is_aim_active(), "cancelled Flash releases the pointer")
	_expect(
		GameState.get_stat("mana") == mana_before_cancel,
		"cancelled Flash aim spends no Mana"
	)

	player.global_position = Vector3(0.0, 0.96, 0.0)
	player.velocity = Vector3.ZERO
	var surf: PlayerSurfController = player.get_node_or_null(
		"SurfController"
	) as PlayerSurfController
	if surf == null:
		surf = SurfControllerScript.new() as PlayerSurfController
		surf.name = "SurfController"
		player.add_child(surf)
	await get_tree().process_frame
	surf.set_test_input_override(Vector2(0.0, -1.0), true)
	surf.activate_surf(Vector3(0.0, 0.0, -1.0))
	var surf_position_before: Vector3 = player.global_position
	var combo_flash: Node = _spawn_direct_flash(player, Vector3.RIGHT)
	_expect(surf.is_surf_active(), "Flash preserves an active Surf state")
	_expect(
		player.global_position.distance_to(surf_position_before) > 20.0,
		"Flash relocates the active Surf rider along the aimed line"
	)
	combo_flash.call("finish_flash", "test_cleanup")
	surf.cancel_surf("test_cleanup")
	await get_tree().process_frame

	_cleanup_flash_effects()
	await get_tree().process_frame
	_expect(
		get_tree().get_node_count_in_group("spell_effects") == spell_effects_before,
		"Flash trails return temporary spell effects to baseline"
	)
	_expect(
		get_tree().get_node_count_in_group("persistent_spell_effects")
		== persistent_before,
		"Flash and Surf cleanup return persistent effects to baseline"
	)
	_finish([player, wall, floor])


func _spawn_direct_flash(
	player: CharacterBody3D,
	direction: Vector3
) -> Node:
	var flash: Node = FlashAbility.ability_scene.instantiate()
	add_child(flash)
	if flash.has_method("set_source_actor"):
		flash.call("set_source_actor", player)
	flash.call("execute", player, direction)
	return flash


func _cleanup_flash_effects() -> void:
	for effect: Node in get_tree().get_nodes_in_group("lightning_flash_effects"):
		if effect.has_method("finish_flash"):
			effect.call("finish_flash", "test_cleanup")


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
		"Flash retains full three-dimensional aim metadata"
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
	_expect(
		FlashAbility.get_ui_tags().has("free_pointer")
		and FlashAbility.get_ui_tags().has("hold_to_aim"),
		"Flash advertises the independent hold-to-aim pointer"
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
	shape.size = Vector3(100.0, 0.2, 100.0)
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
	push_error("LIGHTNING_FLASH_POINTER_SMOKE_TEST: " + label)


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
		print("LIGHTNING_FLASH_POINTER_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("LIGHTNING_FLASH_POINTER_SMOKE_TEST: " + failure)
	get_tree().quit(1)
