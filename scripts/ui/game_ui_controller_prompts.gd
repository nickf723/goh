extends "res://scripts/ui/game_ui.gd"

const INPUT_MODE_KEYBOARD: String = "keyboard"
const INPUT_MODE_CONTROLLER: String = "controller"

var last_input_mode: String = INPUT_MODE_KEYBOARD
var current_prompt_text: String = ""
var prompt_is_visible: bool = false
var input_mode_label: Label

var focus_element_signature: Array[String] = []
var focus_cached_element_ids: Array[String] = []
var focus_cached_element_tiles: Array[PanelContainer] = []
var focus_cached_element_labels: Array[Label] = []
var focus_spell_signature: Array[String] = []
var focus_cached_spell_rows: Array[PanelContainer] = []
var focus_cached_spell_labels: Array[Label] = []
var focus_style_cache: Dictionary = {}
var focus_structure_rebuilds: int = 0
var focus_visual_updates: int = 0


func _ready() -> void:
	super._ready()
	ensure_input_mode_label()
	update_input_mode_label()
	_upgrade_focus_presentation()
	update_focus_help_copy()


func _input(event: InputEvent) -> void:
	var detected_mode: String = detect_input_mode(event)
	if detected_mode == "":
		return
	set_input_mode(detected_mode)


func show_prompt(text: String) -> void:
	current_prompt_text = text
	prompt_is_visible = true
	prompt_label.text = get_interact_prompt_prefix() + text
	prompt_label.visible = true


func hide_prompt() -> void:
	prompt_is_visible = false
	current_prompt_text = ""
	prompt_label.visible = false


func show_spell_focus_menu(menu_data: Dictionary) -> void:
	super.show_spell_focus_menu(menu_data)
	_refresh_focus_detail_copy(menu_data)
	update_focus_help_copy()


func rebuild_element_tiles(groups: Array, selected_element: String) -> void:
	if focus_spell_element_grid == null:
		return
	var next_signature: Array[String] = []
	for group_variant: Variant in groups:
		if not group_variant is Dictionary:
			continue
		var group: Dictionary = group_variant as Dictionary
		next_signature.append("#" + str(group.get("name", "Group")))
		for element_variant: Variant in group.get("elements", []) as Array:
			next_signature.append(str(element_variant))

	if next_signature != focus_element_signature:
		focus_element_signature = next_signature.duplicate()
		focus_structure_rebuilds += 1
		clear_children(focus_spell_element_grid)
		focus_spell_element_tiles.clear()
		focus_cached_element_ids.clear()
		focus_cached_element_tiles.clear()
		focus_cached_element_labels.clear()
		focus_spell_element_grid.columns = 5
		for group_variant: Variant in groups:
			if not group_variant is Dictionary:
				continue
			var group: Dictionary = group_variant as Dictionary
			focus_spell_element_grid.add_child(
				_make_focus_group_label(str(group.get("name", "Group")))
			)
			for element_variant: Variant in group.get("elements", []) as Array:
				var element: String = str(element_variant)
				var tile_data: Dictionary = _make_cached_element_tile(element)
				var tile: PanelContainer = tile_data.get("tile") as PanelContainer
				var label: Label = tile_data.get("label") as Label
				focus_spell_element_grid.add_child(tile)
				focus_cached_element_ids.append(element)
				focus_cached_element_tiles.append(tile)
				focus_cached_element_labels.append(label)
				focus_spell_element_tiles[element] = tile

	for index: int in range(focus_cached_element_ids.size()):
		var element: String = focus_cached_element_ids[index]
		var selected: bool = element == selected_element
		var tile: PanelContainer = focus_cached_element_tiles[index]
		var label: Label = focus_cached_element_labels[index]
		tile.add_theme_stylebox_override(
			"panel",
			_get_element_tile_style(element, selected)
		)
		tile.modulate = Color(1.0, 1.0, 1.0, 1.0 if selected else 0.76)
		label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.94, 0.78, 1.0) if selected else TEXT_MAIN
		)


