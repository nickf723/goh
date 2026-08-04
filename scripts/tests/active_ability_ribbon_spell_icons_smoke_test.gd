extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const GameUIScene: PackedScene = preload(
	"res://scenes/ui/game_ui.tscn"
)
const SpellIcons = preload(
	"res://scripts/ui/spell_icon_factory.gd"
)

class RibbonFixture:
	extends Node
	var entry: Dictionary = {
		"active": true,
		"id": "fixture_familiar",
		"label": "Juniper",
		"state": "Follow",
		"spell_ids": ["spectral_familiar"],
		"icon_text": "♢",
		"priority": 1,
	}

	func get_active_ability_ribbon_entry() -> Dictionary:
		return entry.duplicate(true)


var failures: Array[String] = []
var old_quick_loadouts: Dictionary = {}
var old_quick_selected: Dictionary = {}
var player: CharacterBody3D
var floor: StaticBody3D
var game_ui: Node
var hud: Node
var caster: Node
var control_router: Node
var context_router: Node
var ribbon: Node
var quick_dock: Node
var fixture: RibbonFixture


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	old_quick_loadouts = GameState.quick_spell_loadouts.duplicate(true)
	old_quick_selected = GameState.quick_spell_selected_slots.duplicate(true)
	floor = _make_floor()
	add_child(floor)
	game_ui = GameUIScene.instantiate()
	add_child(game_ui)
	player = PlayerScene.instantiate() as CharacterBody3D
	player.name = "RibbonSpellIconTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	for _frame: int in range(24):
		await get_tree().process_frame
	await get_tree().physics_frame

	hud = player.get_node_or_null("PlayerHUDV2")
	caster = player.get_node_or_null("AbilityCaster")
	control_router = player.get_node_or_null("PlayerControlRouter")
	context_router = player.get_node_or_null("AbilityContextRouter")
	if context_router != null and context_router.has_method(
		"get_active_ability_ribbon"
	):
		ribbon = context_router.call("get_active_ability_ribbon") as Node
	quick_dock = player.get_node_or_null("QuickSpellBeltPresentation")

	_expect(caster != null, "player retains the authoritative ability caster")
	_expect(control_router != null, "player retains the ten-slot quick-spell router")
	_expect(context_router != null, "player retains the ability context router")
	_expect(ribbon != null, "context router installs one active ability ribbon collector")
	_expect(quick_dock != null, "player installs the optimized command dock")
	_expect(
		game_ui != null
		and game_ui.has_method("get_spell_icon_presentation_debug_data"),
		"GameUI uses the icon-aware spell library subclass"
	)
	if (
		caster == null
		or control_router == null
		or context_router == null
		or ribbon == null
		or quick_dock == null
		or game_ui == null
	):
		await _cleanup_and_finish()
		return

	await _test_spell_icon_factory()
	await _test_quick_and_library_equipped_state()
	await _test_active_ability_ribbon()
	await _cleanup_and_finish()


func _test_spell_icon_factory() -> void:
	var fire_index: int = _find_ability_index("firebolt")
	_expect(fire_index >= 0, "Firebolt exists in the starting loadout")
	if fire_index < 0:
		return
	var firebolt: AbilityDefinition = _get_loadout().get_equipped_ability(
		fire_index
	)
	var descriptor: Dictionary = SpellIcons.get_debug_descriptor(firebolt)
	_expect(
		str(descriptor.get("glyph", "")) != "",
		"every spell receives a readable flat icon glyph"
	)
	var badge: PanelContainer = SpellIcons.create_badge(
		firebolt,
		36.0,
		true,
		true
	)
	add_child(badge)
	_expect(
		badge.get_meta("spell_icon_entry", {}) is Dictionary,
		"spell icon badges retain their spell metadata"
	)
	_expect(
		bool(badge.get_meta("spell_icon_equipped", false)),
		"spell icon badges expose equipped presentation state"
	)
	badge.queue_free()


