extends CanvasLayer

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


func _ready() -> void:
	print("GameUI ready. Adding to game_ui group.")
	add_to_group("game_ui")
	
	GameState.stat_changed.connect(_on_stat_changed)
	GameState.player_defeated.connect(_on_player_defeated)
	update_debug_stats_label()

	play_prologue_button.pressed.connect(_on_play_prologue_pressed)
	skip_prologue_button.pressed.connect(_on_skip_prologue_pressed)

	hide_prompt()
	hide_message()
	hide_choices()
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


func _on_stat_changed(stat_name: String, value: int) -> void:
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
	spell_menu_label.visible = true


func hide_spell_menu() -> void:
	spell_menu_label.visible = false


func show_spell_focus_menu(menu_data: Dictionary) -> void:
	spell_menu_label.text = build_spell_focus_menu_text(menu_data)
	spell_menu_label.visible = true


func hide_spell_focus_menu() -> void:
	hide_spell_menu()


func build_spell_focus_menu_text(menu_data: Dictionary) -> String:
	var selected_element: String = str(menu_data.get("selected_element", ""))
	var selected_element_name: String = str(menu_data.get("selected_element_name", selected_element.capitalize()))
	var selected_spell_index: int = int(menu_data.get("selected_spell_index", 0))
	var selected_spell_name: String = str(menu_data.get("selected_spell_name", "None"))
	var current_ability_name: String = str(menu_data.get("current_ability_name", "None"))

	var text: String = "FOCUS SPELL MENU\n"
	text += "Hold focus. ←/→ element   ↑/↓ or wheel spell   Enter/Q/click select\n\n"
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
		text += "  No learned spells yet. The shelf is waiting.\n"
	else:
		for i: int in range(spell_names.size()):
			var prefix: String = "  "

			if i == selected_spell_index:
				prefix = "> "

			text += prefix + str(i + 1) + ". " + str(spell_names[i]) + "\n"

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


func show_dev_vision(text: String) -> void:
	dev_vision_label.text = text
	dev_vision_label.visible = true


func hide_dev_vision() -> void:
	dev_vision_label.visible = false
