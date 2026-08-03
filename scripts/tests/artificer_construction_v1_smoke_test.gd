extends Node

const LabScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_recorded_object_lab_v1.tscn"
)
const AssemblyAbility: AbilityDefinition = preload(
	"res://data/abilities/artificer_assembly_ability.tres"
)
const DeployAbility: AbilityDefinition = preload(
	"res://data/abilities/deploy_contraption_ability.tres"
)
const PartCatalog = preload(
	"res://scripts/builds/engineering_part_catalog.gd"
)
const BuildCatalog = preload(
	"res://scripts/builds/engineering_build_catalog.gd"
)

var failures: Array[String] = []
var old_inventory: Dictionary = {}
var old_story_flags: Dictionary = {}
var old_stats: Dictionary = {}
var lab: Node3D
var player: Node3D
var controller: PlayerArtificerSpellController
var manager: ArtificerConstructionManagerSafe
var router: Node
var context_hud: GameplayContextHUD


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	_capture_state()
	_clear_artificer_state()
	HitStop.force_release()
	Engine.time_scale = 1.0
	GameState.set_stat("max_mana", 100)
	GameState.set_stat("mana", 100)
	PartCatalog.unlock_all_for_debug()

	lab = LabScene.instantiate() as Node3D
	add_child(lab)
	for _index: int in range(28):
		await get_tree().process_frame
	await get_tree().physics_frame

	player = lab.get_node_or_null("Player") as Node3D
	controller = get_tree().get_first_node_in_group(
		"player_artificer_spell_controllers"
	) as PlayerArtificerSpellController
	router = get_tree().get_first_node_in_group("player_control_router")
	context_hud = get_tree().get_first_node_in_group(
		"gameplay_context_hud"
	) as GameplayContextHUD

	assert_true(player != null, "player exists")
	assert_true(controller != null, "Artificer spell controller exists")
	assert_true(router != null, "authoritative input router exists")
	assert_true(context_hud != null, "global context HUD exists")
	if player == null or controller == null:
		_restore_state()
		_finish()
		return

	manager = controller.get_manager() as ArtificerConstructionManagerSafe
	assert_true(manager != null, "safe Artificer construction manager exists")
	assert_true(
		controller.can_handle_ability(AssemblyAbility),
		"Artificer Assembly is an ability channel"
	)
	assert_true(
		controller.can_handle_ability(DeployAbility),
		"Deploy Contraption is an ability channel"
	)
	assert_true(
		BuildCatalog.validate_catalog().is_empty(),
		"part and starter blueprint catalogs validate"
	)
	for build_id: String in BuildCatalog.BUILD_ORDER:
		assert_true(
			not (BuildCatalog.get_definition(build_id).get("parts", []) as Array).is_empty(),
			build_id + " is authored as an engineering part layout"
		)

	await _test_field_assembly()
	await _test_saved_blueprint_deployment()
	await _test_starter_blueprint_runtime()

	_restore_state()
	_finish()


