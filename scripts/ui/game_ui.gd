extends CanvasLayer

const ELEMENT_COLORS: Dictionary = {
	"water": Color(0.16, 0.48, 0.95, 1.0),
	"earth": Color(0.42, 0.78, 0.24, 1.0),
	"fire": Color(1.0, 0.28, 0.08, 1.0),
	"air": Color(0.95, 0.48, 0.72, 1.0),
	"ice": Color(0.5, 0.9, 1.0, 1.0),
	"metal": Color(0.96, 0.78, 0.18, 1.0),
	"lightning": Color(0.28, 0.46, 1.0, 1.0),
	"poison": Color(0.48, 0.92, 0.22, 1.0),
	"life": Color(0.1, 0.92, 0.5, 1.0),
	"death": Color(0.82, 0.08, 0.08, 1.0),
	"body": Color(0.92, 0.22, 0.72, 1.0),
	"soul": Color(0.1, 0.86, 0.92, 1.0),
	"dreams": Color(0.18, 0.28, 0.9, 1.0),
	"sound": Color(1.0, 0.52, 0.08, 1.0),
	"space": Color(0.58, 0.22, 1.0, 1.0),
	"time": Color(0.98, 0.66, 0.16, 1.0),
}

const EMPTY_ELEMENT_COLOR: Color = Color(0.2, 0.22, 0.27, 1.0)
const PANEL_BACKGROUND: Color = Color(0.035, 0.045, 0.06, 0.44)
const PANEL_BORDER: Color = Color(0.52, 0.6, 0.78, 0.72)
const INNER_PANEL_BACKGROUND: Color = Color(0.05, 0.065, 0.09, 0.34)
const INNER_PANEL_BORDER: Color = Color(0.28, 0.34, 0.48, 0.45)
const ROW_BACKGROUND: Color = Color(0.075, 0.08, 0.1, 0.44)
const TEXT_MAIN: Color = Color(0.92, 0.95, 1.0, 0.96)
const TEXT_SOFT: Color = Color(0.64, 0.72, 0.84, 0.82)
const FIRE_CHARGE_COLOR: Color = Color(1.0, 0.32, 0.08, 0.92)
const FIRE_CHARGE_FULL_COLOR: Color = Color(1.0, 0.78, 0.18, 1.0)

@onready var objective_label: Label = $ObjectiveLabel
@onready var prompt_label: Label = $PromptLabel
@onready var message_panel: PanelContainer = $MessagePanel
@onready var message_label: Label = $MessagePanel/MessageLabel

@onready var choice_panel: PanelContainer = $ChoicePanel
@onready var choice_label: Label = $ChoicePanel/ChoiceBox/ChoiceLabel
@onready var play_prologue_button: Button = $ChoicePanel/ChoiceBox/PlayPrologueButton
@onready var skip_prologue_button: Button = $ChoicePanel/ChoiceBox/SkipPrologueButton

@onready var debug_stats_label: Label = $DebugStatsLabel
@onready var focus_label: Label = $FocusLabel
@onready var spell_menu_label: Label = $SpellMenuLabel
@onready var dev_vision_label: Label = $DevVisionLabel

var focus_spell_panel: PanelContainer
var focus_spell_title_label: Label
var focus_spell_current_label: Label
var focus_spell_element_grid: GridContainer
var focus_spell_list: VBoxContainer
var focus_spell_header_label: Label
var focus_spell_selected_label: Label
var focus_spell_help_label: Label
var focus_spell_element_tiles: Dictionary = {}

var charge_panel: PanelContainer
var charge_title_label: Label
var charge_hint_label: Label
var charge_progress_bar: ProgressBar
var charge_meter_was_full: bool = false
var charge_pulse_tween: Tween


func _ready() -> void:
	print("GameUI ready. Adding to game_ui group.")
	add_to_group("game_ui")

	ensure_focus_spell_selector_ui()
	ensure_charge_meter_ui()
	
	GameState.stat_changed.connect(_on_stat_changed)
	GameState.player_defeated.connect(_on_player_defeated)
	update_debug_stats_label()

	play_prologue_button.pressed.connect(_on_play_prologue_pressed)
	skip_prologue_button.pressed.connect(_on_skip_prologue_pressed)

	hide_prompt()
	hide_message()
	hide_choices()
	hide_spell_focus_menu()
	hide_charge_meter()
	set_objective("Look around.")


