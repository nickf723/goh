extends "res://scripts/tests/artificer_construction_v1_smoke_test.gd"


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

	# The controller is authoritative about which Grace it belongs to. Resolve
	# every modal dependency from that same player instead of taking the first
	# globally registered router or HUD from a busy headless SceneTree.
	controller = get_tree().get_first_node_in_group(
		"player_artificer_spell_controllers"
	) as PlayerArtificerSpellController
	if controller != null:
		player = controller.get_parent() as Node3D
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		player = lab.find_child("Player", true, false) as Node3D

	if player != null:
		router = player.get_node_or_null("PlayerControlRouter")
		context_hud = player.get_node_or_null(
			"ArtificerConstructionRegressionHUD"
		) as GameplayContextHUD
		if context_hud == null:
			for child: Node in player.get_children():
				if child is GameplayContextHUD:
					context_hud = child as GameplayContextHUD
					break

	# Headless prototype shells do not always install FullMenuDirector's
	# presentation surface. Add the same production HUD to this Grace only.
	if context_hud == null and player != null:
		context_hud = GameplayContextHUD.new()
		context_hud.name = "ArtificerConstructionRegressionHUD"
		player.add_child(context_hud)
		await get_tree().process_frame
		await get_tree().process_frame
		if controller == null:
			controller = player.get_node_or_null(
				"ArtificerSpellController"
			) as PlayerArtificerSpellController
		if router == null:
			router = player.get_node_or_null("PlayerControlRouter")

	assert_true(player != null, "player exists")
	assert_true(controller != null, "Artificer spell controller exists")
	assert_true(router != null, "Grace-owned input router exists")
	assert_true(context_hud != null, "Grace-owned global context HUD exists")
	if player == null or controller == null:
		_restore_state()
		_finish()
		return

	manager = controller.get_manager() as ArtificerConstructionManagerSafe
	assert_true(manager != null, "safe Artificer construction manager exists")
	assert_true(
		manager != null and manager.get_parent() == player,
		"Grace owns the tested Artificer manager"
	)
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


func _clear_artificer_state() -> void:
	super._clear_artificer_state()
	for slot_id: String in BuildCatalog.CUSTOM_SLOT_ORDER:
		GameState.story_flags.erase(
			BuildCatalog.get_custom_slot_flag(slot_id)
		)


func _send_controller_button(button_index: JoyButton) -> void:
	var pressed := InputEventJoypadButton.new()
	pressed.device = 0
	pressed.button_index = button_index
	pressed.pressed = true
	var press_owned: bool = false
	if router != null and router.has_method("_handle_active_manipulation_button"):
		press_owned = bool(router.call(
			"_handle_active_manipulation_button",
			pressed
		))
	assert_true(
		press_owned,
		"Grace's modal router owns controller button " + str(int(button_index))
	)
	await get_tree().process_frame

	var released := InputEventJoypadButton.new()
	released.device = 0
	released.button_index = button_index
	released.pressed = false
	var release_owned: bool = false
	if router != null and router.has_method("_handle_active_manipulation_button"):
		release_owned = bool(router.call(
			"_handle_active_manipulation_button",
			released
		))
	assert_true(
		release_owned,
		"Grace's modal router owns controller release " + str(int(button_index))
	)
	await get_tree().process_frame