func _test_field_assembly() -> void:
	BuildCatalog.select_custom_slot("custom_1")
	PartCatalog.select_part("plate")
	var started: bool = controller.begin_ability_channel(player, AssemblyAbility)
	assert_true(started, "casting Artificer Assembly opens the workshop")
	assert_equal(manager.mode, manager.MODE_ASSEMBLY, "assembly mode is active")

	var part_before: String = PartCatalog.get_selected_part_id()
	var depth_before: float = manager.placement_depth_offset
	await _send_controller_button(JOY_BUTTON_DPAD_RIGHT)
	assert_true(
		PartCatalog.get_selected_part_id() != part_before,
		"D-pad Right cycles the engineering part palette"
	)
	await _send_controller_button(JOY_BUTTON_DPAD_UP)
	assert_true(
		manager.placement_depth_offset > depth_before,
		"D-pad Up changes Artificer placement depth"
	)
	await _send_controller_button(JOY_BUTTON_RIGHT_SHOULDER)
	assert_true(
		manager.placement_yaw_degrees > 0.0,
		"R rotates an Artificer part preview"
	)
	if context_hud != null:
		context_hud.call("_refresh")
		assert_true(
			bool(context_hud.get_debug_data().get("artificer_context", false)),
			"global HUD reports Artificer Assembly context"
		)

	PartCatalog.select_part("plate")
	var first: Node3D = manager.place_prepared_part_at(
		Vector3(0.0, 0.15, 9.0),
		0.0,
		true
	)
	assert_true(first != null, "first deck plate enters the draft")
	assert_true(manager.draft_root != null, "draft root exists")
	if manager.draft_root == null:
		return

	_place_draft_part("wheel", Vector3(-1.05, 0.55, -0.75), 90.0)
	_place_draft_part("wheel", Vector3(1.05, 0.55, -0.75), 90.0)
	_place_draft_part("wheel", Vector3(-1.05, 0.55, 0.75), 90.0)
	_place_draft_part("wheel", Vector3(1.05, 0.55, 0.75), 90.0)
	_place_draft_part("spring_unit", Vector3(0.0, 0.82, 0.0), 0.0)
	_place_draft_part("conductor_rail", Vector3(0.0, 1.18, 0.0), 0.0)
	assert_equal(manager.draft_parts.size(), 7, "custom machine contains seven parts")

	var result: Dictionary = manager.finalize_draft(true, true)
	assert_true(bool(result.get("ok", false)), "custom contraption finalizes")
	assert_true(BuildCatalog.is_custom_build("custom_1"), "Contraption A is saved")
	assert_equal(manager.mode, manager.MODE_NONE, "finalization closes assembly mode")

	var stored_blueprints: Dictionary = BuildCatalog.get_custom_blueprints()
	var stored: Dictionary = stored_blueprints.get("custom_1", {}) as Dictionary
	var stored_parts: Array = stored.get("parts", []) as Array
	assert_equal(stored_parts.size(), 7, "seven parts persist in the save slot")
	for value: Variant in stored_parts:
		if not value is Dictionary:
			failures.append("stored part is not a Dictionary")
			continue
		var position_value: Variant = (value as Dictionary).get("position")
		assert_true(
			position_value is Array,
			"stored part position is JSON-safe rather than Vector3"
		)
	var encoded_json: String = JSON.stringify(stored_blueprints)
	assert_true(encoded_json != "" and encoded_json != "null", "custom blueprint serializes to JSON")

	var definition: Dictionary = BuildCatalog.get_definition("custom_1")
	var features: Dictionary = definition.get("features", {}) as Dictionary
	assert_equal(int(features.get("wheels", 0)), 4, "wheels create mobility")
	assert_equal(int(features.get("springs", 0)), 1, "spring mechanism is derived")
	assert_true(int(features.get("conductors", 0)) >= 2, "spring and rail create conductivity")
	assert_equal(str(definition.get("body_mode", "")), "dynamic", "wheels make the machine dynamic")
	assert_true(int(definition.get("mana_cost", 0)) > 0, "mana cost is derived from parts")

	var manifestation: Variant = result.get("manifestation")
	assert_true(
		manifestation is ArtificerContraptionInstanceSafe,
		"finalization manifests the safe part-derived actor"
	)
	if manifestation is ArtificerContraptionInstanceSafe:
		var machine := manifestation as ArtificerContraptionInstanceSafe
		assert_equal(machine.parts.size(), 7, "runtime machine contains seven parts")
		var lightning := DamagePayload.new()
		lightning.element = "lightning"
		lightning.amount = 2
		lightning.status_strength = 1.0
		lightning.source_name = "Artificer Regression Lightning"
		lightning.tags = ["lightning", "electrical"]
		var response: Dictionary = machine.receive_damage_payload(lightning)
		assert_true(bool(response.get("handled", false)), "machine accepts elemental payloads")
		assert_equal(machine.overcharge_charges, 3, "Lightning grants three spring charges")


func _test_saved_blueprint_deployment() -> void:
	assert_true(BuildCatalog.select_build("custom_1"), "custom blueprint can be prepared")
	var started: bool = controller.begin_ability_channel(player, DeployAbility)
	assert_true(started, "Deploy Contraption opens custom blueprint placement")
	assert_equal(manager.mode, manager.MODE_DEPLOY, "deploy mode is active")
	var depth_before: float = manager.placement_depth_offset
	await _send_controller_button(JOY_BUTTON_DPAD_UP)
	await _send_controller_button(JOY_BUTTON_RIGHT_SHOULDER)
	assert_true(
		manager.placement_depth_offset > depth_before,
		"deployment uses Ultrahand-style depth"
	)
	assert_true(
		manager.placement_yaw_degrees > 0.0,
		"deployment uses shoulder rotation"
	)
	if context_hud != null:
		context_hud.call("_refresh")
		assert_true(
			bool(context_hud.get_debug_data().get("artificer_context", false)),
			"global HUD reports contraption deployment context"
		)
	manager.cancel_mode()

	var deployed: ArtificerContraptionInstance = manager.deploy_selected_at(
		Vector3(4.0, 0.0, 9.0),
		45.0,
		true,
		true
	)
	assert_true(
		deployed is ArtificerContraptionInstanceSafe,
		"saved personal blueprint redeploys as a safe contraption"
	)
	if deployed != null:
		assert_equal(deployed.parts.size(), 7, "redeployed personal blueprint preserves its layout")


