extends Node3D

signal ability_changed(ability_name: String, ability_index: int)

const ELEMENT_ORDER: Array[String] = [
	"water",
	"earth",
	"fire",
	"air",
	"ice",
	"metal",
	"lightning",
	"poison",
	"life",
	"death",
	"body",
	"soul",
	"dreams",
	"sound",
	"space",
	"time",
]

const ELEMENT_GROUPS: Array[Dictionary] = [
	{
		"name": "Natural",
		"elements": ["water", "earth", "fire", "air"],
	},
	{
		"name": "Primal",
		"elements": ["ice", "metal", "lightning", "poison"],
	},
	{
		"name": "Vital",
		"elements": ["life", "death", "body", "soul"],
	},
	{
		"name": "Mystical",
		"elements": ["dreams", "sound", "space", "time"],
	},
]

const ELEMENT_DISPLAY_NAMES: Dictionary = {
	"water": "Water",
	"earth": "Earth",
	"fire": "Fire",
	"air": "Air",
	"ice": "Ice",
	"metal": "Metal",
	"lightning": "Lightning",
	"poison": "Poison",
	"life": "Life",
	"death": "Death",
	"body": "Body",
	"soul": "Soul",
	"dreams": "Dreams",
	"sound": "Sound",
	"space": "Space",
	"time": "Time",
}

@export var loadout: AbilityLoadout
@export var current_ability_index: int = 0

@export var cast_spawn_height: float = 1.2
@export var cast_spawn_distance: float = 1.0

var focus_spell_menu_open: bool = false
var focus_element_index: int = 2
var focus_spell_index: int = 0

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
	align_focus_menu_to_current_ability()
	add_to_group("debuggable")
	emit_current_ability()
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
	align_focus_menu_to_current_ability()
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

	align_focus_menu_to_current_ability()
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

	if focus_spell_menu_open and ui.has_method("show_spell_focus_menu"):
		ui.show_spell_focus_menu(get_focus_menu_data())


func open_focus_spell_menu() -> void:
	if focus_spell_menu_open:
		update_focus_spell_menu_ui()
		return

	focus_spell_menu_open = true
	align_focus_menu_to_current_ability()
	update_focus_spell_menu_ui()


func close_focus_spell_menu() -> void:
	if not focus_spell_menu_open:
		return

	focus_spell_menu_open = false

	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("hide_spell_focus_menu"):
		ui.hide_spell_focus_menu()
	elif ui != null and ui.has_method("hide_spell_menu"):
		ui.hide_spell_menu()


func is_focus_spell_menu_open() -> bool:
	return focus_spell_menu_open


func handle_focus_menu_input(event: InputEvent) -> bool:
	if not focus_spell_menu_open:
		return false

	if event.is_action_pressed("cast_spell"):
		confirm_focus_spell_menu()
		return true

	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey

		if not key_event.pressed or key_event.echo:
			return true

		match key_event.keycode:
			KEY_LEFT:
				cycle_focus_element(-1)
				return true
			KEY_RIGHT:
				cycle_focus_element(1)
				return true
			KEY_UP:
				cycle_focus_spell(-1)
				return true
			KEY_DOWN:
				cycle_focus_spell(1)
				return true
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				confirm_focus_spell_menu()
				return true
			_:
				return true

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton

		if not mouse_event.pressed:
			return true

		match mouse_event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				cycle_focus_spell(-1)
				return true
			MOUSE_BUTTON_WHEEL_DOWN:
				cycle_focus_spell(1)
				return true
			MOUSE_BUTTON_LEFT:
				confirm_focus_spell_menu()
				return true
			_:
				return true

	return true


func cycle_focus_element(direction: int) -> void:
	if ELEMENT_ORDER.size() <= 0:
		return

	focus_element_index = (focus_element_index + direction + ELEMENT_ORDER.size()) % ELEMENT_ORDER.size()
	focus_spell_index = 0
	update_focus_spell_menu_ui()