func set_objective(text: String) -> void:
	objective_label.text = "Objective: " + text


func show_prompt(text: String) -> void:
	prompt_label.text = "E: " + text
	prompt_label.visible = true


func hide_prompt() -> void:
	prompt_label.visible = false


func show_message(text: String) -> void:
	message_label.text = text
	message_panel.visible = true


func hide_message() -> void:
	message_panel.visible = false


func show_prologue_choice() -> void:
	choice_label.text = "What happened before you arrived?"
	choice_panel.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func hide_choices() -> void:
	choice_panel.visible = false


func _on_play_prologue_pressed() -> void:
	hide_choices()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().change_scene_to_file("res://scenes/prologue_placeholder.tscn")


func _on_skip_prologue_pressed() -> void:
	hide_choices()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().change_scene_to_file("res://scenes/church_hq_placeholder.tscn")


func update_debug_stats_label() -> void:
	var health: int = GameState.get_stat("health")
	var max_health: int = GameState.get_stat("max_health")

	var stamina: int = GameState.get_stat("stamina")
	var max_stamina: int = GameState.get_stat("max_stamina")

	var mana: int = GameState.get_stat("mana")
	var max_mana: int = GameState.get_stat("max_mana")

	var stance: int = GameState.get_stat("stance")
	var max_stance: int = GameState.get_stat("max_stance")

	debug_stats_label.text = (
		"Health: " + str(health) + " / " + str(max_health) + "\n"
		+ "Stamina: " + str(stamina) + " / " + str(max_stamina) + "\n"
		+ "Mana: " + str(mana) + " / " + str(max_mana) + "\n"
		+ "Stance: " + str(stance) + " / " + str(max_stance)
	)


func _on_stat_changed(stat_name: String, _value: int) -> void:
	if stat_name in [
		"health",
		"max_health",
		"stamina",
		"max_stamina",
		"mana",
		"max_mana",
		"stance",
		"max_stance",
	]:
		update_debug_stats_label()


func show_focus_mode(time_scale: float) -> void:
	focus_label.text = "Focus: Time x" + str(snapped(time_scale, 0.01))
	focus_label.visible = true


func hide_focus_mode() -> void:
	focus_label.text = "Focus: Ready"
	focus_label.visible = true


func show_spell_menu() -> void:
	if focus_spell_panel != null and focus_spell_panel.visible:
		return

	spell_menu_label.visible = true


func hide_spell_menu() -> void:
	spell_menu_label.visible = false


func set_spell_label(ability_name: String) -> void:
	spell_menu_label.text = "Spell: " + ability_name

	if ability_name.begins_with("Charging Firebolt"):
		show_charge_meter(parse_charge_percent(ability_name))
	else:
		hide_charge_meter()


func ensure_charge_meter_ui() -> void:
	if charge_panel != null:
		return

	charge_panel = PanelContainer.new()
	charge_panel.name = "ChargedFireboltMeter"
	charge_panel.visible = false
	charge_panel.anchor_left = 0.5
	charge_panel.anchor_top = 1.0
	charge_panel.anchor_right = 0.5
	charge_panel.anchor_bottom = 1.0
	charge_panel.offset_left = -170.0
	charge_panel.offset_top = -150.0
	charge_panel.offset_right = 170.0
	charge_panel.offset_bottom = -86.0
	charge_panel.pivot_offset = Vector2(170.0, 32.0)
	charge_panel.add_theme_stylebox_override("panel", make_panel_style(Color(0.09, 0.045, 0.03, 0.76), Color(1.0, 0.38, 0.08, 0.72), 2, 14))
	add_child(charge_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	charge_panel.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)

	charge_title_label = Label.new()
	charge_title_label.text = "CHARGING FIREBOLT"
	charge_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	charge_title_label.add_theme_color_override("font_color", TEXT_MAIN)
	charge_title_label.add_theme_font_size_override("font_size", 13)
	box.add_child(charge_title_label)

	charge_progress_bar = ProgressBar.new()
	charge_progress_bar.min_value = 0.0
	charge_progress_bar.max_value = 100.0
	charge_progress_bar.value = 0.0
	charge_progress_bar.show_percentage = false
	charge_progress_bar.custom_minimum_size = Vector2(0.0, 14.0)
	charge_progress_bar.add_theme_stylebox_override("background", make_panel_style(Color(0.04, 0.03, 0.025, 0.88), Color(0.4, 0.18, 0.08, 0.5), 1, 8))
	charge_progress_bar.add_theme_stylebox_override("fill", make_panel_style(FIRE_CHARGE_COLOR, FIRE_CHARGE_COLOR, 0, 8))
	box.add_child(charge_progress_bar)

	charge_hint_label = Label.new()
	charge_hint_label.text = "Release to cast"
	charge_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	charge_hint_label.add_theme_color_override("font_color", TEXT_SOFT)
	charge_hint_label.add_theme_font_size_override("font_size", 11)
	box.add_child(charge_hint_label)


