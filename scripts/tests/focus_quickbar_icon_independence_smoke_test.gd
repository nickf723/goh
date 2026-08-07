extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const GameUIScene: PackedScene = preload(
	"res://scenes/ui/game_ui.tscn"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}
var original_quick_spell_loadouts: Dictionary = {}
var original_quick_spell_selected_slots: Dictionary = {}
var original_equipped: Array[AbilityDefinition] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	original_quick_spell_loadouts = GameState.quick_spell_loadouts.duplicate(true)
	original_quick_spell_selected_slots = (
		GameState.quick_spell_selected_slots.duplicate(true)
	)
	GameState.quick_spell_loadouts.clear()
	GameState.quick_spell_selected_slots.clear()
	_prepare_stats()

	var game_ui: Node = GameUIScene.instantiate()
	game_ui.name = "FocusIconTestGameUI"
	add_child(game_ui)
	var floor: StaticBody3D = _make_floor()
	add_child(floor)
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "FocusIconTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	for _frame: int in range(20):
		await get_tree().process_frame
	await get_tree().physics_frame

	var caster: Node = player.get_node_or_null("AbilityCaster")
	var router: Node = player.get_node_or_null("PlayerControlRouter")
	_expect(caster != null, "Focus icon test resolves AbilityCaster")
	_expect(router != null, "Focus icon test resolves quickbar router")
	_expect(
		game_ui.has_method("get_focus_library_icon_debug_data"),
		"production GameUI exposes learned-library icon diagnostics"
	)
	if caster == null or router == null or not game_ui.has_method(
		"get_focus_library_icon_debug_data"
	):
		_finish(game_ui, player, floor, null)
		return

	var loadout_value: Variant = caster.get("loadout")
	var loadout: AbilityLoadout = (
		loadout_value as AbilityLoadout
		if loadout_value is AbilityLoadout
		else null
	)
	_expect(loadout != null, "Focus icon test resolves the ability loadout")
	if loadout == null:
		_finish(game_ui, player, floor, null)
		return
	_copy_abilities(loadout.equipped_abilities, original_equipped)

	var before: Dictionary = game_ui.call(
		"get_focus_library_icon_debug_data",
		"fire"
	) as Dictionary
	var before_ids: Array = before.get("spell_ids", []) as Array
	_expect(before_ids.has("firebolt"), "Fire icon rows initially contain Firebolt")
	_expect(
		str(before.get("source", "")) == "learned_abilities",
		"Focus icon rows report the learned library as their source"
	)

	var firebolt_index: int = _find_equipped_index(loadout, "firebolt")
	var bubble: AbilityDefinition = _find_learned(loadout, "bubble")
	_expect(firebolt_index >= 0, "Focus icon test finds Firebolt runtime slot")
	_expect(bubble != null, "Focus icon test finds learned Bubble")
	if firebolt_index >= 0 and bubble != null:
		loadout.equip_ability(firebolt_index, bubble)
		await get_tree().process_frame
		var after: Dictionary = game_ui.call(
			"get_focus_library_icon_debug_data",
			"fire"
		) as Dictionary
		var after_ids: Array = after.get("spell_ids", []) as Array
		_expect(
			after_ids == before_ids,
			"overriding Firebolt in the quickbar leaves Fire icon rows unchanged"
		)
		_expect(
			after_ids.has("firebolt"),
			"Firebolt icon remains visible and hoverable in Focus"
		)
		_expect(
			not after_ids.has("bubble"),
			"the displaced Water shortcut does not leak into Fire Focus rows"
		)

	_expect(
		bool(caster.call("select_focus_spell_by_id", "surf")),
		"Focus icon test selects learned Surf"
	)
	var water_before: Dictionary = game_ui.call(
		"get_focus_library_icon_debug_data",
		"water"
	) as Dictionary
	var water_before_ids: Array = water_before.get("spell_ids", []) as Array
	_expect(water_before_ids.has("surf"), "Water icon rows contain Surf")
	_expect(
		bool(router.call("assign_selected_focus_spell_to_slot", 0)),
		"Surf assigns to the permanent quickbar"
	)
	await get_tree().process_frame
	var water_after: Dictionary = game_ui.call(
		"get_focus_library_icon_debug_data",
		"water"
	) as Dictionary
	var water_after_ids: Array = water_after.get("spell_ids", []) as Array
	_expect(
		water_after_ids == water_before_ids,
		"assigning Surf does not reorder or gray out Water Focus icon rows"
	)

	_finish(game_ui, player, floor, loadout)


func _find_equipped_index(loadout: AbilityLoadout, spell_id: String) -> int:
	for ability_index: int in range(loadout.equipped_abilities.size()):
		var ability: AbilityDefinition = loadout.equipped_abilities[ability_index]
		if ability != null and ability.get_spell_id() == spell_id:
			return ability_index
	return -1


func _find_learned(
	loadout: AbilityLoadout,
	spell_id: String
) -> AbilityDefinition:
	for ability: AbilityDefinition in loadout.get_learned_abilities():
		if ability != null and ability.get_spell_id() == spell_id:
			return ability
	return null


func _copy_abilities(
	source: Array[AbilityDefinition],
	destination: Array[AbilityDefinition]
) -> void:
	destination.clear()
	for ability: AbilityDefinition in source:
		destination.append(ability)


func _restore_loadout(loadout: AbilityLoadout) -> void:
	if loadout == null:
		return
	loadout.equipped_abilities.clear()
	for ability: AbilityDefinition in original_equipped:
		loadout.equipped_abilities.append(ability)


func _prepare_stats() -> void:
	GameState.set_stat("max_health", 100)
	GameState.set_stat("health", 100)
	GameState.set_stat("max_mana", 60)
	GameState.set_stat("mana", 60)
	GameState.set_stat("max_stamina", 40)
	GameState.set_stat("stamina", 40)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)


func _make_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "FocusIconFloor"
	floor.position = Vector3(0.0, -0.1, 0.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(30.0, 0.2, 30.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("FOCUS_QUICKBAR_ICON_INDEPENDENCE_SMOKE_TEST: " + label)


func _restore_state() -> void:
	GameState.stats = original_stats.duplicate(true)
	for stat_value: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_value)
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_value]))
	GameState.quick_spell_loadouts = original_quick_spell_loadouts.duplicate(true)
	GameState.quick_spell_selected_slots = (
		original_quick_spell_selected_slots.duplicate(true)
	)


func _finish(
	game_ui: Node,
	player: Node,
	floor: Node,
	loadout: AbilityLoadout
) -> void:
	Engine.time_scale = 1.0
	_restore_loadout(loadout)
	_restore_state()
	for node: Node in [player, floor, game_ui]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	if failures.is_empty():
		print("FOCUS_QUICKBAR_ICON_INDEPENDENCE_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("FOCUS_QUICKBAR_ICON_INDEPENDENCE_SMOKE_TEST: " + failure)
	get_tree().quit(1)
