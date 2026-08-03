extends Node

const LabScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_recorded_object_lab_v1.tscn"
)
const ReproduceAbility: AbilityDefinition = preload(
	"res://data/abilities/recorded_object_summon_ability.tres"
)
const Catalog = preload(
	"res://scripts/objects/recorded_object_catalog.gd"
)

var failures: Array[String] = []
var old_inventory: Dictionary = {}
var old_story_flags: Dictionary = {}
var old_stats: Dictionary = {}
var lab: Node3D
var manager: RecordedObjectManagerSpell


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	_capture_state()
	_clear_blueprints()
	HitStop.force_release()
	Engine.time_scale = 1.0
	lab = LabScene.instantiate() as Node3D
	add_child(lab)
	for _index: int in range(24):
		await get_tree().process_frame
	await get_tree().physics_frame

	manager = get_tree().get_first_node_in_group(
		"recorded_object_manager"
	) as RecordedObjectManagerSpell
	var player: Node3D = lab.get_node_or_null("Player") as Node3D
	var spell_controller: PlayerRecordedObjectSpellController = (
		get_tree().get_first_node_in_group(
			"recorded_object_spell_controllers"
		) as PlayerRecordedObjectSpellController
	)
	var context_hud: GameplayContextHUD = get_tree().get_first_node_in_group(
		"gameplay_context_hud"
	) as GameplayContextHUD
	var router: Node = get_tree().get_first_node_in_group(
		"player_control_router"
	)

	assert_true(manager != null, "spell-aware recorded object manager exists")
	assert_true(player != null, "player exists")
	assert_true(
		spell_controller != null,
		"recorded object spell controller exists"
	)
	assert_true(context_hud != null, "global gameplay context HUD exists")
	assert_true(router != null, "authoritative player control router exists")
	if manager == null or player == null or spell_controller == null:
		_restore_state()
		_finish()
		return

	lab.call("record_all_for_debug")
	await get_tree().process_frame
	assert_equal(
		Catalog.get_recorded_blueprint_ids().size(),
		4,
		"all object blueprints are available"
	)

	await _test_live_controller_ownership(
		player,
		spell_controller,
		router,
		context_hud
	)
	await _test_base_manager_safe_factory(player)
	await _test_live_charged_firebolt_barrel_path(player)

	_restore_state()
	_finish()


func _test_live_controller_ownership(
	player: Node3D,
	spell_controller: PlayerRecordedObjectSpellController,
	router: Node,
	context_hud: GameplayContextHUD
) -> void:
	Catalog.select_blueprint("crate")
	var cast_started: bool = spell_controller.begin_ability_channel(
		player,
		ReproduceAbility
	)
	assert_true(cast_started, "Reproduce Object begins placement")
	assert_true(manager.placement_active, "spell owns active placement")

	var quick_item_before: int = (
		int(router.call("get_selected_quick_item_slot"))
		if router.has_method("get_selected_quick_item_slot")
		else -1
	)
	var depth_before: float = manager.placement_depth_offset
	await _send_controller_button(JOY_BUTTON_DPAD_UP)
	assert_true(
		manager.placement_depth_offset > depth_before,
		"D-pad Up reaches placement depth before quick-item input"
	)
	if quick_item_before >= 0 and router.has_method("get_selected_quick_item_slot"):
		assert_equal(
			int(router.call("get_selected_quick_item_slot")),
			quick_item_before,
			"D-pad Up does not cycle the default quick item"
		)

	var weapon_controller: Node = player.get_node_or_null("WeaponController")
	await _send_controller_button(JOY_BUTTON_RIGHT_SHOULDER)
	assert_true(
		is_equal_approx(manager.placement_yaw_degrees, 90.0),
		"R rotates the placement preview"
	)
	if weapon_controller != null:
		assert_true(
			weapon_controller.get("current_attack") == null,
			"R does not perform its default weapon attack during placement"
		)

	await _send_controller_button(JOY_BUTTON_LEFT_SHOULDER)
	assert_true(
		is_equal_approx(manager.placement_yaw_degrees, 0.0),
		"L rotates the placement preview left"
	)
	var ability_caster: Node = player.get_node_or_null("AbilityCaster")
	if ability_caster != null and ability_caster.has_method(
		"is_focus_spell_menu_open"
	):
		assert_true(
			not bool(ability_caster.call("is_focus_spell_menu_open")),
			"L press and release do not open Focus during placement"
		)

	await _send_controller_button(JOY_BUTTON_DPAD_DOWN)
	assert_true(
		is_equal_approx(manager.placement_depth_offset, depth_before),
		"D-pad Down moves the preview nearer"
	)
	var special_context: Node = player.get_node_or_null(
		"PlayerSpecialContextController"
	)
	if special_context != null and special_context.has_method("get_debug_data"):
		var special_debug: Dictionary = special_context.call("get_debug_data")
		assert_true(
			not bool(special_debug.get("held", false))
			and not bool(special_debug.get("wheel_open", false)),
			"D-pad Down does not wake Special Context during placement"
		)

	await get_tree().process_frame
	if context_hud != null:
		context_hud.call("_refresh")
		var hud_debug: Dictionary = context_hud.get_debug_data()
		assert_true(
			bool(hud_debug.get("object_context", false)),
			"global HUD reports object placement context"
		)
	manager.cancel_placement()


