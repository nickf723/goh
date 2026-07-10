extends Node

@export var minimum_time_scale: float = 0.12
@export var max_focus_for_best_slow: int = 10

var is_focusing: bool = false


func _process(_delta: float) -> void:
	if Input.is_action_pressed("spell_menu"):
		start_focus()
	else:
		stop_focus()


func start_focus() -> void:
	if is_focusing:
		return

	is_focusing = true

	var target_time_scale: float = get_focus_time_scale()
	Engine.time_scale = target_time_scale

	set_focus_menu_open(true)
	update_focus_ui(target_time_scale)
	open_spell_quick_menu()


func stop_focus() -> void:
	if not is_focusing:
		return

	is_focusing = false
	Engine.time_scale = 1.0

	set_focus_menu_open(false)
	clear_focus_ui()
	close_spell_quick_menu()


func get_focus_time_scale() -> float:
	var focus: int = GameState.get_stat("focus")
	var focus_ratio: float = clamp(float(focus) / float(max_focus_for_best_slow), 0.0, 1.0)

	return lerp(1.0, minimum_time_scale, focus_ratio)


func set_focus_menu_open(value: bool) -> void:
	var action_state: Node = get_action_state()

	if action_state != null and action_state.has_method("set_focus_menu_open"):
		action_state.set_focus_menu_open(value)


func update_focus_ui(time_scale: float) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("show_focus_mode"):
		ui.show_focus_mode(time_scale)


func clear_focus_ui() -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("hide_focus_mode"):
		ui.hide_focus_mode()


func open_spell_quick_menu() -> void:
	var ability_caster: Node = get_ability_caster()

	if ability_caster != null and ability_caster.has_method("open_focus_spell_menu"):
		ability_caster.open_focus_spell_menu()
		return

	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("show_spell_menu"):
		ui.show_spell_menu()


func close_spell_quick_menu() -> void:
	var ability_caster: Node = get_ability_caster()

	if ability_caster != null and ability_caster.has_method("close_focus_spell_menu"):
		ability_caster.close_focus_spell_menu()
		return

	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("hide_spell_menu"):
		ui.hide_spell_menu()


func get_player() -> Node:
	return get_tree().get_first_node_in_group("player")


func get_action_state() -> Node:
	var player: Node = get_player()

	if player == null:
		return null

	return player.get_node_or_null("PlayerActionState")


func get_ability_caster() -> Node:
	var player: Node = get_player()

	if player == null:
		return null

	return player.get_node_or_null("AbilityCaster")
