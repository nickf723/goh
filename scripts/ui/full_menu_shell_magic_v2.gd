extends "res://scripts/ui/full_menu_shell_magic_v1.gd"
class_name FullMenuShellMagicV2

const SPELL_SLOTS_PER_ELEMENT: int = 8
const AUGMENTATION_SLOT_COUNT: int = 3
const AUGMENT_BACKGROUND: Color = Color(0.035, 0.085, 0.095, 0.96)
const AUGMENT_BORDER: Color = Color(0.28, 0.8, 0.84, 0.9)


func handle_menu_input(event: InputEvent) -> bool:
	if not visible:
		return false

	if _is_directional_navigation_event(event):
		_yield_virtual_cursor_to_directional_input()

	return super.handle_menu_input(event)


func _is_directional_navigation_event(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
		if motion.axis in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
			return false

	if event is InputEventJoypadButton:
		var button: InputEventJoypadButton = event as InputEventJoypadButton
		return button.pressed and button.button_index in [
			JOY_BUTTON_DPAD_UP,
			JOY_BUTTON_DPAD_DOWN,
			JOY_BUTTON_DPAD_LEFT,
			JOY_BUTTON_DPAD_RIGHT,
		]

	return (
		event.is_action_pressed("ui_up")
		or event.is_action_pressed("ui_down")
		or event.is_action_pressed("ui_left")
		or event.is_action_pressed("ui_right")
	)


func _yield_virtual_cursor_to_directional_input() -> void:
	if not virtual_cursor_active:
		return
	virtual_cursor_active = false
	virtual_cursor_tab_target = -1
	right_stick_vector = Vector2.ZERO
	if virtual_cursor_layer != null:
		virtual_cursor_layer.visible = false


func _render_element_spell_list(parent: VBoxContainer) -> void:
	parent.add_child(
		_make_magic_heading(
			get_spell_icon(selected_magic_element)
			+ "  "
			+ selected_magic_element.to_upper()
			+ " SPELLS"
		)
	)

	var spells: Array[Dictionary] = _get_element_spells(selected_magic_element)
	_render_element_school_summary(parent, spells.size())

	var spell_grid: GridContainer = make_visual_grid(4)
	spell_grid.name = "MagicElementSpellGrid"
	spell_grid.add_theme_constant_override("h_separation", 8)
	spell_grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(spell_grid)

	var visible_spell_count: int = mini(spells.size(), SPELL_SLOTS_PER_ELEMENT)
	for index: int in range(SPELL_SLOTS_PER_ELEMENT):
		if index < visible_spell_count:
			_add_element_spell_tile(spell_grid, spells[index])
		else:
			_add_undiscovered_spell_slot(spell_grid, index)

	if is_assigning_spell():
		return

	parent.add_child(_make_magic_heading("ELEMENTAL AUGMENTATION  •  SCHOOL-WIDE"))
	var augmentation_hint: Label = Label.new()
	augmentation_hint.text = (
		"Choose one directed secondary element, or select Pure to remove the augmentation. "
		+ "This changes every spell in the school rather than one individual spell."
	)
	augmentation_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	augmentation_hint.add_theme_font_size_override("font_size", 10)
	augmentation_hint.add_theme_color_override("font_color", TEXT_SOFT)
	parent.add_child(augmentation_hint)

	var augmentation_grid: GridContainer = make_visual_grid(AUGMENTATION_SLOT_COUNT)
	augmentation_grid.name = "MagicAugmentationStrip"
	augmentation_grid.add_theme_constant_override("h_separation", 9)
	parent.add_child(augmentation_grid)
	_render_augmentation_choices(augmentation_grid)


func _render_element_school_summary(parent: VBoxContainer, learned_count: int) -> void:
	var summary_grid: GridContainer = make_visual_grid(4)
	summary_grid.name = "MagicElementSchoolSummary"
	summary_grid.add_theme_constant_override("h_separation", 6)
	parent.add_child(summary_grid)
	_add_magic_info_panel(
		summary_grid,
		_get_element_family(selected_magic_element).to_upper(),
		"Element family"
	)
	_add_magic_info_panel(
		summary_grid,
		str(learned_count) + "/" + str(SPELL_SLOTS_PER_ELEMENT) + " LEARNED",
		"Spell library"
	)
	_add_magic_info_panel(
		summary_grid,
		"AFFINITY " + str(GameState.get_stat(selected_magic_element)),
		"Scaling hook"
	)
	var active_target: String = _get_active_augmentation(selected_magic_element)
	_add_magic_info_panel(
		summary_grid,
		(
			ElementalAugmentationCatalogScript.get_pair_label(
				selected_magic_element,
				active_target
			).to_upper()
			if active_target != ""
			else "PURE " + selected_magic_element.to_upper()
		),
		"Current school form"
	)


func _add_element_spell_tile(parent: Container, spell: Dictionary) -> void:
	var spell_id: String = SpellProgressionCatalogScript.get_spell_id(spell)
	var action: Dictionary = (
		{
			"kind": "assign_spell",
			"learned_index": int(spell.get("learned_index", -1)),
		}
		if is_assigning_spell()
		else {"kind": "open_magic_spell", "spell_id": spell_id}
	)
	var badge: String = get_spell_cost_label(spell)
	var equipped: String = get_spell_equipped_subtitle(spell)
	if equipped != "Spellbook":
		badge += "  •  " + equipped
	_add_compact_action_tile(
		parent,
		get_spell_icon(selected_magic_element),
		_get_magic_spell_name(spell),
		badge,
		action,
		str(spell.get("description", "")),
		72.0,
		10
	)


func _add_undiscovered_spell_slot(parent: Container, slot_index: int) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(112.0, 72.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(
		"panel",
		make_panel_style(
			Color(0.035, 0.043, 0.058, 0.76),
			Color(0.18, 0.22, 0.31, 0.45),
			1,
			9
		)
	)
	parent.add_child(panel)
	var label: Label = Label.new()
	label.text = "◇\nUndiscovered\nSPELL " + str(slot_index + 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", TEXT_DIM)
	panel.add_child(label)


func _render_augmentation_choices(parent: Container) -> void:
	var active_target: String = _get_active_augmentation(selected_magic_element)
	_add_augmentation_choice_tile(
		parent,
		"◇",
		"Pure " + selected_magic_element.capitalize(),
		"NO AUGMENTATION",
		"",
		active_target == "",
		"Return every " + selected_magic_element.capitalize() + " spell to its original element identity."
	)

	for option: Dictionary in ElementalAugmentationCatalogScript.get_options(
		selected_magic_element
	):
		var target: String = str(option.get("target", ""))
		_add_augmentation_choice_tile(
			parent,
			get_spell_icon(selected_magic_element) + " → " + get_spell_icon(target),
			str(option.get("name", target.capitalize())),
			target.to_upper() + " AUGMENT",
			target,
			active_target == target,
			str(option.get("result", ""))
		)


func _add_augmentation_choice_tile(
	parent: Container,
	icon_text: String,
	title: String,
	badge: String,
	target_element: String,
	is_active: bool,
	tooltip: String
) -> void:
	var action_index: int = selectable_actions.size()
	selectable_actions.append({
		"kind": "set_elemental_augmentation",
		"source": selected_magic_element,
		"target": target_element,
	})

	var selected: bool = action_index == selected_action_index
	var button: Button = Button.new()
	button.text = (
		icon_text
		+ "\n"
		+ title
		+ "\n"
		+ ("ACTIVE  •  " if is_active else "")
		+ badge
	)
	button.tooltip_text = tooltip
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(145.0, 82.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", TEXT_MAIN if selected or is_active else TEXT_SOFT)
	button.add_theme_stylebox_override(
		"normal",
		make_panel_style(
			ACTIVE_SELECTION_BACKGROUND if selected else AUGMENT_BACKGROUND,
			ACTIVE_SELECTION_BORDER if selected else (AUGMENT_BORDER if is_active else AUGMENT_BORDER.darkened(0.3)),
			3 if selected else (2 if is_active else 1),
			11
		)
	)
	button.add_theme_stylebox_override(
		"focus",
		make_panel_style(ACTIVE_SELECTION_BACKGROUND, ACTIVE_SELECTION_BORDER, 3, 11)
	)
	button.add_theme_stylebox_override(
		"hover",
		make_panel_style(Color(0.06, 0.14, 0.15, 0.98), AUGMENT_BORDER, 2, 11)
	)
	button.pressed.connect(_on_action_row_pressed.bind(action_index))
	button.mouse_entered.connect(_on_action_row_hovered.bind(action_index))
	parent.add_child(button)
	_register_action_control(button, action_index)
	if selected:
		schedule_selected_control(button)


func _render_spell_augmentation_summary(
	parent: VBoxContainer,
	spell: Dictionary
) -> void:
	var source: String = str(spell.get("element", selected_magic_element))
	var target: String = _get_active_augmentation(source)
	var panel: PanelContainer = _make_magic_subpanel()
	panel.name = "SpellSchoolAugmentationSummary"
	parent.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var title: Label = Label.new()
	title.text = "SCHOOL AUGMENTATION"
	title.custom_minimum_size = Vector2(190.0, 0.0)
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", AUGMENT_BORDER)
	row.add_child(title)
	var value: Label = Label.new()
	value.text = (
		ElementalAugmentationCatalogScript.get_pair_label(source, target)
		if target != ""
		else "Pure " + source.capitalize()
	)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.add_theme_font_size_override("font_size", 11)
	value.add_theme_color_override("font_color", TEXT_MAIN)
	row.add_child(value)
	var hint: Label = Label.new()
	hint.text = "Change this from the three-choice strip beneath the element's eight spell slots."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", TEXT_DIM)
	row.add_child(hint)


func _get_element_family(element_id: String) -> String:
	var index: int = ELEMENT_ORDER.find(element_id)
	if index < 0:
		return "Unknown"
	return ["Natural", "Primal", "Vital", "Mystical"][index / 4]


func get_magic_debug_data() -> Dictionary:
	var data: Dictionary = super.get_magic_debug_data()
	data["spell_slots_per_element"] = SPELL_SLOTS_PER_ELEMENT
	data["augmentation_slot_count"] = AUGMENTATION_SLOT_COUNT
	data["augmentation_strip_present"] = (
		find_child("MagicAugmentationStrip", true, false) != null
	)
	data["virtual_cursor_active"] = virtual_cursor_active
	return data
