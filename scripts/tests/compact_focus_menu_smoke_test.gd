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
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "CompactFocusMenuTestPlayer"
	player.add_to_group("player")
	add_child(player)
	for _frame: int in range(12):
		await get_tree().process_frame

	var caster: Node = player.get_node_or_null("AbilityCaster")
	_expect(caster != null, "player exposes the Focus caster")
	_expect(game_ui.has_method("get_minimal_focus_debug_data"), "minimal Focus presentation is active")
	if caster == null or not game_ui.has_method("get_minimal_focus_debug_data"):
		_finish([player, game_ui])
		return

	_expect(
		bool(caster.call("select_focus_spell_by_id", "duplicate")),
		"Soul library can select the fifth spell"
	)
	caster.call("open_focus_spell_menu")
	for _frame: int in range(4):
		await get_tree().process_frame

	var minimal: Dictionary = game_ui.call("get_minimal_focus_debug_data") as Dictionary
	_expect(bool(minimal.get("minimal", false)), "Focus reports minimal picker mode")
	_expect(float(minimal.get("panel_width", 9999.0)) <= 650.0, "Focus wraps tightly around the two useful panes")
	_expect(float(minimal.get("panel_height", 9999.0)) <= 200.0, "Focus no longer occupies a large dashboard rectangle")
	_expect(bool(minimal.get("title_hidden", false)), "Focus title chrome is removed")
	_expect(bool(minimal.get("active_hidden", false)), "redundant active-spell header is removed")
	_expect(bool(minimal.get("element_header_hidden", false)), "redundant element heading is removed")
	_expect(bool(minimal.get("detail_hidden", false)), "redundant selected-spell detail is removed")
	_expect(bool(minimal.get("help_hidden", false)), "instruction footer is removed")
	_expect(int(minimal.get("element_matrix", 0)) == 16, "all sixteen element buttons remain")
	_expect(int(minimal.get("spell_rows", 0)) >= 5, "Soul spell rows remain visible")

	var focus_debug: Dictionary = game_ui.call("get_focus_presentation_debug_data") as Dictionary
	_expect(int(focus_debug.get("cached_elements", 0)) == 16, "Focus still caches all sixteen elements")
	var grid_value: Variant = game_ui.get("focus_spell_element_grid")
	_expect(
		grid_value is GridContainer
		and (grid_value as GridContainer).columns == 5,
		"element families remain the compact labeled matrix"
	)

	var scroll_value: Variant = game_ui.get("focus_spell_scroll")
	var list_value: Variant = game_ui.get("focus_spell_list")
	var scroll: ScrollContainer = scroll_value as ScrollContainer if scroll_value is ScrollContainer else null
	var spell_list: VBoxContainer = list_value as VBoxContainer if list_value is VBoxContainer else null
	_expect(scroll != null, "spell pane remains growth-safe with scrolling")
	_expect(spell_list != null, "spell pane retains its cached rows")
	if scroll != null and spell_list != null:
		_expect(spell_list.get_parent() == scroll, "spell rows live directly inside the scroll viewport")
		_expect(scroll.custom_minimum_size.y >= 165.0, "five ordinary spell rows fit without needless clipping")

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
