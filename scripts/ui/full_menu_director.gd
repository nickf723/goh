extends Node

const FullMenuShellScript = preload("res://scripts/ui/full_menu_shell.gd")

var full_menu_shell: FullMenuShell
var was_paused_before_menu: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_full_menu_input_map()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("full_menu"):
		toggle_full_menu()
		get_viewport().set_input_as_handled()
		return

	if is_full_menu_open():
		if event.is_action_pressed("ui_cancel"):
			close_full_menu()
		else:
			ensure_full_menu_shell()

			if full_menu_shell != null:
				full_menu_shell.handle_menu_input(event)

		get_viewport().set_input_as_handled()
		return


func toggle_full_menu() -> void:
	if is_full_menu_open():
		close_full_menu()
	else:
		open_full_menu()


func open_full_menu() -> void:
	ensure_full_menu_shell()

	if full_menu_shell == null:
		print("FullMenuDirector: no shell available.")
		return

	was_paused_before_menu = get_tree().paused
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	full_menu_shell.show_menu(build_menu_data())


func close_full_menu() -> void:
	if full_menu_shell != null:
		full_menu_shell.hide_menu()

	get_tree().paused = was_paused_before_menu
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func is_full_menu_open() -> bool:
	return full_menu_shell != null and full_menu_shell.is_open()


func ensure_full_menu_shell() -> void:
	if full_menu_shell != null and is_instance_valid(full_menu_shell):
		return

	var game_ui: Node = get_tree().get_first_node_in_group("game_ui")

	if game_ui == null:
		return

	var existing_shell: Node = game_ui.get_node_or_null("FullMenuShell")

	if existing_shell is FullMenuShell:
		full_menu_shell = existing_shell as FullMenuShell
		return

	full_menu_shell = FullMenuShellScript.new()
	full_menu_shell.name = "FullMenuShell"
	full_menu_shell.process_mode = Node.PROCESS_MODE_ALWAYS
	game_ui.add_child(full_menu_shell)


func ensure_full_menu_input_map() -> void:
	ensure_input_action("full_menu")

	if not input_action_has_key("full_menu", KEY_TAB):
		var tab_event: InputEventKey = InputEventKey.new()
		tab_event.physical_keycode = KEY_TAB
		InputMap.action_add_event("full_menu", tab_event)

	if not input_action_has_key("full_menu", KEY_M):
		var m_event: InputEventKey = InputEventKey.new()
		m_event.physical_keycode = KEY_M
		InputMap.action_add_event("full_menu", m_event)

	# Common controller start/menu button in Godot's standard mapping.
	if not input_action_has_joy_button("full_menu", 6):
		var joy_event: InputEventJoypadButton = InputEventJoypadButton.new()
		joy_event.button_index = 6
		InputMap.action_add_event("full_menu", joy_event)


func ensure_input_action(action_name: String) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.2)


