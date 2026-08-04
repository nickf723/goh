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
	player.name = "FamiliarCommandInterfaceTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	for _frame: int in range(5):
		await get_tree().process_frame
	await get_tree().physics_frame

	var manager: PlayerSummonManager = player.get_node_or_null(
		"SummonManager"
	) as PlayerSummonManager
	var interface: Node = player.get_node_or_null("FamiliarCommandInterface")
	var action_state: PlayerActionState = player.get_node_or_null(
		"PlayerActionState"
	) as PlayerActionState
	_expect(manager != null, "player retains summon manager")
	_expect(interface != null, "summon manager installs the familiar command interface")
	_expect(action_state != null, "command interface can use the shared action lock")
	if manager == null or interface == null or action_state == null:
		await _finish(player, floor, manager)
		return

	_expect(not bool(interface.call("is_interface_visible")), "familiar UI is hidden before a summon exists")
	_validate_controller_bindings()

	var definition := SummonDefinition.new()
	definition.summon_id = "smoke_test_bonded_sheep"
	definition.species_id = "sheep"
	definition.display_name = "Juniper Familiar"
	definition.summon_scene = AnimalFamiliarScene
	definition.summon_offset = Vector3(1.8, 0.2, -1.3)
	definition.mana_cost = 0
	definition.unlock_id = ""
	var summoned: bool = manager.summon_familiar(definition)
	_expect(summoned, "Summon Familiar accepts the bonded-animal summon adapter")
	for _frame: int in range(4):
		await get_tree().process_frame
	await get_tree().physics_frame
	var familiar: Node3D = manager.get_active_summon()
	_expect(familiar is SummonedBondedAnimalFamiliar, "spell summon produces a bonded animal familiar")
	_expect(bool(interface.call("is_interface_visible")), "familiar UI appears only after the spell creates a familiar")
	var commands: Array[String] = _string_array(interface.call("get_available_commands"))
	_expect(commands.has("follow"), "animal command wheel exposes Follow")
	_expect(commands.has("stay"), "animal command wheel exposes Stay Here")
	_expect(commands.has("come_here"), "animal command wheel exposes Come Here")
	_expect(commands.has("move_to"), "animal command wheel exposes Go There")
	_expect(not commands.has("assist"), "animal command wheel omits unsupported combat commands")

	var opened: bool = bool(interface.call("handle_menu_button", true, 0))
	_expect(opened and bool(interface.call("is_menu_open")), "L3-style press opens the familiar command wheel")
	_expect(action_state.is_focus_menu_open, "open familiar wheel applies the shared menu action lock")
	_expect(Engine.time_scale <= 0.3501, "open familiar wheel slows the battlefield")
	_expect(bool(interface.call("select_command_by_id", "stay")), "right-stick selection can resolve Stay")
	var commands_before: int = manager.total_commands
	var released: bool = bool(interface.call("handle_menu_button", false, 0))
	_expect(released, "releasing the command button commits the selected command")
	_expect(not bool(interface.call("is_menu_open")), "command wheel closes after release")
	_expect(not action_state.is_focus_menu_open, "command release restores ordinary player actions")
	_expect(is_equal_approx(Engine.time_scale, original_time_scale), "command release restores world time")
	_expect(manager.total_commands == commands_before + 1, "one controller release issues exactly one command")
	var stay_state: Dictionary = manager.get_familiar_command_state()
	_expect(str(stay_state.get("command_id", "")) == "stay", "Stay reaches the authoritative animal command layer")
	if familiar is CharacterBody3D:
		var body := familiar as CharacterBody3D
		_expect(Vector2(body.velocity.x, body.velocity.z).length() < 0.05, "Stay immediately clears animal follow velocity")

	interface.call("handle_menu_button", true, 0)
	interface.call("select_command_by_id", "move_to")
	interface.call("handle_menu_button", false, 0)
	_expect(bool(interface.call("is_targeting")), "Go There enters aimed world targeting after radial release")
	var move_target := Vector3(5.0, 0.0, 4.0)
	_expect(bool(interface.call("confirm_move_to_target", move_target)), "A-style confirmation commits the aimed destination")
	_expect(not bool(interface.call("is_targeting")), "Go There targeting closes after confirmation")
	var move_state: Dictionary = manager.get_familiar_command_state()
	_expect(str(move_state.get("command_id", "")) == "move_to", "Go There reaches the authoritative destination command")
	var saved_destination: Vector3 = move_state.get("destination", Vector3.ZERO) as Vector3
	_expect(saved_destination.distance_to(move_target) < 0.05, "Go There preserves the confirmed world position")

	interface.call("handle_menu_button", true, 0)
	var command_before_cancel: String = str(manager.get_familiar_command_state().get("command_id", ""))
	_expect(bool(interface.call("cancel_interface", "controller_b_cancel")), "B-style cancellation closes the familiar wheel")
	_expect(not bool(interface.call("is_menu_open")), "cancelled familiar wheel is hidden")
	_expect(str(manager.get_familiar_command_state().get("command_id", "")) == command_before_cancel, "cancel does not mutate the active familiar command")

	if familiar is SummonedBondedAnimalFamiliar:
		(familiar as SummonedBondedAnimalFamiliar).clear_persistent_bond()
	manager.dismiss_summon(false)
	await get_tree().process_frame
	_expect(not bool(interface.call("is_interface_visible")), "familiar UI disappears when the summon is dismissed")
	_expect(not bool(interface.call("is_menu_open")), "dismissal cannot leave an orphaned command wheel")
	_expect(not bool(interface.call("is_targeting")), "dismissal cannot leave orphaned Go There targeting")

	await _finish(player, floor, manager)


func _validate_controller_bindings() -> void:
	_expect(_action_has_button(&"familiar_command_menu", JOY_BUTTON_LEFT_STICK), "L3 opens familiar commands")
	_expect(_action_has_button(&"familiar_command_confirm", JOY_BUTTON_A), "A confirms Go There targeting")
	_expect(_action_has_button(&"familiar_command_cancel", JOY_BUTTON_B), "B cancels familiar command surfaces")
	_expect(InputMap.has_action(&"camera_left") and InputMap.has_action(&"camera_right"), "right-stick camera actions remain available for radial selection")


func _action_has_button(action_name: StringName, button_index: int) -> bool:
	if not InputMap.has_action(action_name):
		return false
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button_index:
			return true
	return false


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