func _test_quick_and_library_equipped_state() -> void:
	var fire_index: int = _find_ability_index("firebolt")
	var fire_field_index: int = _find_ability_index("fire_field")
	var familiar_index: int = _find_ability_index("spectral_familiar")
	_expect(fire_index >= 0, "Firebolt can be selected from the quick belt")
	_expect(fire_field_index >= 0, "Fire Field can be equipped from the spell library")
	_expect(familiar_index >= 0, "Summon Familiar can be equipped outside the ten quick slots")
	if fire_index < 0 or fire_field_index < 0 or familiar_index < 0:
		return

	var fire_slot: int = _find_quick_slot_for_ability(fire_index)
	var fire_field_slot: int = _find_quick_slot_for_ability(fire_field_index)
	_expect(fire_slot >= 0, "Firebolt has a quick spell slot")
	_expect(fire_field_slot >= 0, "Fire Field has a quick spell slot")
	if fire_slot < 0:
		return

	_expect(
		bool(control_router.call(
			"select_quick_spell_slot",
			fire_slot,
			"controller",
			false
		)),
		"quick spell selection equips Firebolt through the authoritative caster"
	)
	for _frame: int in range(4):
		await get_tree().process_frame
	var dock_data: Dictionary = quick_dock.call("get_debug_data") as Dictionary
	_expect(
		(dock_data.get("equipped_slot_indices", []) as Array).has(fire_slot),
		"quick-selected Firebolt receives the gold equipped slot indicator"
	)
	_expect(
		str(dock_data.get("equipped_spell_name", "")) == "Firebolt",
		"command dock header names the currently equipped spell"
	)

	caster.call("open_focus_spell_menu")
	for _frame: int in range(3):
		await get_tree().process_frame
	var icon_data: Dictionary = game_ui.call(
		"get_spell_icon_presentation_debug_data"
	) as Dictionary
	_expect(int(icon_data.get("icon_rows", 0)) >= 2, "Fire spell rows render icon badges")
	_expect(int(icon_data.get("badge_count", 0)) >= 2, "spell library builds one badge per visible spell")
	_expect(int(icon_data.get("equipped_rows", 0)) == 1, "spell library marks exactly one equipped spell")

	caster.call("cycle_focus_spell", 1)
	for _frame: int in range(2):
		await get_tree().process_frame
	var browsed_index: int = int(caster.call(
		"get_selected_focus_spell_global_index"
	))
	_expect(browsed_index != fire_index, "browsing can highlight a spell without equipping it")
	_expect(int(caster.get("current_ability_index")) == fire_index, "browsing leaves Firebolt equipped")
	icon_data = game_ui.call(
		"get_spell_icon_presentation_debug_data"
	) as Dictionary
	_expect(int(icon_data.get("equipped_rows", 0)) == 1, "equipped marker survives independent library browsing")

	caster.call("confirm_focus_spell_menu")
	for _frame: int in range(4):
		await get_tree().process_frame
	_expect(
		int(caster.get("current_ability_index")) == browsed_index,
		"confirming the library equips the highlighted spell"
	)
	dock_data = quick_dock.call("get_debug_data") as Dictionary
	if browsed_index == fire_field_index and fire_field_slot >= 0:
		_expect(
			(dock_data.get("equipped_slot_indices", []) as Array).has(
				fire_field_slot
			),
			"menu-equipped Fire Field moves the gold indicator to its quick slot"
		)
		_expect(
			(dock_data.get("cursor_slot_indices", []) as Array).has(fire_slot),
			"quick-slot cursor remains separate from the equipped spell"
		)

	caster.call("select_ability", familiar_index, false)
	caster.call("close_focus_spell_menu")
	for _frame: int in range(4):
		await get_tree().process_frame
	dock_data = quick_dock.call("get_debug_data") as Dictionary
	_expect(
		(dock_data.get("equipped_slot_indices", []) as Array).is_empty(),
		"an unassigned library spell does not falsely crown an old quick slot"
	)
	_expect(
		str(dock_data.get("equipped_spell_name", "")).contains("Familiar"),
		"command dock still names a menu-equipped spell outside the quick belt"
	)