func rebuild_spell_rows(
	spell_names: Array,
	selected_spell_index: int,
	selected_element: String
) -> void:
	if focus_spell_list == null:
		return
	var next_signature: Array[String] = []
	for spell_variant: Variant in spell_names:
		next_signature.append(str(spell_variant))

	if next_signature != focus_spell_signature:
		focus_spell_signature = next_signature.duplicate()
		focus_structure_rebuilds += 1
		clear_children(focus_spell_list)
		focus_cached_spell_rows.clear()
		focus_cached_spell_labels.clear()
		if next_signature.is_empty():
			var empty_data: Dictionary = _make_cached_spell_row("No learned spells")
			focus_spell_list.add_child(empty_data.get("row") as PanelContainer)
			focus_cached_spell_rows.append(empty_data.get("row") as PanelContainer)
			focus_cached_spell_labels.append(empty_data.get("label") as Label)
		else:
			for spell_name: String in next_signature:
				var row_data: Dictionary = _make_cached_spell_row(spell_name)
				focus_spell_list.add_child(row_data.get("row") as PanelContainer)
				focus_cached_spell_rows.append(row_data.get("row") as PanelContainer)
				focus_cached_spell_labels.append(row_data.get("label") as Label)

	var element_color: Color = get_element_color(selected_element)
	if next_signature.is_empty():
		focus_cached_spell_rows[0].add_theme_stylebox_override(
			"panel",
			_get_focus_style(
				"spell_empty",
				Color(0.018, 0.026, 0.042, 0.86),
				Color(0.18, 0.25, 0.38, 0.5),
				1,
				9
			)
		)
		focus_cached_spell_labels[0].text = "No learned spells in this element"
		focus_cached_spell_labels[0].add_theme_color_override("font_color", TEXT_SOFT)
		return

	for index: int in range(next_signature.size()):
		var selected: bool = index == selected_spell_index
		var row: PanelContainer = focus_cached_spell_rows[index]
		var label: Label = focus_cached_spell_labels[index]
		row.add_theme_stylebox_override(
			"panel",
			_get_spell_row_style(selected_element, element_color, selected)
		)
		row.modulate = Color(1.0, 1.0, 1.0, 1.0 if selected else 0.78)
		var slots: String = _get_quick_slots_for_spell_name(next_signature[index])
		label.text = (
			("◆  " if selected else "·  ")
			+ next_signature[index]
			+ ("    [" + slots + "]" if slots != "" else "")
		)
		label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.93, 0.74, 1.0) if selected else TEXT_MAIN
		)


func _upgrade_focus_presentation() -> void:
	ensure_focus_spell_selector_ui()
	if focus_spell_panel != null:
		focus_spell_panel.add_theme_stylebox_override(
			"panel",
			_get_focus_style(
				"focus_outer",
				Color(0.009, 0.015, 0.027, 0.975),
				Color(0.36, 0.54, 0.84, 0.78),
				2,
				16
			)
		)
	if focus_spell_title_label != null:
		focus_spell_title_label.text = "SPELL LIBRARY"
		focus_spell_title_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.74, 0.28, 1.0)
		)
		focus_spell_title_label.add_theme_font_size_override("font_size", 17)
	if focus_spell_element_grid != null:
		focus_spell_element_grid.columns = 5
		focus_spell_element_grid.add_theme_constant_override("h_separation", 4)
		focus_spell_element_grid.add_theme_constant_override("v_separation", 5)


func _refresh_focus_detail_copy(menu_data: Dictionary) -> void:
	focus_visual_updates += 1
	var selected_element: String = str(menu_data.get("selected_element", ""))
	var element_name: String = str(
		menu_data.get("selected_element_name", selected_element.capitalize())
	)
	var group_name: String = _get_group_name(menu_data.get("groups", []) as Array, selected_element)
	var selected_spell_name: String = str(menu_data.get("selected_spell_name", "None"))
	var current_ability_name: String = str(menu_data.get("current_ability_name", "None"))
	if focus_spell_header_label != null:
		focus_spell_header_label.text = group_name.to_upper() + "  /  " + element_name.to_upper()
		focus_spell_header_label.add_theme_color_override(
			"font_color",
			get_element_color(selected_element)
		)
	if focus_spell_current_label != null:
		focus_spell_current_label.text = (
			"ACTIVE  "
			+ _get_selected_quick_slot_label()
			+ "  •  "
			+ current_ability_name
		)
	if focus_spell_selected_label != null:
		var detail: String = selected_spell_name
		var ability: AbilityDefinition = _get_selected_focus_ability()
		if ability != null:
			var costs: Array[String] = []
			if ability.mana_cost > 0:
				costs.append("MANA " + str(ability.mana_cost))
			if ability.stamina_cost > 0:
				costs.append("STAMINA " + str(ability.stamina_cost))
			if ability.focus_cost > 0:
				costs.append("FOCUS " + str(ability.focus_cost))
			var assigned: String = _get_quick_slots_for_spell_id(ability.get_spell_id())
			if assigned != "":
				costs.append("SLOTS " + assigned)
			if not costs.is_empty():
				detail += "    •    " + "    •    ".join(costs)
		focus_spell_selected_label.text = detail


