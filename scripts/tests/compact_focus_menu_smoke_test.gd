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
	_expect(game_ui.has_method("get_compact_focus_grid_debug_data"), "compact Focus wrapper is active")
	if caster == null or router == null or not game_ui.has_method("get_focus_grid_debug_data"):
		_finish([player, game_ui])
		return

	_expect(
		bool(caster.call("select_focus_spell_by_id", "sprout")),
		"test can align Focus to the fifth Life spell"
	)
	caster.call("open_focus_spell_menu")
	# Intentionally inspect the first visible render before any navigation. This
	# catches the old bug where the large inherited border survived until D-pad.
	await get_tree().process_frame

	var element_page: Dictionary = game_ui.call("get_focus_grid_debug_data") as Dictionary
	_expect(bool(element_page.get("two_state", false)), "Focus reports the two-state grid contract")
	_expect(str(element_page.get("page", "")) == "elements", "Focus always opens on the element screen")
	_expect(int(element_page.get("element_columns", 0)) == 4, "element screen is four columns")
	_expect(int(element_page.get("element_count", 0)) == 16, "element screen contains all sixteen elements")
	_expect(int(element_page.get("family_labels", -1)) == 0, "NAT/PRI/VIT/MYS labels stay removed")
	_expect(bool(element_page.get("fixed_panel", false)), "Focus renderer has one fixed physical panel")

	var compact: Dictionary = game_ui.call("get_compact_focus_grid_debug_data") as Dictionary
	_expect(float(compact.get("compact_width", 9999.0)) <= 320.0, "Focus panel shrink-wraps the useful controls")
	_expect(float(compact.get("compact_height", 9999.0)) <= 195.0, "Focus panel no longer reserves dashboard height")
	_expect(str(compact.get("lightning_label", "")) == "Lightning", "Lightning is no longer abbreviated as Bolt")
	_expect(bool(compact.get("spell_labels_visible", false)), "spell cells explicitly keep their names visible")
	_expect(bool(compact.get("compact_applied_before_show", false)), "compact geometry owns the first visible Focus frame")

	var panel_value: Variant = game_ui.get("focus_spell_panel")
	var panel: PanelContainer = panel_value as PanelContainer if panel_value is PanelContainer else null
	_expect(panel != null, "Focus panel exists on first render")
	var panel_width: float = 0.0
	var panel_height: float = 0.0
	if panel != null:
		panel_width = panel.offset_right - panel.offset_left
		panel_height = panel.offset_bottom - panel.offset_top
		_expect(panel_width <= 320.0, "first element render never uses the large inherited border")
		_expect(panel_height <= 195.0, "first element render never uses the tall inherited border")

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
	for _frame: int in range(2):
		await get_tree().process_frame
	var spell_page: Dictionary = game_ui.call("get_focus_grid_debug_data") as Dictionary
	_expect(str(spell_page.get("page", "")) == "spells", "confirming an element swaps to the spell screen")
	_expect(int(spell_page.get("spell_columns", 0)) == 3, "spell screen is a 3x3 grid")
	_expect(int(spell_page.get("spell_center_slot", -1)) == 4, "chosen element owns the center cell")
	_expect(int(spell_page.get("spell_count", 0)) == 5, "Life exposes five learned spells including Sprout")
	_expect(
		spell_page.get("spell_slots", []) == FocusGridLayoutScript.get_spell_slots(5),
		"five Life spells use the shared ring layout"
	)
	if panel != null:
		_expect(absf((panel.offset_right - panel.offset_left) - panel_width) < 0.01, "element and spell screens keep identical width")
		_expect(absf((panel.offset_bottom - panel.offset_top) - panel_height) < 0.01, "element and spell screens keep identical height")

	var labels_value: Variant = game_ui.get("focus_spell_labels")
	if labels_value is Array:
		var labels: Array = labels_value as Array
		_expect(labels.size() == 5, "all five Life spell cells own text labels")
		for label_value: Variant in labels:
			_expect(label_value is Label and str((label_value as Label).text).strip_edges() != "", "spell label text is nonempty")
	else:
		_expect(false, "spell label cache is available")

	# B is now owned directly by the Focus router, so controller navigation does
	# not depend on ui_cancel being routed through Player._unhandled_input.
	var back_event := InputEventJoypadButton.new()
	back_event.button_index = JOY_BUTTON_B
	back_event.pressed = true
	_expect(
		bool(router.call("_handle_focus_grid_action_button", back_event)),
		"B is consumed as a Focus back command"
	)
	await get_tree().process_frame
	var returned_page: Dictionary = game_ui.call("get_focus_grid_debug_data") as Dictionary
	_expect(str(returned_page.get("page", "")) == "elements", "B returns from spells to the 4x4 element screen")

	# A enters again, proving A/B form a complete two-state controller grammar.
	var accept_event := InputEventJoypadButton.new()
	accept_event.button_index = JOY_BUTTON_A
	accept_event.pressed = true
	_expect(bool(router.call("_handle_focus_grid_action_button", accept_event)), "A is consumed as Focus confirm")
	await get_tree().process_frame
	_expect(bool(caster.call("is_focus_spell_grid_active")), "A enters the selected element spell grid")
	back_event.pressed = true
	router.call("_handle_focus_grid_action_button", back_event)
	await get_tree().process_frame
	_expect(not bool(caster.call("is_focus_spell_grid_active")), "B can back out repeatedly without trapping the player")

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
