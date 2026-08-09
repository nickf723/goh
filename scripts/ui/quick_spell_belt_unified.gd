extends "res://scripts/ui/quick_spell_belt_performance.gd"
class_name QuickSpellBeltUnified

const GENERATED_SURFACE_NAMES: Array[String] = [
	"PermanentDPadCommandDock",
	"DPadUpItemMenu",
	"DPadDownSpecialMenu",
]

var unified_layout_applied: bool = false
var retired_duplicate_surface_count: int = 0
var duplicate_surface_sweep_count: int = 0
var duplicate_surface_node_checks: int = 0
var duplicate_surface_listener_connected: bool = false
var mode_property_write_count: int = 0


func _finish_setup() -> void:
	super._finish_setup()
	if not setup_complete:
		return
	_apply_unified_layout()
	_connect_duplicate_surface_listener()
	# One bounded startup sweep catches surfaces that existed before this
	# presenter finished binding. Anything created later is handled by node_added.
	_retire_duplicate_generated_surfaces()


func _exit_tree() -> void:
	super._exit_tree()
	_disconnect_duplicate_surface_listener()


func _process(delta: float) -> void:
	super._process(delta)
	if not unified_layout_applied:
		_apply_unified_layout()
	# Duplicate retirement used to recursively search the complete HUD tree three
	# times every frame. In a growing scene that became a major idle-process cost.
	# Late surfaces are now caught once through SceneTree.node_added instead.
	_apply_mode_presentation()


func _build_command_dock() -> void:
	super._build_command_dock()
	_apply_unified_layout()


func _build_item_menu() -> void:
	super._build_item_menu()
	_apply_unified_layout()


func _build_special_menu() -> void:
	super._build_special_menu()
	_apply_unified_layout()


func _apply_unified_layout() -> void:
	if hud == null or dock_panel == null:
		return
	_retire_duplicate_generated_surfaces()
	var target_parent: Control = hud.root
	if hud.has_method("get_hud_zone"):
		var zone_value: Variant = hud.call("get_hud_zone", "action_bar")
		if zone_value is Control:
			target_parent = zone_value as Control
	if dock_panel.get_parent() != target_parent:
		dock_panel.reparent(target_parent)
	dock_panel.anchor_left = 0.5
	dock_panel.anchor_top = 1.0
	dock_panel.anchor_right = 0.5
	dock_panel.anchor_bottom = 1.0
	dock_panel.offset_left = -510.0
	dock_panel.offset_top = -124.0
	dock_panel.offset_right = 510.0
	dock_panel.offset_bottom = -16.0
	dock_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.006, 0.013, 0.024, 0.96),
			Color(0.3, 0.5, 0.78, 0.68),
			15,
			2
		)
	)
	if item_tile != null:
		item_tile.custom_minimum_size = Vector2(142.0, 78.0)
	if special_tile != null:
		special_tile.custom_minimum_size = Vector2(142.0, 78.0)
	var spell_section: Control = dock_panel.find_child(
		"TenSpellSection",
		true,
		false
	) as Control
	if spell_section != null:
		spell_section.custom_minimum_size = Vector2(680.0, 78.0)
	for panel: PanelContainer in slot_panels:
		panel.custom_minimum_size = Vector2(62.0, 53.0)
	for label: Label in slot_labels:
		label.add_theme_font_size_override("font_size", 8)
	if belt_hint_label != null:
		belt_hint_label.add_theme_font_size_override("font_size", 8)
	if item_menu_panel != null:
		_reparent_overlay_to_hud(item_menu_panel)
		item_menu_panel.offset_left = -510.0
		item_menu_panel.offset_top = -342.0
		item_menu_panel.offset_right = -344.0
		item_menu_panel.offset_bottom = -134.0
	if special_menu_panel != null:
		_reparent_overlay_to_hud(special_menu_panel)
		special_menu_panel.offset_left = 344.0
		special_menu_panel.offset_top = -342.0
		special_menu_panel.offset_right = 510.0
		special_menu_panel.offset_bottom = -134.0
	unified_layout_applied = true
	_align_focus_panel()


func _connect_duplicate_surface_listener() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var callback := Callable(self, "_on_tree_node_added")
	if not tree.node_added.is_connected(callback):
		tree.node_added.connect(callback)
	duplicate_surface_listener_connected = true


func _disconnect_duplicate_surface_listener() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var callback := Callable(self, "_on_tree_node_added")
	if tree.node_added.is_connected(callback):
		tree.node_added.disconnect(callback)
	duplicate_surface_listener_connected = false


func _on_tree_node_added(node: Node) -> void:
	if not setup_complete or node == null:
		return
	if not GENERATED_SURFACE_NAMES.has(str(node.name)):
		return
	duplicate_surface_node_checks += 1
	# Installers commonly assign their authoritative member reference in the same
	# frame they add the Control. Defer the comparison so the new current surface
	# is never mistaken for an orphan.
	call_deferred("_retire_duplicate_surface_candidate", node)