func _make_focus_group_label(group_name: String) -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(52.0, 38.0)
	label.text = group_name.to_upper().left(4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color(0.48, 0.58, 0.74, 0.82))
	return label


func _make_cached_element_tile(element: String) -> Dictionary:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(52.0, 38.0)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 3)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_right", 3)
	margin.add_theme_constant_override("margin_bottom", 3)
	tile.add_child(margin)
	var label := Label.new()
	label.text = get_short_element_name(element)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9 if element.length() > 7 else 10)
	margin.add_child(label)
	return {"tile": tile, "label": label}


func _make_cached_spell_row(spell_name: String) -> Dictionary:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0.0, 38.0)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 11)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 11)
	margin.add_theme_constant_override("margin_bottom", 6)
	row.add_child(margin)
	var label := Label.new()
	label.text = spell_name
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 12)
	margin.add_child(label)
	return {"row": row, "label": label}


func _get_element_tile_style(element: String, selected: bool) -> StyleBoxFlat:
	var color: Color = get_element_color(element)
	return _get_focus_style(
		"element|" + element + "|" + str(selected),
		Color(color.r * 0.22, color.g * 0.22, color.b * 0.22, 0.92)
		if selected
		else Color(0.024, 0.034, 0.052, 0.88),
		Color(color.r, color.g, color.b, 0.96 if selected else 0.42),
		2 if selected else 1,
		8
	)


func _get_spell_row_style(
	element: String,
	color: Color,
	selected: bool
) -> StyleBoxFlat:
	return _get_focus_style(
		"spell|" + element + "|" + str(selected),
		Color(color.r * 0.2, color.g * 0.2, color.b * 0.2, 0.94)
		if selected
		else Color(0.022, 0.032, 0.049, 0.86),
		Color(color.r, color.g, color.b, 0.96 if selected else 0.34),
		2 if selected else 1,
		9
	)


func _get_focus_style(
	key: String,
	fill: Color,
	border: Color,
	border_width: int,
	radius: int
) -> StyleBoxFlat:
	if focus_style_cache.has(key):
		return focus_style_cache[key] as StyleBoxFlat
	var style: StyleBoxFlat = make_panel_style(fill, border, border_width, radius)
	focus_style_cache[key] = style
	return style


func _get_group_name(groups: Array, selected_element: String) -> String:
	for group_variant: Variant in groups:
		if not group_variant is Dictionary:
			continue
		var group: Dictionary = group_variant as Dictionary
		for element_variant: Variant in group.get("elements", []) as Array:
			if str(element_variant) == selected_element:
				return str(group.get("name", "Spells"))
	return "Spells"


func _get_selected_focus_ability() -> AbilityDefinition:
	var caster: Node = _get_player_ability_caster()
	if caster == null or not caster.has_method("get_selected_focus_spell_global_index"):
		return null
	var index: int = int(caster.call("get_selected_focus_spell_global_index"))
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return null
	return (loadout_value as AbilityLoadout).get_equipped_ability(index)


func _get_player_ability_caster() -> Node:
	var player: Node = get_tree().get_first_node_in_group("player")
	return player.get_node_or_null("AbilityCaster") if player != null else null


func _get_player_router() -> Node:
	return get_tree().get_first_node_in_group("player_control_router")


func _get_selected_quick_slot_label() -> String:
	var router: Node = _get_player_router()
	if router != null and router.has_method("get_selected_quick_spell_slot"):
		var slot: int = int(router.call("get_selected_quick_spell_slot"))
		return "0" if slot == 9 else str(slot + 1)
	return "—"


func _get_quick_slots_for_spell_name(spell_name: String) -> String:
	var router: Node = _get_player_router()
	if router == null or not router.has_method("get_quick_spell_slot_rows"):
		return ""
	var labels: Array[String] = []
	for row_variant: Variant in router.call("get_quick_spell_slot_rows") as Array:
		if row_variant is Dictionary and str((row_variant as Dictionary).get("name", "")) == spell_name:
			labels.append(str((row_variant as Dictionary).get("key_label", "")))
	return ",".join(labels)


