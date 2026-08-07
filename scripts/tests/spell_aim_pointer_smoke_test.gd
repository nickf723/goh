extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const FirewallAbility: AbilityDefinition = preload(
	"res://data/abilities/firewall_ability.tres"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	_prepare_stats()

	var floor: StaticBody3D = _make_floor()
	add_child(floor)
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "SpellAimPointerTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	for _frame: int in range(18):
		await get_tree().process_frame
	await get_tree().physics_frame

	var pointer: PlayerSpellAimPointer = player.get_node_or_null(
		"SpellAimPointer"
	) as PlayerSpellAimPointer
	var flash_controller: PlayerFlashAimController = player.get_node_or_null(
		"FlashAimController"
	) as PlayerFlashAimController
	_expect(pointer != null, "production player installs one reusable spell pointer")
	_expect(flash_controller != null, "production player installs the Flash aim controller")
	if pointer == null:
		_finish([player, floor])
		return

	var test_owner := Node.new()
	test_owner.name = "PointerTestOwner"
	add_child(test_owner)
	_expect(
		pointer.begin_aim(test_owner, {
			"mode_id": "pointer_smoke",
			"capture_look": true,
			"horizontal_overflow_screens": 0.7,
			"vertical_overflow_screens": 1.8,
			"status_text": "POINTER TEST",
		}),
		"generic owners can claim the pointer"
	)
	_expect(pointer.captures_look_input(), "active pointer captures camera-look input")

	pointer.set_logical_position_for_test(Vector2(0.5, 0.5))
	var center_direction: Vector3 = pointer.get_ray_direction()
	pointer.set_logical_position_for_test(Vector2(0.5, -1.25))
	var upward_direction: Vector3 = pointer.get_ray_direction()
	var upward_debug: Dictionary = pointer.get_debug_data()
	pointer.set_logical_position_for_test(Vector2(0.5, 2.25))
	var downward_direction: Vector3 = pointer.get_ray_direction()
	var downward_debug: Dictionary = pointer.get_debug_data()

	_expect(
		upward_direction.y > center_direction.y + 0.3,
		"virtual pointer overflow aims substantially above the camera-center ray"
	)
	_expect(
		downward_direction.y < center_direction.y - 0.3,
		"virtual pointer overflow aims substantially below the camera-center ray"
	)
	_expect(
		bool(upward_debug.get("offscreen", false))
		and bool(downward_debug.get("offscreen", false)),
		"off-screen logical aim clamps its visible indicator to the viewport edge"
	)
	_expect(
		pointer.get_display_position().x >= 0.0
		and pointer.get_display_position().y >= 0.0,
		"visible pointer position remains screen-safe while its ray extends beyond the screen"
	)

	var logical_before_mouse: Vector2 = pointer.get_logical_position()
	pointer.handle_mouse_motion(Vector2(80.0, -45.0))
	_expect(
		pointer.get_logical_position() != logical_before_mouse,
		"captured mouse motion moves the independent pointer"
	)
	pointer.recenter()
	_expect(
		pointer.get_logical_position().distance_to(Vector2(0.5, 0.5)) < 0.001,
		"pointer recenter returns to the camera-center ray"
	)
	pointer.end_aim(test_owner, "test_complete")
	_expect(not pointer.is_aim_active(), "generic pointer ownership releases cleanly")

	var firewall: FirewallCast = (
		FirewallAbility.ability_scene.instantiate() as FirewallCast
	)
	_expect(firewall != null, "Firewall production action instantiates")
	if firewall != null:
		firewall.set_payload(FirewallAbility.get_action_payload())
		firewall.set_source_actor(player)
		add_child(firewall)
		firewall.execute(player, Vector3.FORWARD)
		await get_tree().process_frame
		_expect(pointer.is_owned_by(firewall), "Firewall claims the shared pointer while drawing")
		_expect(
			bool(firewall.get_debug_data().get("pointer_surface_ray", false)),
			"Firewall reports pointer-driven surface raycasting"
		)
		pointer.set_logical_position_for_test(Vector2(0.5, 1.2))
		firewall.cancel_drawing("pointer_test_cleanup")
		await get_tree().process_frame
		_expect(not pointer.is_aim_active(), "Firewall release returns camera-look authority")

	if flash_controller != null:
		var flash_ability: AbilityDefinition = _find_ability(player, "flash")
		_expect(
			flash_ability != null and flash_controller.can_handle_ability(flash_ability),
			"Flash aim controller claims the learned Flash spell"
		)

	_finish([player, floor, test_owner])


func _find_ability(player: Node, spell_id: String) -> AbilityDefinition:
	var caster: Node = player.get_node_or_null("AbilityCaster")
	if caster == null:
		return null
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return null
	for ability: AbilityDefinition in (
		loadout_value as AbilityLoadout
	).get_learned_abilities():
		if ability != null and ability.get_spell_id() == spell_id:
			return ability
	return null


func _make_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "SpellAimPointerFloor"
	floor.position = Vector3(0.0, -0.1, 0.0)
	floor.add_to_group("firewall_drawable_surface")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(80.0, 0.2, 80.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor


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
	push_error("SPELL_AIM_POINTER_SMOKE_TEST: " + label)


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
		print("SPELL_AIM_POINTER_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("SPELL_AIM_POINTER_SMOKE_TEST: " + failure)
	get_tree().quit(1)
