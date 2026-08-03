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

	# The inherited laboratory may wrap Grace below another generated root. The
	# Artificer controller is authoritative about which actor it belongs to, so
	# resolve the player from that runtime relationship instead of a brittle path.
	controller = get_tree().get_first_node_in_group(
		"player_artificer_spell_controllers"
	) as PlayerArtificerSpellController
	if controller != null:
		player = controller.get_parent() as Node3D
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		player = lab.find_child("Player", true, false) as Node3D

	router = get_tree().get_first_node_in_group("player_control_router")
	context_hud = get_tree().get_first_node_in_group(
		"gameplay_context_hud"
	) as GameplayContextHUD

	# Headless prototype shells do not always install FullMenuDirector's
	# presentation surface. Add the same production HUD to Grace so this test can
	# validate Artificer context without depending on a particular launcher.
	if context_hud == null and player != null:
		context_hud = GameplayContextHUD.new()
		context_hud.name = "ArtificerConstructionRegressionHUD"
		player.add_child(context_hud)
		await get_tree().process_frame
		await get_tree().process_frame
		if controller == null:
			controller = get_tree().get_first_node_in_group(
				"player_artificer_spell_controllers"
			) as PlayerArtificerSpellController

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