func show_charge_meter(percent: int) -> void:
	ensure_charge_meter_ui()

	var clamped_percent: int = clamp(percent, 0, 100)
	var is_full: bool = clamped_percent >= 100
	charge_panel.visible = true
	charge_progress_bar.value = clamped_percent

	if is_full:
		charge_title_label.text = "FULL CHARGE"
		charge_hint_label.text = "Release the pocket sun"
		charge_progress_bar.add_theme_stylebox_override("fill", make_panel_style(FIRE_CHARGE_FULL_COLOR, FIRE_CHARGE_FULL_COLOR, 0, 8))
		if not charge_meter_was_full:
			trigger_charge_full_feedback()
	else:
		charge_title_label.text = "CHARGING FIREBOLT  " + str(clamped_percent) + "%"
		charge_hint_label.text = "Hold to build power"
		charge_progress_bar.add_theme_stylebox_override("fill", make_panel_style(FIRE_CHARGE_COLOR, FIRE_CHARGE_COLOR, 0, 8))

	charge_meter_was_full = is_full


func hide_charge_meter() -> void:
	if charge_panel != null:
		charge_panel.visible = false
		charge_panel.scale = Vector2.ONE

	charge_meter_was_full = false


func parse_charge_percent(text: String) -> int:
	var split_text: PackedStringArray = text.split(":")

	if split_text.size() < 2:
		return 0

	var percent_text: String = split_text[1].strip_edges().replace("%", "")

	if not percent_text.is_valid_int():
		return 0

	return clamp(int(percent_text), 0, 100)


func trigger_charge_full_feedback() -> void:
	if charge_panel == null:
		return

	if charge_pulse_tween != null:
		charge_pulse_tween.kill()

	charge_panel.scale = Vector2.ONE
	charge_pulse_tween = create_tween()
	charge_pulse_tween.tween_property(charge_panel, "scale", Vector2(1.055, 1.055), 0.06)
	charge_pulse_tween.tween_property(charge_panel, "scale", Vector2.ONE, 0.12)

	Input.start_joy_vibration(0, 0.2, 0.65, 0.16)