func cycle_focus_spell(direction: int) -> void:
	var spell_indices: Array[int] = get_spell_indices_for_element(get_selected_focus_element())

	if spell_indices.size() <= 0:
		focus_spell_index = 0
		update_focus_spell_menu_ui()
		return

	focus_spell_index = (focus_spell_index + direction + spell_indices.size()) % spell_indices.size()
	update_focus_spell_menu_ui()


func confirm_focus_spell_menu() -> void:
	var selected_index: int = get_selected_focus_spell_global_index()

	if selected_index < 0:
		show_feedback("No learned " + get_selected_focus_element_display_name() + " spells yet.")
		update_focus_spell_menu_ui()
		return

	select_ability(selected_index)
	update_focus_spell_menu_ui()


func update_focus_spell_menu_ui() -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui == null:
		return

	if ui.has_method("show_spell_focus_menu"):
		ui.show_spell_focus_menu(get_focus_menu_data())
	elif ui.has_method("show_spell_menu"):
		ui.show_spell_menu()


func align_focus_menu_to_current_ability() -> void:
	var ability: AbilityDefinition = get_current_ability()

	if ability == null:
		return

	var element_index: int = get_element_index(ability.element)

	if element_index < 0:
		return

	focus_element_index = element_index

	var spell_indices: Array[int] = get_spell_indices_for_element(ability.element)
	var local_spell_index: int = spell_indices.find(current_ability_index)

	if local_spell_index >= 0:
		focus_spell_index = local_spell_index
	else:
		focus_spell_index = 0


func get_element_index(element: String) -> int:
	for i: int in range(ELEMENT_ORDER.size()):
		if ELEMENT_ORDER[i] == element:
			return i

	return -1


func get_selected_focus_element() -> String:
	if ELEMENT_ORDER.size() <= 0:
		return "fire"

	focus_element_index = clamp(focus_element_index, 0, ELEMENT_ORDER.size() - 1)
	return ELEMENT_ORDER[focus_element_index]


func get_selected_focus_element_display_name() -> String:
	return get_element_display_name(get_selected_focus_element())


func get_element_display_name(element: String) -> String:
	if ELEMENT_DISPLAY_NAMES.has(element):
		return str(ELEMENT_DISPLAY_NAMES[element])

	return element.capitalize()


func get_spell_indices_for_element(element: String) -> Array[int]:
	var indices: Array[int] = []

	if loadout == null:
		return indices

	for i: int in range(loadout.equipped_abilities.size()):
		var ability: AbilityDefinition = loadout.equipped_abilities[i]

		if ability == null:
			continue

		if ability.element == element:
			indices.append(i)

	return indices


func get_selected_focus_spell_global_index() -> int:
	var spell_indices: Array[int] = get_spell_indices_for_element(get_selected_focus_element())

	if spell_indices.size() <= 0:
		return -1

	focus_spell_index = clamp(focus_spell_index, 0, spell_indices.size() - 1)
	return spell_indices[focus_spell_index]


func get_focus_spell_names_for_element(element: String) -> Array[String]:
	var names: Array[String] = []
	var spell_indices: Array[int] = get_spell_indices_for_element(element)

	for spell_index: int in spell_indices:
		var ability: AbilityDefinition = loadout.equipped_abilities[spell_index]

		if ability != null:
			names.append(ability.display_name)

	return names


func get_focus_menu_data() -> Dictionary:
	var selected_element: String = get_selected_focus_element()
	var selected_spell_global_index: int = get_selected_focus_spell_global_index()
	var selected_spell_name: String = "None"

	if selected_spell_global_index >= 0:
		var selected_ability: AbilityDefinition = loadout.equipped_abilities[selected_spell_global_index]

		if selected_ability != null:
			selected_spell_name = selected_ability.display_name

	return {
		"groups": ELEMENT_GROUPS,
		"element_order": ELEMENT_ORDER,
		"selected_element": selected_element,
		"selected_element_name": get_element_display_name(selected_element),
		"selected_spell_index": focus_spell_index,
		"selected_spell_name": selected_spell_name,
		"spell_names": get_focus_spell_names_for_element(selected_element),
		"current_ability_name": get_current_ability_name(),
		"current_ability_index": current_ability_index,
	}


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
		"menu": focus_spell_menu_open,
		"menu_element": get_selected_focus_element(),
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
