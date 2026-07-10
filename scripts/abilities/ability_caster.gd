extends Node3D

signal ability_changed(ability_name: String, ability_index: int)

@export var loadout: AbilityLoadout
@export var current_ability_index: int = 0

@export var cast_spawn_height: float = 1.2
@export var cast_spawn_distance: float = 1.0

@onready var action_state: PlayerActionState = get_parent().get_node_or_null("PlayerActionState")

func _ready() -> void:
	if loadout == null:
		print("AbilityCaster has no loadout.")
		return

	if loadout.get_equipped_ability_count() <= 0:
		print("AbilityCaster loadout has no equipped abilities.")
		return

	current_ability_index = clamp(
		current_ability_index,
		0,
		loadout.get_equipped_ability_count() - 1
	)
	emit_current_ability()
	add_to_group("debuggable")
	#print_action_audit()

func cast_from_player(player: Node3D) -> void:
	var ability: AbilityDefinition = get_current_ability()
	if action_state != null and not action_state.can_cast():
		return
	if ability == null:
		print("No current ability.")
		return

	if ability.ability_scene == null:
		print("Ability has no scene: ", ability.display_name)
		return

	if not pay_ability_cost(ability):
		show_feedback("Not enough resources for " + ability.display_name + ".")
		return
		
	if action_state != null:
		action_state.begin_cast(0.18)
		
	var ability_instance: Node = ability.ability_scene.instantiate()

	var action_payload: Resource = null

	if ability.has_method("get_action_payload"):
		action_payload = ability.get_action_payload()
	elif ability.payload != null:
		action_payload = ability.payload

	if action_payload != null and ability_instance.has_method("set_payload"):
		ability_instance.set_payload(action_payload)

	if ability_instance.has_method("set_source_actor"):
		ability_instance.set_source_actor(player)
		
	var camera: Camera3D = get_viewport().get_camera_3d()
	var cast_direction: Vector3 = -player.global_transform.basis.z

	if camera != null:
		cast_direction = -camera.global_transform.basis.z

	get_tree().current_scene.add_child(ability_instance)

	if ability_instance.has_method("execute"):
		ability_instance.execute(player, cast_direction)
		return

	ability_instance.global_position = (
		player.global_position
		+ Vector3.UP * cast_spawn_height
		+ cast_direction * cast_spawn_distance
	)

	if ability_instance.has_method("launch"):
		ability_instance.launch(cast_direction)

func pay_ability_cost(ability: AbilityDefinition) -> bool:
	if GameState.get_stat("mana") < ability.mana_cost:
		return false

	if GameState.get_stat("stamina") < ability.stamina_cost:
		return false

	if GameState.get_stat("focus") < ability.focus_cost:
		return false

	if ability.mana_cost > 0:
		GameState.set_stat("mana", GameState.get_stat("mana") - ability.mana_cost)

	if ability.stamina_cost > 0:
		GameState.set_stat("stamina", GameState.get_stat("stamina") - ability.stamina_cost)

	if ability.focus_cost > 0:
		GameState.set_stat("focus", GameState.get_stat("focus") - ability.focus_cost)

	return true

func select_ability(index: int) -> void:
	if loadout == null:
		return

	if index < 0 or index >= loadout.get_equipped_ability_count():
		return

	current_ability_index = index
	emit_current_ability()
	show_feedback("Equipped: " + get_current_ability_name())

func select_next_ability() -> void:
	if loadout == null:
		return

	var ability_count: int = loadout.get_equipped_ability_count()

	if ability_count <= 0:
		return

	current_ability_index += 1

	if current_ability_index >= ability_count:
		current_ability_index = 0

	emit_current_ability()
	show_feedback("Equipped: " + get_current_ability_name())

func get_current_ability() -> AbilityDefinition:
	if loadout == null:
		return null

	return loadout.get_equipped_ability(current_ability_index)

func get_current_ability_name() -> String:
	var ability: AbilityDefinition = get_current_ability()

	if ability == null:
		return "Empty Slot"

	return ability.display_name

func emit_current_ability() -> void:
	ability_changed.emit(get_current_ability_name(), current_ability_index)

	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui == null:
		return

	if ui.has_method("set_spell_label"):
		ui.set_spell_label(get_current_ability_name())

	if ui.has_method("update_spell_menu") and loadout != null:
		ui.update_spell_menu(loadout.get_equipped_ability_names(), current_ability_index)

func show_feedback(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui == null:
		print(text)
		return

	if ui.has_method("show_message"):
		ui.show_message(text)

func get_debug_data() -> Dictionary:
	var ability: AbilityDefinition = get_current_ability()

	var ability_name: String = "None"
	var element: String = "none"
	var mana_cost: int = 0

	if ability != null:
		ability_name = ability.display_name
		element = ability.element
		mana_cost = ability.mana_cost

	return {
		"type": "AbilityCaster",
		"current_ability": ability_name,
		"element": element,
		"mana_cost": mana_cost,
		"slot_index": current_ability_index,
	}

func print_action_audit() -> void:
	if loadout == null:
		print("Action audit: no loadout.")
		return

	print("\n=== ACTION LOADOUT AUDIT ===")

	for i in range(loadout.equipped_abilities.size()):
		var ability: AbilityDefinition = loadout.equipped_abilities[i]

		if ability == null:
			print("Slot ", i + 1, ": Empty")
			continue

		print("Slot ", i + 1, ": ", ability.display_name)
		print("  Element: ", ability.element)
		print("  Category: ", AbilityDefinition.AbilityCategory.keys()[ability.category])
		print("  Scene: ", get_scene_path_text(ability.ability_scene))
		print("  Action Payload: ", describe_action_payload(ability.get_action_payload()))

		if ability.payload != null and ability.action_payload == null:
			print("  Warning: using legacy DamagePayload field.")

	print("===========================\n")

func get_scene_path_text(scene: PackedScene) -> String:
	if scene == null:
		return "none"

	var path: String = scene.resource_path

	if path == "":
		return str(scene)

	return path

func describe_action_payload(action_payload: Resource) -> String:
	if action_payload == null:
		return "none"

	if action_payload is DamagePayload:
		var damage_payload: DamagePayload = action_payload as DamagePayload

		return (
			damage_payload.source_name
			+ " | DamagePayload"
			+ " | element=" + damage_payload.element
			+ " | tags=" + str(damage_payload.tags)
		)

	if action_payload is DetectionPayload:
		var detection_payload: DetectionPayload = action_payload as DetectionPayload

		return (
			detection_payload.source_name
			+ " | DetectionPayload"
			+ " | type=" + detection_payload.detection_type
			+ " | radius=" + str(detection_payload.radius)
			+ " | tags=" + str(detection_payload.tags)
		)

	return action_payload.resource_path + " | " + action_payload.get_class()