func _get_quick_slots_for_spell_id(spell_id: String) -> String:
	var router: Node = _get_player_router()
	if router == null or not router.has_method("get_quick_spell_slot_rows"):
		return ""
	var labels: Array[String] = []
	for row_variant: Variant in router.call("get_quick_spell_slot_rows") as Array:
		if row_variant is Dictionary and str((row_variant as Dictionary).get("spell_id", "")) == spell_id:
			labels.append(str((row_variant as Dictionary).get("key_label", "")))
	return ",".join(labels)


func detect_input_mode(event: InputEvent) -> String:
	if event is InputEventJoypadButton:
		var button_event: InputEventJoypadButton = event as InputEventJoypadButton
		if button_event.pressed:
			return INPUT_MODE_CONTROLLER
		return ""
	if event is InputEventJoypadMotion:
		var motion_event: InputEventJoypadMotion = event as InputEventJoypadMotion
		if abs(motion_event.axis_value) >= 0.35:
			return INPUT_MODE_CONTROLLER
		return ""
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			return INPUT_MODE_KEYBOARD
		return ""
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.pressed:
			return INPUT_MODE_KEYBOARD
		return ""
	if event is InputEventMouseMotion:
		return INPUT_MODE_KEYBOARD
	return ""


func set_input_mode(mode: String) -> void:
	if mode == "" or mode == last_input_mode:
		return
	last_input_mode = mode
	update_input_mode_label()
	update_focus_help_copy()
	if prompt_is_visible:
		show_prompt(current_prompt_text)


func ensure_input_mode_label() -> void:
	if input_mode_label != null:
		return
	input_mode_label = Label.new()
	input_mode_label.name = "InputModeLabel"
	input_mode_label.anchor_left = 1.0
	input_mode_label.anchor_top = 0.0
	input_mode_label.anchor_right = 1.0
	input_mode_label.anchor_bottom = 0.0
	input_mode_label.offset_left = -270.0
	input_mode_label.offset_top = 74.0
	input_mode_label.offset_right = -24.0
	input_mode_label.offset_bottom = 98.0
	input_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	input_mode_label.visible = false
	input_mode_label.add_theme_color_override(
		"font_color",
		Color(0.68, 0.76, 0.9, 0.78)
	)
	input_mode_label.add_theme_font_size_override("font_size", 12)
	add_child(input_mode_label)


func update_input_mode_label() -> void:
	ensure_input_mode_label()
	input_mode_label.text = "Input: " + get_input_mode_display_name()


func update_focus_help_copy() -> void:
	if focus_spell_help_label == null:
		return
	if last_input_mode == INPUT_MODE_CONTROLLER:
		var hand_roles: Dictionary = get_hand_role_summary()
		focus_spell_help_label.text = (
			"D-pad ←/→ elements  •  ↑/↓ spells  •  Right stick browse  •  "
			+ "1–0 assign  •  A/"
			+ str(hand_roles.get("cast", "ZL"))
			+ " equip  •  Release "
			+ str(hand_roles.get("focus", "L"))
			+ " close"
		)
	else:
		focus_spell_help_label.text = (
			"Arrows / wheel browse  •  1–0 assign  •  Enter / Q equip  •  Release Tab close"
		)


func get_hand_role_summary() -> Dictionary:
	var router: Node = get_tree().get_first_node_in_group("player_control_router")
	if router != null and router.has_method("get_hand_role_summary"):
		var summary_result: Variant = router.call("get_hand_role_summary")
		if summary_result is Dictionary:
			return summary_result as Dictionary
	return {
		"focus": "L",
		"cast": "ZL",
	}


func get_interact_prompt_prefix() -> String:
	if last_input_mode == INPUT_MODE_CONTROLLER:
		return "A: "
	return "E: "


func get_input_mode_display_name() -> String:
	if last_input_mode == INPUT_MODE_CONTROLLER:
		return "Controller"
	return "Keyboard / Mouse"


func get_focus_presentation_debug_data() -> Dictionary:
	return {
		"upgraded": true,
		"cached_elements": focus_cached_element_tiles.size(),
		"cached_spells": focus_cached_spell_rows.size(),
		"structure_rebuilds": focus_structure_rebuilds,
		"visual_updates": focus_visual_updates,
		"style_cache_size": focus_style_cache.size(),
		"panel_visible": focus_spell_panel != null and focus_spell_panel.visible,
	}
