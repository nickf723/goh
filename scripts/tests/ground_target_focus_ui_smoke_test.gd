extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const GameUIScene: PackedScene = preload(
	"res://scenes/ui/game_ui.tscn"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	_prepare_stats()

	var game_ui: Node = GameUIScene.instantiate()
	add_child(game_ui)
	var floor: StaticBody3D = _make_floor()
	add_child(floor)
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "GroundTargetFocusUITestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	for _frame: int in range(12):
		await get_tree().process_frame
	await get_tree().physics_frame

	var ability_caster: Node = player.get_node_or_null("AbilityCaster")
	var router: Node = player.get_node_or_null("PlayerControlRouter")
	var dock: Node = player.get_node_or_null("QuickSpellBeltPresentation")
	_expect(ability_caster != null, "Ability caster remains available")
	_expect(router != null, "Unified controller router remains available")
	_expect(dock != null, "Optimized command dock installs")
	_expect(game_ui.has_method("get_focus_presentation_debug_data"), "Upgraded Focus UI installs")
	if ability_caster == null or router == null or dock == null:
		_finish(player, floor, game_ui)
		return

	var loadout_value: Variant = ability_caster.get("loadout")
	var loadout: AbilityLoadout = (
		loadout_value as AbilityLoadout
		if loadout_value is AbilityLoadout
		else null
	)
	_expect(loadout != null, "Test player has an ability loadout")
	if loadout == null:
		_finish(player, floor, game_ui)
		return
	var earth_spike_index: int = _find_spell_index(loadout, "earth_spike")
	_expect(earth_spike_index >= 0, "Earth Spike is available for AoE targeting")
	if earth_spike_index < 0:
		_finish(player, floor, game_ui)
		return

	ability_caster.call("select_ability", earth_spike_index, false)
	var targeting_started: bool = bool(
		ability_caster.call("cast_from_player", player, 0.18, false)
	)
	_expect(targeting_started, "Earth Spike enters ground targeting")
	_expect(
		bool(ability_caster.call("is_ground_targeting")),
		"Ground targeting controller is active"
	)
	await get_tree().process_frame

	var focus_panel_value: Variant = game_ui.get("focus_spell_panel")
	var focus_panel: Control = (
		focus_panel_value as Control if focus_panel_value is Control else null
	)
	_expect(
		focus_panel != null and not focus_panel.visible,
		"AoE targeting keeps the Focus library hidden"
	)
	var router_mode: Dictionary = router.call("get_input_mode_debug_data") as Dictionary
	_expect(
		str(router_mode.get("right_stick_owner", "")) == "ground_target",
		"Right stick ownership transfers exclusively to the AoE marker"
	)

	var element_before: int = int(ability_caster.get("focus_element_index"))
	var spell_before: int = int(ability_caster.get("focus_spell_index"))
	var stick_event := InputEventJoypadMotion.new()
	stick_event.axis = JOY_AXIS_RIGHT_X
	stick_event.axis_value = 1.0
	router.call("_input", stick_event)
	_expect(
		int(ability_caster.get("focus_element_index")) == element_before
		and int(ability_caster.get("focus_spell_index")) == spell_before,
		"Right-stick aiming cannot navigate the Focus library"
	)
	_expect(
		bool(router.call("handle_focus_action", true)),
		"Focus bumper is consumed while ground targeting"
	)
	_expect(
		focus_panel != null and not focus_panel.visible,
		"Focus bumper cannot reopen the library during AoE aiming"
	)

	ability_caster.call("cancel_ground_targeting", false)
	_expect(
		not bool(ability_caster.call("is_ground_targeting")),
		"Ground targeting cancels cleanly"
	)
	_expect(
		bool(router.call("handle_focus_action", true)),
		"Focus opens normally after targeting ends"
	)
	await get_tree().process_frame
	_expect(
		focus_panel != null and focus_panel.visible,
		"Focus library becomes visible in library mode"
	)

	var focus_debug: Dictionary = game_ui.call(
		"get_focus_presentation_debug_data"
	) as Dictionary
	_expect(bool(focus_debug.get("upgraded", false)), "Focus uses the upgraded presentation")
	_expect(int(focus_debug.get("cached_elements", 0)) == 16, "Focus caches all sixteen elements")
	var element_grid_value: Variant = game_ui.get("focus_spell_element_grid")
	_expect(
		element_grid_value is GridContainer
		and (element_grid_value as GridContainer).columns == 5,
		"Element families form four readable labeled rows"
	)

	var menu_data: Dictionary = ability_caster.call("get_focus_menu_data") as Dictionary
	var rebuilds_before: int = int(focus_debug.get("structure_rebuilds", 0))
	game_ui.call("show_spell_focus_menu", menu_data)
	game_ui.call("show_spell_focus_menu", menu_data)
	focus_debug = game_ui.call("get_focus_presentation_debug_data") as Dictionary
	_expect(
		int(focus_debug.get("structure_rebuilds", 0)) == rebuilds_before,
		"Repeated Focus refreshes reuse cached controls"
	)

	var dock_script: Script = dock.get_script() as Script
	_expect(
		dock_script != null
		and dock_script.resource_path == "res://scripts/ui/quick_spell_belt_performance.gd",
		"Permanent command dock uses the optimized coordinator"
	)
	var dock_before: Dictionary = dock.call("get_debug_data") as Dictionary
	for _frame: int in range(120):
		dock.call("_process", 1.0 / 60.0)
	var dock_after: Dictionary = dock.call("get_debug_data") as Dictionary
	var frame_delta: int = (
		int(dock_after.get("process_frames", 0))
		- int(dock_before.get("process_frames", 0))
	)
	var refresh_delta: int = (
		int(dock_after.get("heavy_refreshes", 0))
		- int(dock_before.get("heavy_refreshes", 0))
	)
	_expect(bool(dock_after.get("optimized", false)), "Command dock reports optimized refresh mode")
	_expect(
		frame_delta >= 120 and refresh_delta <= 20,
		"Two seconds of HUD frames coalesce into a small number of heavy refreshes"
	)
	_expect(
		int(dock_after.get("style_cache_size", 0)) > 0,
		"Command dock reuses cached StyleBoxes"
	)

	router.call("handle_focus_action", false)
	_finish(player, floor, game_ui)


func _find_spell_index(loadout: AbilityLoadout, spell_id: String) -> int:
	for index: int in range(loadout.get_equipped_ability_count()):
		var ability: AbilityDefinition = loadout.get_equipped_ability(index)
		if ability != null and ability.get_spell_id() == spell_id:
			return index
	return -1


func _prepare_stats() -> void:
	GameState.set_stat("max_health", 100)
	GameState.set_stat("health", 100)
	GameState.set_stat("max_mana", 60)
	GameState.set_stat("mana", 60)
	GameState.set_stat("max_stamina", 40)
	GameState.set_stat("stamina", 40)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)
	GameState.set_stat("max_focus", 40)
	GameState.set_stat("focus", 40)


func _make_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "GroundTargetFocusUITestFloor"
	floor.position = Vector3(0.0, -0.1, 0.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(30.0, 0.2, 30.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _restore_state() -> void:
	GameState.stats = original_stats.duplicate(true)
	for stat_value: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_value)
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_value]))


func _finish(player: Node, floor: Node, game_ui: Node) -> void:
	Engine.time_scale = 1.0
	_restore_state()
	if is_instance_valid(player):
		player.queue_free()
	if is_instance_valid(floor):
		floor.queue_free()
	if is_instance_valid(game_ui):
		game_ui.queue_free()
	if failures.is_empty():
		print("GROUND_TARGET_FOCUS_UI_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("GROUND_TARGET_FOCUS_UI_SMOKE_TEST: " + failure)
	get_tree().quit(1)
