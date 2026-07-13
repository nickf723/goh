extends Node3D
class_name PrototypeElementalReactionLab

const ComboRuleRegistryScript = preload("res://scripts/systems/combo_rule_registry.gd")
const LabLoadout: Resource = preload("res://data/loadouts/grace_reaction_lab_loadout.tres")

@export var opening_objective: String = "Trigger IGNITE, CONDUCT, FREEZE, SHATTER, STEAM, and REVEAL. Use the reset console whenever needed."
@export var opening_message: String = "Elemental Reaction Laboratory online. Five elements, six reactions, one extremely patient collection of gobbies."
@export var refill_resources_on_ready: bool = true
@export var enable_editor_f8_reset: bool = true

var reset_count: int = 0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("debuggable")
	configure_lab_loadout()

	if refill_resources_on_ready:
		refill_player_resources()

	set_objective(opening_objective)
	show_message(get_opening_message())


func _unhandled_input(event: InputEvent) -> void:
	if not enable_editor_f8_reset or not OS.has_feature("editor"):
		return

	if not (event is InputEventKey):
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if key_event.physical_keycode != KEY_F8:
		return

	get_viewport().set_input_as_handled()
	reset_lab()


func get_opening_message() -> String:
	if enable_editor_f8_reset and OS.has_feature("editor"):
		return opening_message + " Press F8 or use the violet console to reset every station."

	return opening_message


func configure_lab_loadout() -> void:
	var ability_caster: Node = get_node_or_null("Player/AbilityCaster")

	if ability_caster == null:
		return

	ability_caster.set("loadout", LabLoadout)
	ability_caster.set("current_ability_index", 0)

	if ability_caster.has_method("align_focus_menu_to_current_ability"):
		ability_caster.align_focus_menu_to_current_ability()

	if ability_caster.has_method("emit_current_ability"):
		ability_caster.emit_current_ability()


func refill_player_resources() -> void:
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	GameState.set_stat("focus", GameState.get_stat("max_focus"))


func reset_lab() -> void:
	reset_count += 1

	for node: Node in get_tree().get_nodes_in_group("lab_resettable"):
		if node == null or not is_instance_valid(node):
			continue

		if node.has_method("reset_target"):
			node.reset_target()
		elif node.has_method("reset_surface"):
			node.reset_surface()
		elif node.has_method("reset_reveal"):
			node.reset_reveal()

	for receiver: Node in get_tree().get_nodes_in_group("detectable"):
		if receiver != null and receiver.has_method("reset_reveal"):
			receiver.reset_reveal()

	var player: Node = get_node_or_null("Player")
	if player != null:
		var player_status_receiver: Node = player.get_node_or_null("StatusReceiver")
		if player_status_receiver != null and player_status_receiver.has_method("clear_all_statuses"):
			player_status_receiver.clear_all_statuses()

	refill_player_resources()
	configure_lab_loadout()
	set_objective(opening_objective)
	show_message("Laboratory reset #" + str(reset_count) + ". Every surface and target is back at baseline.")


func get_station_summary() -> Array[String]:
	var rows: Array[String] = []

	for node: Node in get_tree().get_nodes_in_group("lab_resettable"):
		if node == null or not is_instance_valid(node):
			continue

		if node.has_method("get_debug_data"):
			var data: Dictionary = node.get_debug_data()
			if data.has("surface"):
				rows.append(str(data["surface"]) + ":" + str(data.get("reaction_state", "normal")))
			elif data.has("lab_target"):
				rows.append(str(data["lab_target"]) + ":" + str(data.get("reaction", "none")))

	return rows


func get_debug_data() -> Dictionary:
	var matrix: Array[Dictionary] = ComboRuleRegistryScript.get_debug_matrix_rows()
	return {
		"lab": "elemental_reaction_v0_5",
		"rules": matrix.size(),
		"resets": reset_count,
		"stations": get_station_summary(),
	}


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)
	else:
		print(text)


func set_objective(text: String) -> void:
	GameState.set_objective(text)
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("set_objective"):
		ui.set_objective(text)
