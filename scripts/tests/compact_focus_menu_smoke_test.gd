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
	_expect(game_ui.has_method("get_compact_focus_debug_data"), "compact Focus presentation is active")
	if caster == null or not game_ui.has_method("get_compact_focus_debug_data"):
		_finish([player, game_ui])
		return

	_expect(
		bool(caster.call("select_focus_spell_by_id", "duplicate")),
		"Soul library can select the fifth spell"
	)
	caster.call("open_focus_spell_menu")
	for _frame: int in range(4):
		await get_tree().process_frame

	var compact: Dictionary = game_ui.call("get_compact_focus_debug_data") as Dictionary
	_expect(bool(compact.get("compact", false)), "Focus reports compact picker mode")
	_expect(str(compact.get("title", "")) == "SPELL FOCUS", "Focus no longer presents itself as a full library dashboard")
	_expect(bool(compact.get("scroll_backed", false)), "spell list is capped by a ScrollContainer")
	_expect(float(compact.get("panel_bottom", 0.0)) <= -120.0, "Focus picker sits above the permanent command dock")
	_expect(bool(compact.get("selection_detail_hidden", false)), "redundant selection-detail row is removed")

	var focus_debug: Dictionary = game_ui.call("get_focus_presentation_debug_data") as Dictionary
	_expect(int(focus_debug.get("cached_elements", 0)) == 16, "all sixteen elements remain visible")
	var grid_value: Variant = game_ui.get("focus_spell_element_grid")
	_expect(grid_value is GridContainer and (grid_value as GridContainer).columns == 5, "four labeled element families remain a compact five-column matrix")

	var scroll_value: Variant = game_ui.get("focus_spell_scroll")
	var list_value: Variant = game_ui.get("focus_spell_list")
	var scroll: ScrollContainer = scroll_value as ScrollContainer if scroll_value is ScrollContainer else null
	var spell_list: VBoxContainer = list_value as VBoxContainer if list_value is VBoxContainer else null
	_expect(scroll != null, "compact spell window exposes its scroll viewport")
	_expect(spell_list != null, "compact spell window keeps the cached spell list")
	if scroll != null and spell_list != null:
		_expect(spell_list.get_parent() == scroll, "spell rows live inside the capped viewport")
		_expect(spell_list.size.y > scroll.size.y, "a five-spell element scrolls instead of growing the panel")
		await get_tree().process_frame
		_expect(scroll.scroll_vertical > 0, "highlighting the last Soul spell auto-scrolls it into view")

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