func _test_active_ability_ribbon() -> void:
	fixture = RibbonFixture.new()
	fixture.name = "RibbonFixture"
	player.add_child(fixture)
	caster.call("close_focus_spell_menu")
	if ribbon.has_method("force_refresh"):
		ribbon.call("force_refresh")
	for _frame: int in range(2):
		await get_tree().process_frame
	var ribbon_data: Dictionary = ribbon.call("get_debug_data") as Dictionary
	_expect(int(ribbon_data.get("entry_count", 0)) == 1, "ribbon collector gathers active persistent providers")
	var unified_support: bool = (
		hud != null
		and hud.has_method("get_unified_hud_debug_data")
	)
	if unified_support:
		var support_data: Dictionary = hud.call(
			"get_unified_hud_debug_data"
		) as Dictionary
		_expect(
			int(support_data.get("active_ability_count", 0)) == 1,
			"unified support cluster displays the active persistent ability"
		)
		_expect(
			bool(ribbon_data.get("legacy_ribbon_hidden", false)),
			"standalone ribbon stays retired under the unified shell"
		)
	else:
		_expect(bool(ribbon_data.get("visible", false)), "legacy ribbon appears when a persistent ability is active")
	_expect(
		str(ribbon_data.get("highlighted_entry_id", "")) == "fixture_familiar",
		"provider collector highlights the entry matching the equipped familiar spell"
	)

	var fire_index: int = _find_ability_index("firebolt")
	caster.call("select_ability", fire_index, false)
	if ribbon.has_method("force_refresh"):
		ribbon.call("force_refresh")
	for _frame: int in range(2):
		await get_tree().process_frame
	ribbon_data = ribbon.call("get_debug_data") as Dictionary
	_expect(
		str(ribbon_data.get("highlighted_entry_id", "")) == "",
		"switching to an ordinary spell clears the persistent highlight without dismissing it"
	)
	_expect(int(ribbon_data.get("entry_count", 0)) == 1, "persistent provider entry survives ordinary spell selection")
	if unified_support:
		var ordinary_support_data: Dictionary = hud.call(
			"get_unified_hud_debug_data"
		) as Dictionary
		_expect(
			int(ordinary_support_data.get("active_ability_count", 0)) == 1,
			"support entry survives ordinary spell selection"
		)
		_expect(
			str(ordinary_support_data.get("highlighted_ability", "")) == "",
			"support cluster clears its highlight while Firebolt is equipped"
		)

	fixture.entry["active"] = false
	if ribbon.has_method("force_refresh"):
		ribbon.call("force_refresh")
	for _frame: int in range(2):
		await get_tree().process_frame
	ribbon_data = ribbon.call("get_debug_data") as Dictionary
	_expect(int(ribbon_data.get("entry_count", 0)) == 0, "provider collector removes dismissed persistent entries")
	if unified_support:
		var cleared_support_data: Dictionary = hud.call(
			"get_unified_hud_debug_data"
		) as Dictionary
		_expect(
			int(cleared_support_data.get("active_ability_count", 0)) == 0,
			"support cluster removes dismissed persistent entries"
		)
		_expect(
			bool(ribbon_data.get("legacy_ribbon_hidden", false)),
			"standalone ribbon remains hidden when the support cluster empties"
		)
	else:
		_expect(not bool(ribbon_data.get("visible", true)), "legacy ribbon hides when nothing persistent remains")


func _get_loadout() -> AbilityLoadout:
	var value: Variant = caster.get("loadout") if caster != null else null
	return value as AbilityLoadout if value is AbilityLoadout else null


func _find_ability_index(spell_id: String) -> int:
	var loadout: AbilityLoadout = _get_loadout()
	if loadout == null:
		return -1
	for index: int in range(loadout.get_equipped_ability_count()):
		var ability: AbilityDefinition = loadout.get_equipped_ability(index)
		if ability != null and ability.get_spell_id() == spell_id:
			return index
	return -1


func _find_quick_slot_for_ability(ability_index: int) -> int:
	if control_router == null or not control_router.has_method(
		"get_quick_spell_slot_rows"
	):
		return -1
	var rows_value: Variant = control_router.call("get_quick_spell_slot_rows")
	if not rows_value is Array:
		return -1
	for raw_row: Variant in rows_value as Array:
		if raw_row is Dictionary:
			var row: Dictionary = raw_row as Dictionary
			if int(row.get("ability_index", -1)) == ability_index:
				return int(row.get("slot_index", -1))
	return -1


func _make_floor() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "RibbonSpellIconTestFloor"
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(30.0, 0.5, 30.0)
	collision.shape = shape
	collision.position.y = -0.25
	body.add_child(collision)
	return body


func _cleanup_and_finish() -> void:
	if caster != null and is_instance_valid(caster):
		caster.call("close_focus_spell_menu")
	if player != null and is_instance_valid(player):
		player.queue_free()
	if game_ui != null and is_instance_valid(game_ui):
		game_ui.queue_free()
	if floor != null and is_instance_valid(floor):
		floor.queue_free()
	GameState.quick_spell_loadouts = old_quick_loadouts.duplicate(true)
	GameState.quick_spell_selected_slots = old_quick_selected.duplicate(true)
	await get_tree().process_frame
	_finish()


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("ACTIVE_ABILITY_RIBBON_SPELL_ICONS_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("ACTIVE_ABILITY_RIBBON_SPELL_ICONS_SMOKE_TEST: " + failure)
	get_tree().quit(1)
