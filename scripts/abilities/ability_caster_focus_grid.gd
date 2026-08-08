extends "res://scripts/abilities/ability_caster_player_channels.gd"
class_name AbilityCasterFocusGrid

const FocusGridRouterScript = preload(
	"res://scripts/input/player_control_router_focus_grid.gd"
)
const FocusGridLayoutScript = preload(
	"res://scripts/ui/focus_grid_layout.gd"
)
const FLASH_SPELL_ID: String = "flash"

const FOCUS_PAGE_ELEMENTS: String = "elements"
const FOCUS_PAGE_SPELLS: String = "spells"

var focus_grid_page: String = FOCUS_PAGE_ELEMENTS
var focus_spell_memory: Dictionary = {}


func _ready() -> void:
	super._ready()
	var tree: SceneTree = get_tree()
	if tree != null:
		var callback := Callable(self, "_on_tree_node_added")
		if not tree.node_added.is_connected(callback):
			tree.node_added.connect(callback)
	call_deferred("_ensure_focus_safe_router")


func _exit_tree() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var callback := Callable(self, "_on_tree_node_added")
	if tree.node_added.is_connected(callback):
		tree.node_added.disconnect(callback)


func _on_tree_node_added(node: Node) -> void:
	if node == null or str(node.name) != "PlayerControlRouter":
		return
	var actor: Node = get_parent()
	if actor == null or node.get_parent() != actor:
		return
	call_deferred("_ensure_focus_safe_router")


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


func _rebind_router_consumers(router: Node) -> void:
	if router == null or not is_instance_valid(router):
		return
	var actor: Node = get_parent()
	if actor == null or not is_instance_valid(actor):
		return
	var command_dock: Node = actor.get_node_or_null("QuickSpellBeltPresentation")
	if command_dock == null or not is_instance_valid(command_dock):
		return
	command_dock.set("router", router)
	if command_dock.has_method("_connect_runtime_signals"):
		command_dock.call("_connect_runtime_signals")
	if command_dock.has_method("_mark_slots_dirty"):
		command_dock.call("_mark_slots_dirty")


func get_cast_direction(player: Node3D, cast_origin: Vector3) -> Vector3:
	var ability: AbilityDefinition = get_current_ability()
	if ability != null and ability.get_spell_id() == FLASH_SPELL_ID:
		return _get_flash_camera_direction(player)
	return super.get_cast_direction(player, cast_origin)


func _get_flash_camera_direction(player: Node3D) -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		var viewport_rect: Rect2 = camera.get_viewport().get_visible_rect()
		var screen_center: Vector2 = viewport_rect.position + viewport_rect.size * 0.5
		var ray_direction: Vector3 = camera.project_ray_normal(screen_center)
		if ray_direction.length_squared() > 0.0001:
			return ray_direction.normalized()
	if player != null:
		var fallback: Vector3 = -player.global_transform.basis.z
		if fallback.length_squared() > 0.0001:
			return fallback.normalized()
	return Vector3.FORWARD


func get_focus_library_abilities() -> Array[AbilityDefinition]:
	if loadout == null:
		return []
	return loadout.get_learned_abilities()


func get_focus_abilities_for_element(element: String) -> Array[AbilityDefinition]:
	var abilities: Array[AbilityDefinition] = []
	for ability: AbilityDefinition in get_focus_library_abilities():
		if ability != null and ability.element == element:
			abilities.append(ability)
	return abilities


func get_spell_indices_for_element(element: String) -> Array[int]:
	var indices: Array[int] = []
	var learned: Array[AbilityDefinition] = get_focus_library_abilities()
	for ability_index: int in range(learned.size()):
		var ability: AbilityDefinition = learned[ability_index]
		if ability != null and ability.element == element:
			indices.append(ability_index)
	return indices


func _get_selected_focus_library_index() -> int:
	var spell_indices: Array[int] = get_spell_indices_for_element(get_selected_focus_element())
	if spell_indices.is_empty():
		return -1
	focus_spell_index = clampi(focus_spell_index, 0, spell_indices.size() - 1)
	return spell_indices[focus_spell_index]


func get_selected_focus_spell_global_index() -> int:
	return _ensure_runtime_ability(get_selected_focus_ability())


func get_selected_focus_ability() -> AbilityDefinition:
	var selected_index: int = _get_selected_focus_library_index()
	var learned: Array[AbilityDefinition] = get_focus_library_abilities()
	if selected_index < 0 or selected_index >= learned.size():
		return null
	return learned[selected_index]


func get_focus_spell_names_for_element(element: String) -> Array[String]:
	var names: Array[String] = []
	for ability: AbilityDefinition in get_focus_abilities_for_element(element):
		names.append(ability.display_name)
	return names


func align_focus_menu_to_current_ability() -> void:
	var ability: AbilityDefinition = get_current_ability()
	if ability == null:
		return
	var element_index: int = get_element_index(ability.element)
	if element_index < 0:
		return
	focus_element_index = element_index
	var element_abilities: Array[AbilityDefinition] = get_focus_abilities_for_element(ability.element)
	focus_spell_index = 0
	var spell_id: String = ability.get_spell_id()
	for local_index: int in range(element_abilities.size()):
		var candidate: AbilityDefinition = element_abilities[local_index]
		if candidate != null and candidate.get_spell_id() == spell_id:
			focus_spell_index = local_index
			break
	_remember_current_spell_index()


