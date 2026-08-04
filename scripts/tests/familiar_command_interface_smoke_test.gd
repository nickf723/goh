extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const AnimalFamiliarScene: PackedScene = preload(
	"res://scenes/tests/fixtures/summoned_bonded_sheep_familiar.tscn"
)

var failures: Array[String] = []
var original_time_scale: float = 1.0


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_time_scale = Engine.time_scale
	var floor := _make_floor()
	add_child(floor)
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "AbilityContextFamiliarTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	for _frame: int in range(7):
		await get_tree().process_frame
	await get_tree().physics_frame

	var manager: PlayerSummonManager = player.get_node_or_null(
		"SummonManager"
	) as PlayerSummonManager
	var router: Node = player.get_node_or_null("AbilityContextRouter")
	var menu: Node = player.get_node_or_null("AbilityContextMenu")
	var caster: Node = player.get_node_or_null("AbilityCaster")
	var hud: Node = player.get_node_or_null("PlayerHUDV2")
	var unified_hud: bool = (
		hud != null
		and hud.has_method("get_unified_hud_debug_data")
	)
	var action_state: PlayerActionState = player.get_node_or_null(
		"PlayerActionState"
	) as PlayerActionState
	_expect(manager != null, "player retains summon manager")
	_expect(router != null, "summon provider installs the global ability context router")
	_expect(menu != null, "global ability context router installs one shared context menu")
	_expect(caster != null, "player retains the shared ability caster")
	_expect(action_state != null, "global context can use the shared action lock")
	_expect(player.get_node_or_null("FamiliarCommandInterface") == null, "legacy L3 familiar interface is not installed")
	if manager == null or router == null or menu == null or caster == null or action_state == null:
		await _finish(player, floor, manager)
		return

	_expect(not bool(menu.call("is_interface_visible")), "context status is hidden before a persistent ability exists")
	if unified_hud:
		var initial_hud_data: Dictionary = hud.call(
			"get_unified_hud_debug_data"
		) as Dictionary
		_expect(
			int(initial_hud_data.get("active_ability_count", 0)) == 0,
			"unified support cluster begins without a familiar entry"
		)
	_expect(not InputMap.has_action(&"familiar_command_menu"), "global context does not create a dedicated L3 action")
	_expect(InputMap.has_action(&"cast_spell"), "global context reuses the authoritative cast action")

	var definition := SummonDefinition.new()
	definition.summon_id = "smoke_test_bonded_sheep"
	definition.species_id = "sheep"
	definition.display_name = "Juniper Familiar"
	definition.summon_scene = AnimalFamiliarScene
	definition.summon_offset = Vector3(1.8, 0.2, -1.3)
	definition.mana_cost = 0
	definition.unlock_id = ""
	manager.summon_definition = definition
	GameState.set_stat("mana", 99)

	var familiar_index: int = _find_ability_index(caster, "spectral_familiar")
	var fireball_index: int = _find_ability_index(caster, "firebolt")
	_expect(familiar_index >= 0, "Summon Familiar remains selectable on the spell belt")
	_expect(fireball_index >= 0, "Fireball remains selectable beside persistent abilities")
	if familiar_index < 0:
		await _finish(player, floor, manager)
		return

	caster.call("select_ability", familiar_index, false)
	var first_cast: bool = bool(caster.call("cast_from_player", player))
	_expect(first_cast, "first Cast on Summon Familiar creates the familiar")
	for _frame: int in range(4):
		await get_tree().process_frame
	await get_tree().physics_frame
	var familiar: Node3D = manager.get_active_summon()
	_expect(familiar is SummonedBondedAnimalFamiliar, "spell cast produces a bonded animal familiar")
	if unified_hud:
		var summoned_hud_data: Dictionary = hud.call(
			"get_unified_hud_debug_data"
		) as Dictionary
		_expect(
			int(summoned_hud_data.get("active_ability_count", 0)) >= 1,
			"unified support cluster appears after summoning"
		)
		_expect(
			not bool(menu.call("is_interface_visible")),
			"retired compact status card stays hidden under the unified shell"
		)
		var compact_panel: Control = menu.get("compact_panel") as Control
		_expect(
			compact_panel != null and not compact_panel.visible,
			"unified familiar state does not leave a duplicate compact panel"
		)
	else:
		_expect(bool(menu.call("is_interface_visible")), "persistent context status appears after summoning")
	_expect(not bool(menu.call("is_context_open")), "summoning does not immediately force the context menu open")

	if fireball_index >= 0:
		caster.call("select_ability", fireball_index, false)
		var fireball_ability: AbilityDefinition = caster.call("get_current_ability") as AbilityDefinition
		var fireball_context: Dictionary = router.call(
			"try_open_context",
			player,
			fireball_ability
		) as Dictionary
		_expect(not bool(fireball_context.get("handled", false)), "ordinary Fireball ignores the context router")
		_expect(not bool(menu.call("is_context_open")), "switching to Fireball does not open familiar controls")

	caster.call("select_ability", familiar_index, false)
	_open_with_cast_input(router)
	_expect(bool(menu.call("is_context_open")), "Cast opens the context when Summon Familiar is selected again")
	_expect(action_state.is_focus_menu_open, "open global context applies the shared action lock")
	_expect(Engine.time_scale <= 0.3501, "open global context slows the battlefield")
	var actions: Array[String] = _string_array(menu.call("get_available_action_ids"))
	_expect(actions.has("follow"), "familiar context exposes Follow")
	_expect(actions.has("stay"), "familiar context exposes Stay Here")
	_expect(actions.has("come_here"), "familiar context exposes Come Here")
	_expect(actions.has("move_to"), "familiar context exposes Go There")
	_expect(actions.has("dismiss"), "familiar context exposes Dismiss Familiar")
	_expect(not actions.has("assist"), "animal context omits unsupported combat actions")

	_expect(bool(menu.call("select_action_by_id", "stay")), "global selection resolves Stay")
	var commands_before: int = manager.total_commands
	var stay_committed: bool = bool(menu.call("commit_selected_action"))
	_expect(stay_committed, "Cast-style confirmation commits Stay")
	_expect(not bool(menu.call("is_context_open")), "context closes after a normal action")
	_expect(not action_state.is_focus_menu_open, "normal action restores ordinary player actions")
	_expect(is_equal_approx(Engine.time_scale, original_time_scale), "normal action restores world time")
	_expect(manager.total_commands == commands_before + 1, "one context confirmation issues exactly one command")
	var stay_state: Dictionary = manager.get_familiar_command_state()
	_expect(str(stay_state.get("command_id", "")) == "stay", "Stay reaches the authoritative animal command layer")
	if familiar is CharacterBody3D:
		var body := familiar as CharacterBody3D
		_expect(Vector2(body.velocity.x, body.velocity.z).length() < 0.05, "Stay immediately clears animal follow velocity")

	_open_with_cast_input(router)
	menu.call("select_action_by_id", "move_to")
	menu.call("commit_selected_action")
	_expect(bool(menu.call("is_targeting")), "Go There enters shared world targeting")
	var move_target := Vector3(5.0, 0.0, 4.0)
	_expect(bool(menu.call("confirm_world_target", move_target)), "Cast-style confirmation commits the aimed destination")
	_expect(not bool(menu.call("is_targeting")), "world targeting closes after confirmation")
	var move_state: Dictionary = manager.get_familiar_command_state()
	_expect(str(move_state.get("command_id", "")) == "move_to", "Go There reaches the authoritative destination command")
	var saved_destination: Vector3 = move_state.get("destination", Vector3.ZERO) as Vector3
	_expect(saved_destination.distance_to(move_target) < 0.05, "Go There preserves the confirmed world position")

	_open_with_cast_input(router)
	var command_before_cancel: String = str(manager.get_familiar_command_state().get("command_id", ""))
	_expect(bool(menu.call("cancel_context")), "B-style cancellation closes the global context")
	_expect(not bool(menu.call("is_context_open")), "cancelled global context is hidden")
	_expect(str(manager.get_familiar_command_state().get("command_id", "")) == command_before_cancel, "cancel does not mutate the active familiar command")

	_open_with_cast_input(router)
	_expect(bool(menu.call("select_action_by_id", "dismiss")), "Dismiss Familiar is selectable")
	_expect(bool(menu.call("commit_selected_action")), "Dismiss Familiar executes through the global layout")
	for _frame: int in range(2):
		await get_tree().process_frame
	_expect(manager.get_active_summon() == null, "Dismiss Familiar removes the active summon")
	if unified_hud:
		var dismissed_hud_data: Dictionary = hud.call(
			"get_unified_hud_debug_data"
		) as Dictionary
		_expect(
			int(dismissed_hud_data.get("active_ability_count", 0)) == 0,
			"unified support cluster removes the dismissed familiar entry"
		)
	_expect(not bool(menu.call("is_interface_visible")), "context status disappears after dismissal")
	_expect(not bool(menu.call("is_context_open")), "dismissal cannot leave an orphaned context menu")
	_expect(not bool(menu.call("is_targeting")), "dismissal cannot leave orphaned world targeting")

	await _finish(player, floor, manager)