func _test_starter_blueprint_runtime() -> void:
	var save_result: Dictionary = BuildCatalog.save_build("blast_cart")
	assert_true(bool(save_result.get("ok", false)), "starter Blast Cart schematic saves")
	assert_true(BuildCatalog.select_build("blast_cart"), "Blast Cart can be prepared")
	var blast_cart: ArtificerContraptionInstance = manager.deploy_selected_at(
		Vector3(-4.0, 0.0, 9.0),
		0.0,
		true,
		true
	)
	assert_true(
		blast_cart is ArtificerContraptionInstanceSafe,
		"starter schematics use the same safe part runtime"
	)
	if blast_cart == null:
		return
	var features: Dictionary = blast_cart.features
	assert_equal(int(features.get("wheels", 0)), 4, "Blast Cart receives four wheels")
	assert_equal(int(features.get("blast_cores", 0)), 1, "Blast Cart receives one blast core")
	var fire := DamagePayload.new()
	fire.element = "fire"
	fire.amount = 3
	fire.stance_damage = 3
	fire.status_strength = 1.0
	fire.source_name = "Artificer Regression Firebolt"
	fire.tags = ["fire", "ignite", "projectile"]
	var response: Dictionary = blast_cart.receive_damage_payload(fire)
	assert_true(bool(response.get("handled", false)), "Blast Cart accepts Firebolt")
	var frame_count: int = 0
	for _index: int in range(10):
		await get_tree().process_frame
		frame_count += 1
		await get_tree().physics_frame
	assert_equal(frame_count, 10, "frames continue after part-derived blast")
	assert_true(
		blast_cart == null
		or not is_instance_valid(blast_cart)
		or blast_cart.is_queued_for_deletion(),
		"part-derived Blast Cart detonates and exits"
	)


func _place_draft_part(
	part_id: String,
	local_center: Vector3,
	yaw_degrees: float
) -> void:
	PartCatalog.select_part(part_id)
	var world_center: Vector3 = manager.draft_root.to_global(local_center)
	var node: Node3D = manager.place_prepared_part_at(
		world_center,
		yaw_degrees,
		true
	)
	assert_true(node != null, part_id + " attaches to the draft")


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


func _clear_artificer_state() -> void:
	GameState.story_flags.erase(BuildCatalog.CUSTOM_BLUEPRINTS_FLAG)
	GameState.story_flags.erase(BuildCatalog.SELECTED_BUILD_FLAG)
	GameState.story_flags.erase(BuildCatalog.SELECTED_CUSTOM_SLOT_FLAG)
	for part_id: String in PartCatalog.PART_ORDER:
		GameState.story_flags.erase(PartCatalog.UNLOCK_PREFIX + part_id)
	GameState.story_flags.erase(PartCatalog.SELECTED_PART_FLAG)
	for build_id: String in BuildCatalog.BUILD_ORDER:
		GameState.inventory.erase(BuildCatalog.get_item_id(build_id))


func _restore_state() -> void:
	HitStop.force_release()
	Engine.time_scale = 1.0
	if manager != null and is_instance_valid(manager):
		manager.clear_active_contraptions()
		manager.clear_draft()
		manager.cancel_mode()
	if lab != null and is_instance_valid(lab):
		lab.queue_free()
	GameState.inventory = old_inventory.duplicate(true)
	GameState.story_flags = old_story_flags.duplicate(true)
	GameState.stats = old_stats.duplicate(true)


func _finish() -> void:
	if failures.is_empty():
		print("ARTIFICER_CONSTRUCTION_V1_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("ARTIFICER_CONSTRUCTION_V1_SMOKE_TEST: " + failure)
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
