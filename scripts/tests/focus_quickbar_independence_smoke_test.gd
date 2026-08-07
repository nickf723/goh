extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}
var original_quick_spell_loadouts: Dictionary = {}
var original_quick_spell_selected_slots: Dictionary = {}
var original_equipped: Array[AbilityDefinition] = []
var original_learned: Array[AbilityDefinition] = []


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

	var floor: StaticBody3D = _make_floor()
	add_child(floor)
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "FocusQuickbarIndependencePlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	for _frame: int in range(16):
		await get_tree().process_frame
	await get_tree().physics_frame

	var caster: Node = player.get_node_or_null("AbilityCaster")
	var router: Node = player.get_node_or_null("PlayerControlRouter")
	_expect(caster is AbilityCasterFocusLibrary, "player uses the learned-spell Focus caster")
	_expect(router is PlayerControlRouterFocusLibrary, "player uses the Focus-safe quickbar router")
	if caster == null or router == null:
		_finish(player, floor, null)
		return

	var loadout_value: Variant = caster.get("loadout")
	var loadout: AbilityLoadout = (
		loadout_value as AbilityLoadout
		if loadout_value is AbilityLoadout
		else null
	)
	_expect(loadout != null, "player has an ability loadout")
	if loadout == null:
		_finish(player, floor, null)
		return

	_copy_abilities(loadout.equipped_abilities, original_equipped)
	_copy_abilities(loadout.learned_abilities, original_learned)
	var original_fire_names: Array = caster.call(
		"get_focus_spell_names_for_element",
		"fire"
	) as Array
	var original_water_names: Array = caster.call(
		"get_focus_spell_names_for_element",
		"water"
	) as Array
	_expect(original_fire_names.has("Firebolt"), "Focus initially contains Firebolt")
	_expect(original_water_names.has("Surf"), "Focus includes Surf from the learned library")

	var firebolt_index: int = _find_equipped_index(loadout, "firebolt")
	var bubble: AbilityDefinition = _find_learned(loadout, "bubble")
	_expect(firebolt_index >= 0, "runtime loadout contains Firebolt")
	_expect(bubble != null, "learned library contains Bubble")
	if firebolt_index >= 0 and bubble != null:
		loadout.equip_ability(firebolt_index, bubble)
		await get_tree().process_frame
		var fire_names_after_replace: Array = caster.call(
			"get_focus_spell_names_for_element",
			"fire"
		) as Array
		_expect(
			fire_names_after_replace == original_fire_names,
			"overriding a quick runtime slot does not alter the Fire Focus list"
		)
		_expect(
			bool(caster.call("select_focus_spell_by_id", "firebolt")),
			"Firebolt remains selectable in Focus after its quick slot is replaced"
		)
		var selected: Variant = caster.call("get_selected_focus_ability")
		_expect(
			selected is AbilityDefinition
			and (selected as AbilityDefinition).get_spell_id() == "firebolt",
			"Focus resolves the learned Firebolt resource rather than the replaced slot"
		)
		_expect(
			bool(router.call("assign_selected_focus_spell_to_slot", firebolt_index)),
			"Focus can assign the learned Firebolt back into the quickbar"
		)
		var rows: Array = router.call("get_quick_spell_slot_rows") as Array
		var repaired_row: Dictionary = (
			rows[firebolt_index] as Dictionary
			if firebolt_index < rows.size()
			else {}
		)
		_expect(
			str(repaired_row.get("spell_id", "")) == "firebolt",
			"quickbar stores the Focus-selected spell ID"
		)
		_expect(
			str(repaired_row.get("name", "")) == "Firebolt",
			"reassigned Focus spell remains selectable in the quickbar"
		)

	var surf: AbilityDefinition = _find_learned(loadout, "surf")
	_expect(surf != null, "Surf remains available as a learned Water spell")
	if surf != null:
		_expect(
			bool(caster.call("select_focus_spell_by_id", "surf")),
			"Focus can select Surf by learned spell ID"
		)
		_expect(
			bool(router.call("assign_selected_focus_spell_to_slot", 0)),
			"Surf can override quick slot one"
		)
		var water_names_after_assignment: Array = caster.call(
			"get_focus_spell_names_for_element",
			"water"
		) as Array
		_expect(
			water_names_after_assignment == original_water_names,
			"quickbar assignment does not reorder or remove Water Focus spells"
		)

	var focus_debug: Dictionary = caster.call("get_debug_data") as Dictionary
	var router_debug: Dictionary = router.call("get_debug_data") as Dictionary
	_expect(
		bool(focus_debug.get("focus_quickbar_independent", false)),
		"Focus reports learned-library authority"
	)
	_expect(
		not bool(router_debug.get("quickbar_mutates_focus_library", true)),
		"quickbar reports that it cannot mutate Focus contents"
	)

	_finish(player, floor, loadout)


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
	loadout.learned_abilities.clear()
	for ability: AbilityDefinition in original_learned:
		loadout.learned_abilities.append(ability)


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
	floor.name = "FocusQuickbarFloor"
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
	push_error("FOCUS_QUICKBAR_INDEPENDENCE_SMOKE_TEST: " + label)


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
	player: Node,
	floor: Node,
	loadout: AbilityLoadout
) -> void:
	Engine.time_scale = 1.0
	_restore_loadout(loadout)
	_restore_state()
	if is_instance_valid(player):
		player.queue_free()
	if is_instance_valid(floor):
		floor.queue_free()
	if failures.is_empty():
		print("FOCUS_QUICKBAR_INDEPENDENCE_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("FOCUS_QUICKBAR_INDEPENDENCE_SMOKE_TEST: " + failure)
	get_tree().quit(1)