func input_action_has_key(action_name: String, physical_keycode: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			if key_event.physical_keycode == physical_keycode:
				return true

	return false


func input_action_has_joy_button(action_name: String, button_index: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton:
			var joy_event: InputEventJoypadButton = event as InputEventJoypadButton
			if joy_event.button_index == button_index:
				return true

	return false


func build_menu_data() -> Dictionary:
	return {
		"objective": get_current_objective_text(),
		"stats": get_stat_rows(),
		"stat_sections": get_stat_sections(),
		"spells": get_spell_rows(),
		"weapon": get_weapon_data(),
	}


func get_current_objective_text() -> String:
	var game_ui: Node = get_tree().get_first_node_in_group("game_ui")

	if game_ui == null:
		return "Look around."

	var objective_label: Label = game_ui.get_node_or_null("ObjectiveLabel") as Label

	if objective_label == null:
		return "Look around."

	var text: String = objective_label.text
	var prefix: String = "Objective: "

	if text.begins_with(prefix):
		return text.substr(prefix.length())

	return text


func get_stat_rows() -> Dictionary:
	return {
		"health": str(GameState.get_stat("health")) + " / " + str(GameState.get_stat("max_health")),
		"stamina": str(GameState.get_stat("stamina")) + " / " + str(GameState.get_stat("max_stamina")),
		"mana": str(GameState.get_stat("mana")) + " / " + str(GameState.get_stat("max_mana")),
		"stance": str(GameState.get_stat("stance")) + " / " + str(GameState.get_stat("max_stance")),
	}


func get_stat_sections() -> Array[Dictionary]:
	if GameState.has_method("get_stat_menu_sections"):
		return GameState.get_stat_menu_sections()

	return []


func get_spell_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var ability_caster: Node = find_first_node_named(get_tree().current_scene, "AbilityCaster")

	if ability_caster == null:
		return rows

	var current_index: int = int(ability_caster.get("current_ability_index"))
	var loadout_variant: Variant = ability_caster.get("loadout")

	if not (loadout_variant is AbilityLoadout):
		return rows

	var loadout: AbilityLoadout = loadout_variant as AbilityLoadout

	for i: int in range(loadout.equipped_abilities.size()):
		var ability: AbilityDefinition = loadout.equipped_abilities[i]
		rows.append(make_spell_row(ability, i, current_index))

	return rows


func make_spell_row(ability: AbilityDefinition, slot_index: int, current_index: int) -> Dictionary:
	if ability == null:
		return {
			"slot": slot_index,
			"name": "Empty Slot",
			"is_current": slot_index == current_index,
		}

	return {
		"slot": slot_index,
		"name": ability.display_name,
		"description": ability.description,
		"element": ability.element,
		"category": get_ability_category_name(ability),
		"mana_cost": ability.mana_cost,
		"stamina_cost": ability.stamina_cost,
		"focus_cost": ability.focus_cost,
		"profile": ability.get_trait_profile_id() if ability.has_method("get_trait_profile_id") else "none",
		"roles": ability.get_roles() if ability.has_method("get_roles") else ability.roles,
		"targeting": ability.get_targeting_style() if ability.has_method("get_targeting_style") else ability.targeting_style,
		"delivery": ability.get_delivery_type() if ability.has_method("get_delivery_type") else ability.delivery_type,
		"combo_tags": ability.get_combo_tags() if ability.has_method("get_combo_tags") else ability.combo_tags,
		"status_tags": ability.get_status_tags() if ability.has_method("get_status_tags") else ability.status_tags,
		"ui_tags": ability.get_ui_tags() if ability.has_method("get_ui_tags") else ability.ui_tags,
		"scaling_stats": ability.get_scaling_stats() if ability.has_method("get_scaling_stats") else [],
		"scaling_note": ability.get_scaling_note() if ability.has_method("get_scaling_note") else "",
		"notes": ability.get_design_notes() if ability.has_method("get_design_notes") else ability.design_notes,
		"is_current": slot_index == current_index,
	}


func get_ability_category_name(ability: AbilityDefinition) -> String:
	var keys: Array = AbilityDefinition.AbilityCategory.keys()

	if ability.category < 0 or ability.category >= keys.size():
		return "unknown"

	return str(keys[ability.category]).to_lower()


func get_weapon_data() -> Dictionary:
	var weapon_controller: Node = find_first_node_named(get_tree().current_scene, "WeaponController")

	if weapon_controller == null:
		return {}

	var weapon_variant: Variant = weapon_controller.get("equipped_weapon")

	if not (weapon_variant is WeaponDefinition):
		return {}

	var weapon: WeaponDefinition = weapon_variant as WeaponDefinition

	return {
		"name": weapon.display_name,
		"class": weapon.weapon_class,
		"description": weapon.description,
		"damage": weapon.damage,
		"stance_damage": weapon.stance_damage,
		"range": weapon.range,
		"cooldown": weapon.cooldown,
		"stamina_cost": weapon.stamina_cost,
		"scaling_stats": weapon.get_scaling_stats() if weapon.has_method("get_scaling_stats") else [],
		"scaling_note": weapon.get_scaling_note() if weapon.has_method("get_scaling_note") else "",
	}


func find_first_node_named(root: Node, node_name: String) -> Node:
	if root == null:
		return null

	if root.name == node_name:
		return root

	for child: Node in root.get_children():
		var found: Node = find_first_node_named(child, node_name)

		if found != null:
			return found

	return null