func ensure_focus_spell_selector_ui() -> void:
	if focus_spell_panel != null:
		return

	focus_spell_panel = PanelContainer.new()
	focus_spell_panel.name = "FocusSpellSelectorPanel"
	focus_spell_panel.visible = false
	focus_spell_panel.anchor_left = 0.5
	focus_spell_panel.anchor_top = 1.0
	focus_spell_panel.anchor_right = 0.5
	focus_spell_panel.anchor_bottom = 1.0
	focus_spell_panel.offset_left = -330.0
	focus_spell_panel.offset_top = -310.0
	focus_spell_panel.offset_right = 330.0
	focus_spell_panel.offset_bottom = -42.0
	focus_spell_panel.add_theme_stylebox_override("panel", make_panel_style(PANEL_BACKGROUND, PANEL_BORDER, 2, 14))
	add_child(focus_spell_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	focus_spell_panel.add_child(margin)

	var root_box: VBoxContainer = VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 7)
	margin.add_child(root_box)

	var header_box: HBoxContainer = HBoxContainer.new()
	header_box.add_theme_constant_override("separation", 10)
	root_box.add_child(header_box)

	focus_spell_title_label = Label.new()
	focus_spell_title_label.text = "SPELL FOCUS"
	focus_spell_title_label.add_theme_color_override("font_color", TEXT_MAIN)
	focus_spell_title_label.add_theme_font_size_override("font_size", 16)
	focus_spell_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_box.add_child(focus_spell_title_label)

	focus_spell_current_label = Label.new()
	focus_spell_current_label.text = "Equipped: None"
	focus_spell_current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	focus_spell_current_label.add_theme_color_override("font_color", TEXT_SOFT)
	focus_spell_current_label.add_theme_font_size_override("font_size", 12)
	focus_spell_current_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_box.add_child(focus_spell_current_label)

	var content_box: HBoxContainer = HBoxContainer.new()
	content_box.add_theme_constant_override("separation", 10)
	content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(content_box)

	var element_panel: PanelContainer = PanelContainer.new()
	element_panel.custom_minimum_size = Vector2(292.0, 188.0)
	element_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	element_panel.add_theme_stylebox_override(
		"panel",
		make_panel_style(INNER_PANEL_BACKGROUND, INNER_PANEL_BORDER, 1, 10)
	)
	content_box.add_child(element_panel)

	var element_margin: MarginContainer = MarginContainer.new()
	element_margin.add_theme_constant_override("margin_left", 7)
	element_margin.add_theme_constant_override("margin_top", 7)
	element_margin.add_theme_constant_override("margin_right", 7)
	element_margin.add_theme_constant_override("margin_bottom", 7)
	element_panel.add_child(element_margin)

	focus_spell_element_grid = GridContainer.new()
	focus_spell_element_grid.columns = 4
	focus_spell_element_grid.add_theme_constant_override("h_separation", 5)
	focus_spell_element_grid.add_theme_constant_override("v_separation", 5)
	element_margin.add_child(focus_spell_element_grid)

	var right_panel: PanelContainer = PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(320.0, 188.0)
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_stylebox_override(
		"panel",
		make_panel_style(INNER_PANEL_BACKGROUND, INNER_PANEL_BORDER, 1, 10)
	)
	content_box.add_child(right_panel)

	var right_margin: MarginContainer = MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 9)
	right_margin.add_theme_constant_override("margin_top", 7)
	right_margin.add_theme_constant_override("margin_right", 9)
	right_margin.add_theme_constant_override("margin_bottom", 7)
	right_panel.add_child(right_margin)

	var right_box: VBoxContainer = VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 5)
	right_margin.add_child(right_box)

	focus_spell_header_label = Label.new()
	focus_spell_header_label.text = "Fire"
	focus_spell_header_label.add_theme_color_override("font_color", TEXT_MAIN)
	focus_spell_header_label.add_theme_font_size_override("font_size", 16)
	right_box.add_child(focus_spell_header_label)

	focus_spell_selected_label = Label.new()
	focus_spell_selected_label.text = "Cast: None"
	focus_spell_selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	focus_spell_selected_label.add_theme_color_override("font_color", TEXT_SOFT)
	focus_spell_selected_label.add_theme_font_size_override("font_size", 12)
	right_box.add_child(focus_spell_selected_label)

	focus_spell_list = VBoxContainer.new()
	focus_spell_list.add_theme_constant_override("separation", 4)
	focus_spell_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_box.add_child(focus_spell_list)

	focus_spell_help_label = Label.new()
	focus_spell_help_label.text = "D-pad: choose   ZR/Q: cast   Enter/A: equip"
	focus_spell_help_label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88, 0.74))
	focus_spell_help_label.add_theme_font_size_override("font_size", 11)
	right_box.add_child(focus_spell_help_label)


func show_spell_focus_menu(menu_data: Dictionary) -> void:
	ensure_focus_spell_selector_ui()

	spell_menu_label.visible = false

	if not focus_spell_panel.visible:
		focus_spell_panel.modulate.a = 0.0
		focus_spell_panel.visible = true
		var tween: Tween = create_tween()
		tween.tween_property(focus_spell_panel, "modulate:a", 1.0, 0.08)
	else:
		focus_spell_panel.visible = true

	var selected_element: String = str(menu_data.get("selected_element", ""))
	var selected_element_name: String = str(menu_data.get("selected_element_name", selected_element.capitalize()))
	var selected_spell_index: int = int(menu_data.get("selected_spell_index", 0))
	var selected_spell_name: String = str(menu_data.get("selected_spell_name", "None"))
	var current_ability_name: String = str(menu_data.get("current_ability_name", "None"))
	var groups: Array = menu_data.get("groups", [])
	var spell_names: Array = menu_data.get("spell_names", [])

	focus_spell_current_label.text = "Equipped: " + current_ability_name
	focus_spell_header_label.text = selected_element_name
	focus_spell_header_label.add_theme_color_override("font_color", get_element_color(selected_element))
	focus_spell_selected_label.text = "Cast: " + selected_spell_name

	rebuild_element_tiles(groups, selected_element)
	rebuild_spell_rows(spell_names, selected_spell_index, selected_element)


