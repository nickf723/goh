extends "res://scripts/ui/full_menu_shell_loadout_v2_legacy.gd"

# Safety wrapper for every menu that inherits the geometry-based navigation
# layer. Some later shells rebuild their own content and tab rows instead of
# calling the v2 rebuild hooks, so cached Control references can outlive the
# buttons they once represented. Reconstruct the navigation graph from live
# metadata immediately before any geometric query.


func _select_action_from_screen_geometry(horizontal: int, vertical: int) -> bool:
	_sync_live_action_controls()
	if selectable_actions.is_empty() or action_controls.size() != selectable_actions.size():
		return false
	if horizontal == 0 and vertical == 0:
		return false

	selected_action_index = clampi(
		selected_action_index,
		0,
		selectable_actions.size() - 1
	)
	var current: Control = _get_live_control(action_controls[selected_action_index])
	if not _has_live_geometry(current):
		return false

	var direction: Vector2 = Vector2(float(horizontal), float(vertical)).normalized()
	var current_rect: Rect2 = current.get_global_rect()
	var current_center: Vector2 = current_rect.get_center()
	var best_index: int = -1
	var best_score: float = INF

	for index: int in range(action_controls.size()):
		if index == selected_action_index:
			continue
		var candidate: Control = _get_live_control(action_controls[index])
		if not _has_live_geometry(candidate):
			continue
		var candidate_rect: Rect2 = candidate.get_global_rect()
		var delta: Vector2 = candidate_rect.get_center() - current_center
		var projection: float = delta.dot(direction)
		if projection <= DIRECTION_MIN_PROJECTION:
			continue
		var distance: float = maxf(delta.length(), 0.001)
		var alignment: float = projection / distance
		if alignment < 0.18:
			continue
		var perpendicular: float = absf(
			delta.x * direction.y - delta.y * direction.x
		)
		var score: float = projection + perpendicular * 4.0
		if horizontal != 0 and absf(delta.y) <= maxf(
			current_rect.size.y,
			candidate_rect.size.y
		) * 0.62:
			score *= 0.18
		elif vertical != 0 and absf(delta.x) <= maxf(
			current_rect.size.x,
			candidate_rect.size.x
		) * 0.62:
			score *= 0.18
		if score < best_score:
			best_score = score
			best_index = index

	if best_index < 0:
		return false
	select_action(best_index)
	return true


func _activate_virtual_cursor_if_needed() -> void:
	if right_stick_vector.length() < CURSOR_DEADZONE:
		return
	_ensure_virtual_cursor()
	if virtual_cursor_active:
		return

	virtual_cursor_active = true
	virtual_cursor_layer.visible = true
	_sync_live_action_controls()
	var selected: Control = null
	if selected_action_index >= 0 and selected_action_index < action_controls.size():
		selected = _get_live_control(action_controls[selected_action_index])
	if _has_live_geometry(selected):
		virtual_cursor_position = selected.get_global_rect().get_center()
	else:
		virtual_cursor_position = get_viewport_rect().size * 0.5
	_position_virtual_cursor_label()


func _update_virtual_cursor_target() -> void:
	_sync_live_tab_controls()
	_sync_live_action_controls()
	virtual_cursor_tab_target = -1

	for index: int in range(tab_controls.size()):
		var tab: Control = _get_live_control(tab_controls[index])
		if _has_live_geometry(tab) and tab.get_global_rect().has_point(
			virtual_cursor_position
		):
			virtual_cursor_tab_target = index
			return

	for index: int in range(action_controls.size()):
		var control: Control = _get_live_control(action_controls[index])
		if not _has_live_geometry(control):
			continue
		if not control.get_global_rect().has_point(virtual_cursor_position):
			continue
		if index != selected_action_index:
			selected_action_index = index
			tab_action_memory[get_current_tab_id()] = selected_action_index
			rebuild_menu()
		return


func _sync_live_tab_controls() -> void:
	tab_controls.clear()
	if tab_box == null or not is_instance_valid(tab_box):
		return
	for child: Node in tab_box.get_children():
		if child is Button and is_instance_valid(child):
			tab_controls.append(child as Button)


func _sync_live_action_controls() -> void:
	action_controls.clear()
	for _index: int in range(selectable_actions.size()):
		action_controls.append(null)
	if content_box == null or not is_instance_valid(content_box):
		return
	_collect_live_action_controls(content_box)


func _collect_live_action_controls(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node is Control and node.has_meta("menu_action_index"):
		var action_index: int = int(node.get_meta("menu_action_index", -1))
		if action_index >= 0 and action_index < action_controls.size():
			action_controls[action_index] = node as Control
	for child: Node in node.get_children():
		_collect_live_action_controls(child)


func _get_live_control(value: Variant) -> Control:
	if value == null or not is_instance_valid(value):
		return null
	if not value is Control:
		return null
	return value as Control


func _has_live_geometry(value: Variant) -> bool:
	var control: Control = _get_live_control(value)
	return (
		control != null
		and control.is_visible_in_tree()
		and control.size.x > 2.0
		and control.size.y > 2.0
	)


func get_navigation_debug_data() -> Dictionary:
	_sync_live_tab_controls()
	_sync_live_action_controls()
	var data: Dictionary = super.get_navigation_debug_data()
	data["live_action_controls"] = _count_live_controls(action_controls)
	data["live_tab_controls"] = _count_live_controls(tab_controls)
	data["navigation_graph_synchronized"] = true
	return data


func _count_live_controls(values: Array) -> int:
	var count: int = 0
	for value: Variant in values:
		if _get_live_control(value) != null:
			count += 1
	return count
