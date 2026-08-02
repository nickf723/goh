extends CanvasLayer
class_name RecordedObjectStatusHUD

const Catalog = preload("res://scripts/objects/recorded_object_catalog.gd")

var manager: RecordedObjectManager
var panel: PanelContainer
var title_label: Label
var state_label: Label
var detail_label: Label
var refresh_remaining: float = 0.0


func _ready() -> void:
	layer = 24
	add_to_group("recorded_object_status_hud")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_ui()
	call_deferred("_bind_manager")


func _process(delta: float) -> void:
	refresh_remaining = maxf(refresh_remaining - delta, 0.0)
	if refresh_remaining <= 0.0:
		refresh_remaining = 0.1
		_refresh()


func _bind_manager() -> void:
	manager = get_parent().get_node_or_null("RecordedObjectManager") as RecordedObjectManager
	if manager == null:
		manager = get_tree().get_first_node_in_group(
			"recorded_object_manager"
		) as RecordedObjectManager
	if manager == null:
		_refresh()
		return
	_connect_manager_signal("blueprint_selected", _on_blueprint_selected)
	_connect_manager_signal("placement_started", _on_placement_started)
	_connect_manager_signal("placement_updated", _on_placement_updated)
	_connect_manager_signal("placement_cancelled", _on_placement_cancelled)
	_connect_manager_signal("active_objects_changed", _on_active_objects_changed)
	_refresh()


func _connect_manager_signal(signal_name: StringName, callback: Callable) -> void:
	if manager.has_signal(signal_name) and not manager.is_connected(signal_name, callback):
		manager.connect(signal_name, callback)


func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.name = "RecordedObjectStatusPanel"
	panel.anchor_left = 1.0
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -380.0
	panel.offset_top = -172.0
	panel.offset_right = -22.0
	panel.offset_bottom = -22.0
	panel.add_to_group("menu_suppressed_hud")
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.028, 0.045, 0.92)
	style.border_color = Color(0.3, 0.72, 1.0, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(13)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 11)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 11)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	margin.add_child(stack)

	var eyebrow := Label.new()
	eyebrow.text = "RECORDED OBJECT"
	eyebrow.add_theme_font_size_override("font_size", 9)
	eyebrow.add_theme_color_override("font_color", Color(0.46, 0.8, 1.0, 1.0))
	stack.add_child(eyebrow)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0, 1.0))
	stack.add_child(title_label)

	state_label = Label.new()
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state_label.add_theme_font_size_override("font_size", 11)
	state_label.add_theme_color_override("font_color", Color(0.68, 0.82, 0.94, 1.0))
	stack.add_child(state_label)

	detail_label = Label.new()
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override("font_size", 9)
	detail_label.add_theme_color_override("font_color", Color(0.56, 0.66, 0.78, 1.0))
	stack.add_child(detail_label)
	panel.visible = false


func _refresh() -> void:
	if panel == null:
		return
	if manager == null or not is_instance_valid(manager):
		manager = get_tree().get_first_node_in_group(
			"recorded_object_manager"
		) as RecordedObjectManager
	var selected_id: String = Catalog.get_selected_blueprint_id()
	panel.visible = selected_id != "" and manager != null
	if not panel.visible:
		return
	var definition: Dictionary = Catalog.get_definition(selected_id)
	var debug: Dictionary = manager.get_debug_data()
	title_label.text = (
		str(definition.get("icon", "▣"))
		+ "  "
		+ str(definition.get("display_name", selected_id.capitalize()))
	)
	var placement_active: bool = bool(debug.get("placement_active", false))
	var placement_valid: bool = bool(debug.get("placement_valid", false))
	if placement_active:
		if placement_valid:
			state_label.text = "VALID POSITION • A / CLICK TO PLACE"
			state_label.add_theme_color_override("font_color", Color(0.46, 1.0, 0.66, 1.0))
		else:
			state_label.text = str(debug.get("invalid_reason", "That object cannot fit there."))
			state_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.34, 1.0))
	else:
		state_label.text = "V / Y PLACE  •  Q/E OR L/R CYCLE"
		state_label.add_theme_color_override("font_color", Color(0.68, 0.82, 0.94, 1.0))
	detail_label.text = (
		str(definition.get("mana_cost", 0))
		+ " mana  •  "
		+ str(manager.get_active_count(selected_id))
		+ "/"
		+ str(definition.get("maximum_active", 1))
		+ " active  •  R rotate  •  B / right-click cancel"
	)


func _on_blueprint_selected(_blueprint_id: String) -> void:
	_refresh()


func _on_placement_started(_blueprint_id: String) -> void:
	_refresh()


func _on_placement_updated(_position: Vector3, _valid: bool, _reason: String) -> void:
	_refresh()


func _on_placement_cancelled() -> void:
	_refresh()


func _on_active_objects_changed(_count: int) -> void:
	_refresh()


func get_debug_data() -> Dictionary:
	return {
		"manager_ready": manager != null and is_instance_valid(manager),
		"visible": panel != null and panel.visible,
		"selected_blueprint_id": Catalog.get_selected_blueprint_id(),
		"placement_active": manager.placement_active if manager != null else false,
	}