func _open_with_cast_input(router: Node) -> void:
	var event := InputEventAction.new()
	event.action = &"cast_spell"
	event.pressed = true
	router.call("_input", event)


func _find_ability_index(caster: Node, spell_id: String) -> int:
	var loadout_value: Variant = caster.get("loadout")
	if not (loadout_value is AbilityLoadout):
		return -1
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
	for index: int in range(loadout.get_equipped_ability_count()):
		var ability: AbilityDefinition = loadout.get_equipped_ability(index)
		if ability != null and ability.get_spell_id() == spell_id:
			return index
	return -1


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			result.append(str(raw))
	return result


func _make_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "Floor"
	floor.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(30.0, 0.5, 30.0)
	collision.shape = shape
	collision.position.y = -0.25
	floor.add_child(collision)
	return floor


func _finish(
	player: Node,
	floor: Node,
	manager: PlayerSummonManager
) -> void:
	Engine.time_scale = original_time_scale
	if manager != null:
		var familiar: Node3D = manager.get_active_summon()
		if familiar is SummonedBondedAnimalFamiliar:
			(familiar as SummonedBondedAnimalFamiliar).clear_persistent_bond()
		manager.dismiss_summon(false)
	if player != null and is_instance_valid(player):
		player.queue_free()
	if floor != null and is_instance_valid(floor):
		floor.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("FAMILIAR_COMMAND_INTERFACE_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("FAMILIAR_COMMAND_INTERFACE_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