func _retire_duplicate_surface_candidate(candidate: Node) -> void:
	if candidate == null or not is_instance_valid(candidate):
		return
	if hud == null or hud.root == null or not hud.root.is_ancestor_of(candidate):
		return
	var current_surface: Control = _get_current_surface(str(candidate.name))
	if candidate == current_surface:
		return
	var parent: Node = candidate.get_parent()
	if parent != null:
		parent.remove_child(candidate)
	candidate.queue_free()
	retired_duplicate_surface_count += 1


func _get_current_surface(surface_name: String) -> Control:
	match surface_name:
		"PermanentDPadCommandDock":
			return dock_panel
		"DPadUpItemMenu":
			return item_menu_panel
		"DPadDownSpecialMenu":
			return special_menu_panel
		_:
			return null


func _retire_duplicate_generated_surfaces() -> void:
	if hud == null or hud.root == null:
		return
	duplicate_surface_sweep_count += 1
	_retire_duplicate_surface("PermanentDPadCommandDock", dock_panel)
	_retire_duplicate_surface("DPadUpItemMenu", item_menu_panel)
	_retire_duplicate_surface("DPadDownSpecialMenu", special_menu_panel)


func _retire_duplicate_surface(surface_name: String, current_surface: Control) -> void:
	if hud == null or hud.root == null:
		return
	for candidate: Node in hud.root.find_children(surface_name, "", true, false):
		if candidate == current_surface:
			continue
		var parent: Node = candidate.get_parent()
		if parent != null:
			parent.remove_child(candidate)
		candidate.queue_free()
		retired_duplicate_surface_count += 1


func _generated_dock_debug_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if hud == null or hud.root == null:
		return rows
	for candidate: Node in hud.root.find_children(
		"PermanentDPadCommandDock",
		"",
		true,
		false
	):
		var row: Dictionary = {
			"path": str(candidate.get_path()),
			"current": candidate == dock_panel,
			"class": candidate.get_class(),
		}
		if candidate is Control:
			var control: Control = candidate as Control
			row["visible"] = control.visible
			row["alpha"] = control.modulate.a
			row["rect"] = control.get_global_rect()
		rows.append(row)
	return rows


func _reparent_overlay_to_hud(panel: PanelContainer) -> void:
	if hud == null or hud.root == null or panel == null:
		return
	if panel.get_parent() != hud.root:
		panel.reparent(hud.root)


func _apply_mode_presentation() -> void:
	if hud == null or not hud.has_method("get_hud_mode"):
		return
	var mode_id: String = str(hud.call("get_hud_mode"))
	var placement: bool = mode_id == "placement"
	var modal: bool = mode_id in ["focus", "ability_context", "dialogue"]
	if item_menu_panel != null and (placement or modal) and item_menu_panel.visible:
		item_menu_panel.visible = false
		mode_property_write_count += 1
	if special_menu_panel != null and (placement or modal) and special_menu_panel.visible:
		special_menu_panel.visible = false
		mode_property_write_count += 1
	if dock_panel != null:
		var desired_alpha: float = 0.34 if placement else (0.62 if modal else 1.0)
		if not is_equal_approx(dock_panel.modulate.a, desired_alpha):
			dock_panel.modulate.a = desired_alpha
			last_dock_alpha = desired_alpha
			mode_property_write_count += 1
	if item_tile != null and item_tile.visible == placement:
		item_tile.visible = not placement
		mode_property_write_count += 1
	if special_tile != null and special_tile.visible == placement:
		special_tile.visible = not placement
		mode_property_write_count += 1


func _align_focus_panel() -> void:
	if game_ui == null:
		return
	var panel_value: Variant = game_ui.get("focus_spell_panel")
	if not panel_value is Control:
		return
	var panel: Control = panel_value as Control
	var half_width: float = 420.0 * dock_scale
	panel.anchor_left = 0.5
	panel.anchor_top = 1.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -half_width
	panel.offset_top = -426.0
	panel.offset_right = half_width
	panel.offset_bottom = -136.0


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	var dock_rows: Array[Dictionary] = _generated_dock_debug_rows()
	var visible_docks: int = 0
	for row: Dictionary in dock_rows:
		if bool(row.get("visible", false)) and float(row.get("alpha", 0.0)) > 0.01:
			visible_docks += 1
	data["unified_layout"] = unified_layout_applied
	data["dock_parent_zone"] = (
		str(dock_panel.get_parent().name)
		if dock_panel != null and dock_panel.get_parent() != null
		else "none"
	)
	data["retired_duplicate_surfaces"] = retired_duplicate_surface_count
	data["duplicate_surface_sweeps"] = duplicate_surface_sweep_count
	data["duplicate_surface_node_checks"] = duplicate_surface_node_checks
	data["duplicate_surface_listener"] = duplicate_surface_listener_connected
	data["per_frame_duplicate_tree_scan"] = false
	data["mode_property_writes"] = mode_property_write_count
	data["generated_dock_rows"] = dock_rows
	data["visible_generated_docks"] = visible_docks
	return data