func _test_base_manager_safe_factory(player: Node3D) -> void:
	var base_manager := RecordedObjectManager.new()
	base_manager.name = "BaseRecordedObjectManagerSafetyProbe"
	player.add_child(base_manager)
	base_manager.bind_actor(player)
	Catalog.select_blueprint("blast_barrel")
	var barrel: RecordedObjectInstance = base_manager.place_selected_at(
		Vector3(0.0, 0.0, 7.0),
		0.0,
		true,
		true
	)
	assert_true(
		barrel is RecordedObjectInstanceSafe,
		"the base manager also creates the deferred safe barrel actor"
	)
	base_manager.clear_spawned_objects()
	base_manager.queue_free()
	await get_tree().process_frame


func _test_live_charged_firebolt_barrel_path(player: Node3D) -> void:
	manager.clear_spawned_objects()
	Catalog.select_blueprint("blast_barrel")
	var first: RecordedObjectInstance = manager.place_selected_at(
		Vector3(-1.0, 0.0, 9.0),
		0.0,
		true,
		true
	)
	var second: RecordedObjectInstance = manager.place_selected_at(
		Vector3(1.0, 0.0, 9.0),
		0.0,
		true,
		true
	)
	assert_true(first is RecordedObjectInstanceSafe, "first barrel uses safe actor")
	assert_true(second is RecordedObjectInstanceSafe, "chain barrel uses safe actor")
	if first == null:
		return

	var projectile := GenericProjectile.new()
	projectile.name = "ChargedFireboltBarrelRegressionProjectile"
	lab.add_child(projectile)
	projectile.global_position = first.global_position + Vector3(0.0, 0.4, 0.0)
	projectile.set_source_actor(player)
	var fire := DamagePayload.new()
	fire.element = "fire"
	fire.amount = 4
	fire.stance_damage = 4
	fire.status_strength = 1.0
	fire.source_name = "Charged Firebolt"
	fire.hit_type = "projectile"
	fire.tags = [
		"magic",
		"projectile",
		"fire",
		"firebolt",
		"charged",
		"heavy_impact",
		"ignite",
	]
	projectile.set_payload(fire)
	projectile.try_hit(first)

	var frame_counter: int = 0
	for _index: int in range(18):
		await get_tree().process_frame
		frame_counter += 1
		await get_tree().physics_frame
	assert_equal(
		frame_counter,
		18,
		"process and physics frames continue after real projectile impact"
	)
	assert_true(
		not bool(HitStop.get_debug_data().get("active", true)),
		"charged Firebolt HitStop releases after the barrel impact"
	)
	assert_true(
		is_equal_approx(Engine.time_scale, 1.0),
		"real charged Firebolt barrel impact restores global time"
	)
	assert_true(
		first == null
		or not is_instance_valid(first)
		or first.is_queued_for_deletion(),
		"first barrel resolves and exits"
	)
	assert_true(
		second == null
		or not is_instance_valid(second)
		or second.is_queued_for_deletion(),
		"nearby barrel resolves through the deferred chain"
	)


func _send_controller_button(button_index: JoyButton) -> void:
	var pressed := InputEventJoypadButton.new()
	pressed.device = 0
	pressed.button_index = button_index
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := InputEventJoypadButton.new()
	released.device = 0
	released.button_index = button_index
	released.pressed = false
	Input.parse_input_event(released)
	await get_tree().process_frame


func _capture_state() -> void:
	old_inventory = GameState.inventory.duplicate(true)
	old_story_flags = GameState.story_flags.duplicate(true)
	old_stats = GameState.stats.duplicate(true)


func _clear_blueprints() -> void:
	for blueprint_id: String in Catalog.BLUEPRINT_ORDER:
		GameState.inventory.erase(Catalog.get_item_id(blueprint_id))
	GameState.story_flags.erase(Catalog.SELECTED_BLUEPRINT_FLAG)


func _restore_state() -> void:
	HitStop.force_release()
	Engine.time_scale = 1.0
	if manager != null and is_instance_valid(manager):
		manager.clear_spawned_objects()
	if lab != null and is_instance_valid(lab):
		lab.queue_free()
	GameState.inventory = old_inventory.duplicate(true)
	GameState.story_flags = old_story_flags.duplicate(true)
	GameState.stats = old_stats.duplicate(true)


func _finish() -> void:
	if failures.is_empty():
		print("RECORDED_OBJECT_SPELL_CONTEXT_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("RECORDED_OBJECT_SPELL_CONTEXT_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func assert_true(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(
			label
			+ " (expected "
			+ str(expected)
			+ ", got "
			+ str(actual)
			+ ")"
		)
