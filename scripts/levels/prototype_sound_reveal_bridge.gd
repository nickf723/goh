extends Node3D

@export var recommended_ability_name: String = "Sound Pulse"
@export var opening_objective: String = "Use Sound Pulse to reveal the path, then cross before it fades."
@export_multiline var opening_message: String = "The bridge is present, but ordinary sight cannot find it. Let sound draw its shape."


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	restore_prototype_resources()
	show_opening_guidance()
	call_deferred("select_recommended_ability")


func restore_prototype_resources() -> void:
	for resource_name: String in ["health", "stamina", "mana", "stance"]:
		var max_name: String = "max_" + resource_name

		if GameState.has_method("get_stat") and GameState.has_method("set_stat"):
			GameState.set_stat(resource_name, GameState.get_stat(max_name))


func show_opening_guidance() -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui == null:
		print(opening_message)
		return

	if ui.has_method("set_objective"):
		ui.set_objective(opening_objective)

	if ui.has_method("show_message"):
		ui.show_message(opening_message)


func select_recommended_ability() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")

	if player == null:
		return

	var ability_caster: Node = player.get_node_or_null("AbilityCaster")

	if ability_caster == null or not ability_caster.has_method("select_ability"):
		return

	var loadout: Resource = ability_caster.get("loadout") as Resource

	if loadout == null:
		return

	if not loadout.has_method("get_equipped_ability_count"):
		return

	if not loadout.has_method("get_equipped_ability"):
		return

	var ability_count: int = int(loadout.call("get_equipped_ability_count"))

	for ability_index: int in range(ability_count):
		var ability: Resource = loadout.call("get_equipped_ability", ability_index) as Resource

		if ability == null:
			continue

		if str(ability.get("display_name")).to_lower() != recommended_ability_name.to_lower():
			continue

		ability_caster.call("select_ability", ability_index, false)
		return