func select_focus_spell_by_id(spell_id: String) -> bool:
	var normalized: String = spell_id.strip_edges().to_lower()
	if normalized == "":
		return false
	var learned: Array[AbilityDefinition] = get_focus_library_abilities()
	for ability: AbilityDefinition in learned:
		if ability == null or ability.get_spell_id() != normalized:
			continue
		var element_index: int = get_element_index(ability.element)
		if element_index < 0:
			return false
		focus_element_index = element_index
		var element_abilities: Array[AbilityDefinition] = get_focus_abilities_for_element(ability.element)
		focus_spell_index = element_abilities.find(ability)
		if focus_spell_index < 0:
			focus_spell_index = 0
		_remember_current_spell_index()
		update_focus_spell_menu_ui()
		return true
	return false


func confirm_focus_spell_menu() -> void:
	if not _select_current_focus_ability(true):
		show_feedback(
			"No learned "
			+ get_selected_focus_element_display_name()
			+ " spells yet."
		)
	update_focus_spell_menu_ui()


func equip_selected_focus_spell_and_close() -> void:
	if not _select_current_focus_ability(true):
		show_feedback(
			"No learned "
			+ get_selected_focus_element_display_name()
			+ " spells yet."
		)
		update_focus_spell_menu_ui()
		return
	close_focus_spell_menu()


func quick_cast_selected_focus_spell() -> void:
	if not _select_current_focus_ability(false):
		show_feedback(
			"No learned "
			+ get_selected_focus_element_display_name()
			+ " spells yet."
		)
		update_focus_spell_menu_ui()
		return
	var player: Node3D = get_focus_player()
	if player == null:
		show_feedback("No player found for quick-cast.")
		update_focus_spell_menu_ui()
		return
	cast_from_player(player, focus_quick_cast_lock_duration, false)
	update_focus_spell_menu_ui()


func _select_current_focus_ability(should_show_feedback: bool) -> bool:
	var ability: AbilityDefinition = get_selected_focus_ability()
	if ability == null or loadout == null:
		return false
	var runtime_index: int = _ensure_runtime_ability(ability)
	if runtime_index < 0:
		return false
	select_ability(runtime_index, should_show_feedback)
	return true


func _ensure_runtime_ability(ability: AbilityDefinition) -> int:
	if ability == null or loadout == null:
		return -1
	var spell_id: String = ability.get_spell_id()
	for ability_index: int in range(loadout.equipped_abilities.size()):
		var candidate: AbilityDefinition = loadout.equipped_abilities[ability_index]
		if candidate != null and candidate.get_spell_id() == spell_id:
			return ability_index
	loadout.equipped_abilities.append(ability)
	return loadout.equipped_abilities.size() - 1


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
	if not focus_spell_menu_open or (delta_x == 0 and delta_y == 0):
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

	var spell_count: int = get_focus_abilities_for_element(get_selected_focus_element()).size()
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
	var selected_element: String = get_selected_focus_element()
	var selected_ability: AbilityDefinition = get_selected_focus_ability()
	var spell_count: int = get_focus_abilities_for_element(selected_element).size()
	return {
		"groups": ELEMENT_GROUPS,
		"element_order": ELEMENT_ORDER,
		"selected_element": selected_element,
		"selected_element_name": get_element_display_name(selected_element),
		"selected_spell_index": focus_spell_index,
		"selected_spell_name": (
			selected_ability.display_name if selected_ability != null else "None"
		),
		"selected_spell_id": (
			selected_ability.get_spell_id() if selected_ability != null else ""
		),
		"spell_names": get_focus_spell_names_for_element(selected_element),
		"current_ability_name": get_current_ability_name(),
		"current_ability_index": current_ability_index,
		"library_source": "learned_abilities",
		"quickbar_independent": true,
		"focus_page": focus_grid_page,
		"element_grid_columns": 4,
		"spell_grid_columns": 3,
		"spell_grid_center": 4,
		"spell_grid_slots": FocusGridLayoutScript.get_spell_slots(spell_count),
	}


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	var selected: AbilityDefinition = get_selected_focus_ability()
	data["focus_library_source"] = "learned_abilities"
	data["focus_quickbar_independent"] = true
	data["focus_learned_count"] = get_focus_library_abilities().size()
	data["focus_selected_spell_id"] = (
		selected.get_spell_id() if selected != null else ""
	)
	data["focus_selected_runtime_index"] = _ensure_runtime_ability(selected)
	data["focus_safe_router"] = true
	data["flash_direction_authority"] = "camera_ray"
	data["flash_preserves_vertical_aim"] = true
	data["focus_grid_page"] = focus_grid_page
	data["focus_grid_two_state"] = true
	data["focus_element_columns"] = 4
	data["focus_spell_columns"] = 3
	return data
