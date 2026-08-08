extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const GameUIScene: PackedScene = preload(
	"res://scenes/ui/game_ui.tscn"
)
const FocusGridLayoutScript = preload(
	"res://scripts/ui/focus_grid_layout.gd"
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
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "FocusGridMenuTestPlayer"
	player.add_to_group("player")
	add_child(player)
	for _frame: int in range(16):
		await get_tree().process_frame

	var caster: Node = player.get_node_or_null("AbilityCaster")
	var router: Node = player.get_node_or_null("PlayerControlRouter")
	_expect(caster != null, "player exposes the Focus caster")
	_expect(router != null, "Focus grid router installs")
	_expect(game_ui.has_method("get_focus_grid_debug_data"), "two-state Focus renderer is active")
	if caster == null or router == null or not game_ui.has_method("get_focus_grid_debug_data"):
		_finish([player, game_ui])
		return

	_expect(
		bool(caster.call("select_focus_spell_by_id", "leaf_volley")),
		"test can align Focus to Life"
	)
	caster.call("open_focus_spell_menu")
	for _frame: int in range(3):
		await get_tree().process_frame

	var element_page: Dictionary = game_ui.call("get_focus_grid_debug_data") as Dictionary
	_expect(bool(element_page.get("two_state", false)), "Focus reports the two-state grid contract")
	_expect(str(element_page.get("page", "")) == "elements", "Focus always opens on the element screen")
	_expect(int(element_page.get("element_columns", 0)) == 4, "element screen is four columns")
	_expect(int(element_page.get("element_count", 0)) == 16, "element screen contains all sixteen elements")
	_expect(int(element_page.get("family_labels", -1)) == 0, "NAT/PRI/VIT/MYS labels are removed")
	_expect(bool(element_page.get("fixed_panel", false)), "Focus renderer has one fixed physical panel")
	var panel_width: float = float(element_page.get("panel_width", 0.0))
	var panel_height: float = float(element_page.get("panel_height", 0.0))

	var start_element_index: int = int(caster.get("focus_element_index"))
	var right_event := InputEventJoypadButton.new()
	right_event.button_index = JOY_BUTTON_DPAD_RIGHT
	right_event.pressed = true
	router.call("_handle_focus_dpad", right_event)
	_expect(
		int(caster.get("focus_element_index"))
		== FocusGridLayoutScript.move_element_index(start_element_index, 1, 0, 16),
		"D-pad right moves one cell in the 4x4 element grid"
	)
	var left_event := InputEventJoypadButton.new()
	left_event.button_index = JOY_BUTTON_DPAD_LEFT
	left_event.pressed = true
	router.call("_handle_focus_dpad", left_event)

	caster.call("enter_focus_spell_grid")
	for _frame: int in range(3):
		await get_tree().process_frame
	var spell_page: Dictionary = game_ui.call("get_focus_grid_debug_data") as Dictionary
	_expect(str(spell_page.get("page", "")) == "spells", "confirming an element swaps to the spell screen")
	_expect(int(spell_page.get("spell_columns", 0)) == 3, "spell screen is a 3x3 grid")
	_expect(int(spell_page.get("spell_center_slot", -1)) == 4, "chosen element owns the center cell")
	_expect(int(spell_page.get("spell_count", 0)) == 3, "Life currently exposes its three learned spells")
	_expect(
		spell_page.get("spell_slots", []) == FocusGridLayoutScript.get_spell_slots(3),
		"Life spells occupy the shared triangular ring layout"
	)
	_expect(absf(float(spell_page.get("panel_width", 0.0)) - panel_width) < 0.01, "element and spell screens keep identical width")
	_expect(absf(float(spell_page.get("panel_height", 0.0)) - panel_height) < 0.01, "element and spell screens keep identical height")

	caster.call("return_to_focus_element_grid")
	await get_tree().process_frame
	var returned_page: Dictionary = game_ui.call("get_focus_grid_debug_data") as Dictionary
	_expect(str(returned_page.get("page", "")) == "elements", "back returns to the same 4x4 element screen")
	_expect(absf(float(returned_page.get("panel_width", 0.0)) - panel_width) < 0.01, "returning never resizes Focus")

	var router_script: Script = router.get_script() as Script
	_expect(
		router_script != null
		and router_script.resource_path == "res://scripts/input/player_control_router_focus_grid.gd",
		"controller uses the grid-specific D-pad router"
	)

	caster.call("close_focus_spell_menu")
	_finish([player, game_ui])


func _prepare_stats() -> void:
	GameState.set_stat("max_health", 100)
	GameState.set_stat("health", 100)
	GameState.set_stat("max_mana", 100)
	GameState.set_stat("mana", 100)
	GameState.set_stat("max_stamina", 40)
	GameState.set_stat("stamina", 40)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)
	GameState.set_stat("max_focus", 40)
	GameState.set_stat("focus", 40)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


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
		print("COMPACT_FOCUS_MENU_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("COMPACT_FOCUS_MENU_SMOKE_TEST: " + failure)
	get_tree().quit(1)