func hide_spell_focus_menu() -> void:
	if focus_spell_panel != null:
		focus_spell_panel.visible = false

	hide_spell_menu()


func rebuild_element_tiles(groups: Array, selected_element: String) -> void:
	if focus_spell_element_grid == null:
		return

	clear_children(focus_spell_element_grid)
	focus_spell_element_tiles.clear()

	for group_variant: Variant in groups:
		if not group_variant is Dictionary:
			continue

		var group: Dictionary = group_variant
		var elements: Array = group.get("elements", [])

		for element_variant: Variant in elements:
			var element: String = str(element_variant)
			var tile: PanelContainer = make_element_tile(element, element == selected_element)
			focus_spell_element_grid.add_child(tile)


func make_element_tile(element: String, is_selected: bool) -> PanelContainer:
	var element_color: Color = get_element_color(element)
	var tile_background: Color = Color(0.08, 0.095, 0.125, 0.38)
	var border_color: Color = Color(element_color.r, element_color.g, element_color.b, 0.42)
	var border_width: int = 1
	var tile_alpha: float = 0.68

	if is_selected:
		tile_background = Color(element_color.r * 0.38, element_color.g * 0.38, element_color.b * 0.38, 0.72)
		border_color = Color(element_color.r, element_color.g, element_color.b, 0.95)
		border_width = 3
		tile_alpha = 1.0

	var tile: PanelContainer = PanelContainer.new()
	tile.custom_minimum_size = Vector2(66.0, 40.0)
	tile.modulate = Color(1.0, 1.0, 1.0, tile_alpha)
	tile.add_theme_stylebox_override("panel", make_panel_style(tile_background, border_color, border_width, 8))

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 3)
	tile.add_child(margin)

	var name_label: Label = Label.new()
	name_label.text = get_short_element_name(element)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", TEXT_MAIN)
	name_label.add_theme_font_size_override("font_size", 12 if element.length() <= 7 else 10)
	margin.add_child(name_label)

	return tile


func rebuild_spell_rows(spell_names: Array, selected_spell_index: int, selected_element: String) -> void:
	if focus_spell_list == null:
		return

	clear_children(focus_spell_list)

	if spell_names.size() == 0:
		var empty_panel: PanelContainer = PanelContainer.new()
		empty_panel.add_theme_stylebox_override(
			"panel",
			make_panel_style(ROW_BACKGROUND, Color(0.22, 0.25, 0.32, 0.48), 1, 8)
		)
		focus_spell_list.add_child(empty_panel)

		var empty_margin: MarginContainer = MarginContainer.new()
		empty_margin.add_theme_constant_override("margin_left", 8)
		empty_margin.add_theme_constant_override("margin_top", 7)
		empty_margin.add_theme_constant_override("margin_right", 8)
		empty_margin.add_theme_constant_override("margin_bottom", 7)
		empty_panel.add_child(empty_margin)

		var empty_label: Label = Label.new()
		empty_label.text = "No learned spells."
		empty_label.add_theme_color_override("font_color", TEXT_SOFT)
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_margin.add_child(empty_label)
		return

	var element_color: Color = get_element_color(selected_element)

	for i: int in range(spell_names.size()):
		var is_selected: bool = i == selected_spell_index
		var row_background: Color = ROW_BACKGROUND
		var border_color: Color = Color(0.2, 0.24, 0.32, 0.5)
		var border_width: int = 1
		var row_alpha: float = 0.72

		if is_selected:
			row_background = Color(element_color.r * 0.34, element_color.g * 0.34, element_color.b * 0.34, 0.78)
			border_color = Color(element_color.r, element_color.g, element_color.b, 0.95)
			border_width = 2
			row_alpha = 1.0

		var row_panel: PanelContainer = PanelContainer.new()
		row_panel.custom_minimum_size = Vector2(0.0, 34.0)
		row_panel.modulate = Color(1.0, 1.0, 1.0, row_alpha)
		row_panel.add_theme_stylebox_override("panel", make_panel_style(row_background, border_color, border_width, 8))
		focus_spell_list.add_child(row_panel)

		var margin: MarginContainer = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 9)
		margin.add_theme_constant_override("margin_top", 5)
		margin.add_theme_constant_override("margin_right", 9)
		margin.add_theme_constant_override("margin_bottom", 5)
		row_panel.add_child(margin)

		var row_label: Label = Label.new()
		var prefix: String = "  "

		if is_selected:
			prefix = "> "

		row_label.text = prefix + str(spell_names[i])
		row_label.add_theme_color_override("font_color", TEXT_MAIN)
		row_label.add_theme_font_size_override("font_size", 13)
		row_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		margin.add_child(row_label)


