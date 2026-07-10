extends Node

@export var minimum_time_scale: float = 0.25
@export var max_focus_for_best_slow: int = 10

@onready var action_state: PlayerActionState = get_tree().get_first_node_in_group("player").get_node_or_null("PlayerActionState")

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

	var focus: int = GameState.get_stat("focus")
	var focus_ratio: float = clamp(float(focus) / float(max_focus_for_best_slow), 0.0, 1.0)

	var target_time_scale: float = lerp(1.0, minimum_time_scale, focus_ratio)

	Engine.time_scale = target_time_scale
	update_focus_ui(target_time_scale)
	show_spell_menu()
	if is_focusing:
		return

	is_focusing = true

	Engine.time_scale = target_time_scale
	update_focus_ui(target_time_scale)
	if is_focusing:
		return

	is_focusing = true

	Engine.time_scale = target_time_scale

func stop_focus() -> void:
	if not is_focusing:
		return

	is_focusing = false
	Engine.time_scale = 1.0
	clear_focus_ui()
	hide_spell_menu()
	if not is_focusing:
		return

	is_focusing = false
	Engine.time_scale = 1.0
	clear_focus_ui()

func update_focus_ui(time_scale: float) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("show_focus_mode"):
		ui.show_focus_mode(time_scale)

func clear_focus_ui() -> void:
	
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("hide_focus_mode"):
		ui.hide_focus_mode()		

func show_spell_menu() -> void:
	if action_state != null:
		action_state.set_focus_menu_open(true)
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("show_spell_menu"):
		ui.show_spell_menu()

func hide_spell_menu() -> void:
	if action_state != null:
		action_state.set_focus_menu_open(false)
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("hide_spell_menu"):
		ui.hide_spell_menu()
