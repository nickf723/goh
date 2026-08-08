extends "res://scripts/abilities/ability_caster_focus_library.gd"
class_name AbilityCasterFocusGrid

const FocusGridRouterScript = preload(
	"res://scripts/input/player_control_router_focus_grid.gd"
)
const FocusGridLayoutScript = preload(
	"res://scripts/ui/focus_grid_layout.gd"
)

const FOCUS_PAGE_ELEMENTS: String = "elements"
const FOCUS_PAGE_SPELLS: String = "spells"

var focus_grid_page: String = FOCUS_PAGE_ELEMENTS
var focus_spell_memory: Dictionary = {}


func _ensure_focus_safe_router() -> void:
	var actor: Node = get_parent()
	if actor == null or not is_instance_valid(actor):
		return
	var existing: Node = actor.get_node_or_null("PlayerControlRouter")
	if existing != null:
		var existing_script: Script = existing.get_script() as Script
		if (
			existing_script != null
			and existing_script.resource_path
			== "res://scripts/input/player_control_router_focus_grid.gd"
		):
			_rebind_router_consumers(existing)
			return
		actor.remove_child(existing)
		existing.queue_free()
	var router: Node = FocusGridRouterScript.new()
	router.name = "PlayerControlRouter"
	actor.add_child(router)
	call_deferred("_rebind_router_consumers", router)


func open_focus_spell_menu() -> void:
	if focus_spell_menu_open:
		update_focus_spell_menu_ui()
		return
	focus_grid_page = FOCUS_PAGE_ELEMENTS
	super.open_focus_spell_menu()


func close_focus_spell_menu() -> void:
	if focus_grid_page == FOCUS_PAGE_SPELLS:
		_remember_current_spell_index()
	super.close_focus_spell_menu()
	focus_grid_page = FOCUS_PAGE_ELEMENTS


func is_focus_spell_grid_active() -> bool:
	return focus_spell_menu_open and focus_grid_page == FOCUS_PAGE_SPELLS


func get_focus_grid_page() -> String:
	return focus_grid_page


func navigate_focus_grid(delta_x: int, delta_y: int) -> void:
	if not focus_spell_menu_open:
		return
	if delta_x == 0 and delta_y == 0:
		return

	if focus_grid_page == FOCUS_PAGE_ELEMENTS:
		focus_element_index = FocusGridLayoutScript.move_element_index(
			focus_element_index,
			delta_x,
			delta_y,
			ELEMENT_ORDER.size()
		)
		_restore_spell_memory_for_selected_element()
		update_focus_spell_menu_ui()
		return

	var spell_count: int = get_focus_abilities_for_element(
		get_selected_focus_element()
	).size()
	if spell_count <= 0:
		focus_spell_index = 0
		update_focus_spell_menu_ui()
		return
	focus_spell_index = FocusGridLayoutScript.find_directional_spell_index(
		focus_spell_index,
		spell_count,
		delta_x,
		delta_y
	)
	_remember_current_spell_index()
	update_focus_spell_menu_ui()


func enter_focus_spell_grid() -> void:
	if not focus_spell_menu_open:
		return
	focus_grid_page = FOCUS_PAGE_SPELLS
	_restore_spell_memory_for_selected_element()
	update_focus_spell_menu_ui()


func return_to_focus_element_grid() -> void:
	if not focus_spell_menu_open:
		return
	_remember_current_spell_index()
	focus_grid_page = FOCUS_PAGE_ELEMENTS
	update_focus_spell_menu_ui()


func handle_focus_menu_input(event: InputEvent) -> bool:
	if is_ground_targeting():
		return super.handle_focus_menu_input(event)
	if not focus_spell_menu_open:
		return false

	if (
		event.is_action_pressed("cast_spell")
		or event.is_action_pressed("ui_accept")
		or event.is_action_pressed("interact")
	):
		_activate_focus_grid_selection()
		return true

	if event.is_action_pressed("ui_cancel"):
		_back_focus_grid()
		return true

	if event.is_action_pressed("focus_element_left"):
		navigate_focus_grid(-1, 0)
		return true
	if event.is_action_pressed("focus_element_right"):
		navigate_focus_grid(1, 0)
		return true
	if event.is_action_pressed("focus_spell_up"):
		navigate_focus_grid(0, -1)
		return true
	if event.is_action_pressed("focus_spell_down"):
		navigate_focus_grid(0, 1)
		return true

	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return true
		match key_event.keycode:
			KEY_LEFT:
				navigate_focus_grid(-1, 0)
			KEY_RIGHT:
				navigate_focus_grid(1, 0)
			KEY_UP:
				navigate_focus_grid(0, -1)
			KEY_DOWN:
				navigate_focus_grid(0, 1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_activate_focus_grid_selection()
			KEY_ESCAPE, KEY_BACKSPACE:
				_back_focus_grid()
			_:
				pass
		return true

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if not mouse_event.pressed:
			return true
		match mouse_event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				navigate_focus_grid(0, -1)
			MOUSE_BUTTON_WHEEL_DOWN:
				navigate_focus_grid(0, 1)
			MOUSE_BUTTON_LEFT:
				_activate_focus_grid_selection()
			MOUSE_BUTTON_RIGHT:
				_back_focus_grid()
			_:
				pass
		return true

	return true


func _activate_focus_grid_selection() -> void:
	if focus_grid_page == FOCUS_PAGE_ELEMENTS:
		enter_focus_spell_grid()
		return
	var ability: AbilityDefinition = get_selected_focus_ability()
	if ability == null:
		show_feedback(
			"No learned "
			+ get_selected_focus_element_display_name()
			+ " spells yet."
		)
		return
	_remember_current_spell_index()
	equip_selected_focus_spell_and_close()


func _back_focus_grid() -> void:
	if focus_grid_page == FOCUS_PAGE_SPELLS:
		return_to_focus_element_grid()
		return
	close_focus_spell_menu()


func _remember_current_spell_index() -> void:
	var element: String = get_selected_focus_element()
	if element == "":
		return
	var count: int = get_focus_abilities_for_element(element).size()
	focus_spell_memory[element] = (
		clampi(focus_spell_index, 0, count - 1)
		if count > 0
		else 0
	)


func _restore_spell_memory_for_selected_element() -> void:
	var element: String = get_selected_focus_element()
	var count: int = get_focus_abilities_for_element(element).size()
	if count <= 0:
		focus_spell_index = 0
		return
	focus_spell_index = clampi(
		int(focus_spell_memory.get(element, 0)),
		0,
		count - 1
	)


func get_focus_menu_data() -> Dictionary:
	var data: Dictionary = super.get_focus_menu_data()
	var spell_count: int = get_focus_abilities_for_element(
		get_selected_focus_element()
	).size()
	data["focus_page"] = focus_grid_page
	data["element_grid_columns"] = 4
	data["spell_grid_columns"] = 3
	data["spell_grid_center"] = 4
	data["spell_grid_slots"] = FocusGridLayoutScript.get_spell_slots(spell_count)
	return data


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["focus_grid_page"] = focus_grid_page
	data["focus_grid_two_state"] = true
	data["focus_element_columns"] = 4
	data["focus_spell_columns"] = 3
	return data