func clear_children(parent: Node) -> void:
	if parent == null:
		return

	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func get_element_color(element: String) -> Color:
	if ELEMENT_COLORS.has(element):
		return ELEMENT_COLORS[element]

	return EMPTY_ELEMENT_COLOR


func get_short_element_name(element: String) -> String:
	match element:
		"lightning":
			return "Bolt"
		"dreams":
			return "Dream"
		_:
			return element.capitalize()


func make_panel_style(background_color: Color, border_color: Color, border_width: int = 1, corner_radius: int = 10) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	return style


func build_spell_focus_menu_text(menu_data: Dictionary) -> String:
	var selected_element: String = str(menu_data.get("selected_element", ""))
	var selected_element_name: String = str(menu_data.get("selected_element_name", selected_element.capitalize()))
	var selected_spell_index: int = int(menu_data.get("selected_spell_index", 0))
	var selected_spell_name: String = str(menu_data.get("selected_spell_name", "None"))
	var current_ability_name: String = str(menu_data.get("current_ability_name", "None"))

	var text: String = "FOCUS SPELL MENU\n"
	text += "Hold focus. Left/Right element   Up/Down or wheel spell   Q/click cast\n\n"
	text += "Element: " + selected_element_name + "\n"
	text += "Highlighted spell: " + selected_spell_name + "\n"
	text += "Equipped: " + current_ability_name + "\n\n"

	var groups: Array = menu_data.get("groups", [])

	for group_variant: Variant in groups:
		if not group_variant is Dictionary:
			continue

		var group: Dictionary = group_variant

		if group.is_empty():
			continue

		text += str(group.get("name", "Group")) + "\n"

		var elements: Array = group.get("elements", [])
		var row_text: String = ""

		for element_variant: Variant in elements:
			var element: String = str(element_variant)
			var display_name: String = element.capitalize()

			if element == selected_element:
				row_text += "[" + display_name + "]  "
			else:
				row_text += display_name + "  "

		text += row_text + "\n\n"

	var spell_names: Array = menu_data.get("spell_names", [])
	text += "Spells in " + selected_element_name + "\n"

	if spell_names.size() == 0:
		text += "  No learned spells yet.\n"
	else:
		for i: int in range(spell_names.size()):
			var prefix: String = "  "

			if i == selected_spell_index:
				prefix = "> "

			text += prefix + str(i + 1) + ". " + spell_names[i] + "\n"

	return text


func update_spell_menu(ability_names: Array[String], current_index: int) -> void:
	var text: String = "Spells\n"

	for i: int in range(ability_names.size()):
		var prefix: String = "  "

		if i == current_index:
			prefix = "> "

		text += prefix + str(i + 1) + ". " + ability_names[i] + "\n"

	spell_menu_label.text = text


func _on_player_defeated() -> void:
	print("UI received defeated signal.")
	show_message("Grace falls. Press R to restart.")
	set_objective("Defeated.")
	hide_charge_meter()


func show_dev_vision(text: String) -> void:
	dev_vision_label.text = text
	dev_vision_label.visible = true


func hide_dev_vision() -> void:
	dev_vision_label.visible = false
