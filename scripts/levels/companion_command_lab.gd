extends "res://scripts/levels/wildlife_navigation_rescue_lab.gd"
class_name CompanionCommandLab

const COMMAND_MARKER_POSITION: Vector3 = Vector3(12.8, 0.18, -8.6)

var command_status_label: Label


func _ready() -> void:
	super._ready()
	_build_command_marker()
	_build_command_overlay()


func _process(delta: float) -> void:
	super._process(delta)
	_update_command_status()


func get_command_marker_position() -> Vector3:
	return COMMAND_MARKER_POSITION


func command_follow() -> Dictionary:
	if animal == null:
		return {"ok": false, "error": "animal unavailable"}
	var result: Dictionary = animal.issue_follow_command()
	_show_message(
		"Follow command issued. Juniper will keep a loose companion distance."
		if bool(result.get("ok", false))
		else "Follow command failed: " + str(result.get("error", "unknown"))
	)
	return result


func command_stay_here() -> Dictionary:
	if animal == null:
		return {"ok": false, "error": "animal unavailable"}
	var result: Dictionary = animal.issue_stay_command(animal.global_position)
	_show_message(
		"Stay command issued. Juniper anchored at her current position."
		if bool(result.get("ok", false))
		else "Stay command failed: " + str(result.get("error", "unknown"))
	)
	return result


func command_come_here() -> Dictionary:
	if animal == null:
		return {"ok": false, "error": "animal unavailable"}
	var result: Dictionary = animal.issue_come_here_command()
	_show_message(
		"Come Here issued. Juniper will approach Grace, then resume her prior persistent mode."
		if bool(result.get("ok", false))
		else "Come Here failed: " + str(result.get("error", "unknown"))
	)
	return result


func command_go_to_marker() -> Dictionary:
	if animal == null:
		return {"ok": false, "error": "animal unavailable"}
	var result: Dictionary = animal.issue_move_to_command(COMMAND_MARKER_POSITION)
	_show_message(
		"Go There issued. Juniper will path to the cyan course marker and stay."
		if bool(result.get("ok", false))
		else "Go There failed: " + str(result.get("error", "unknown"))
	)
	return result


func trigger_command_fear() -> void:
	if animal == null:
		return
	animal.set_drive("fear", 1.0)
	if animal.relationship != null:
		animal.relationship.fear_association = maxf(animal.relationship.fear_association, 0.78)
		animal.relationship_label = animal.relationship.get_relationship_label(1.0)
	animal.refresh_command_authority()
	animal.force_decision(true)
	animal.persist_named_state(true)
	_show_message("Fear triggered. The current command is suspended but retained.")


func clear_command_fear() -> void:
	if animal == null:
		return
	animal.set_drive("fear", 0.0)
	if animal.relationship != null:
		animal.relationship.fear_association = minf(animal.relationship.fear_association, 0.12)
		animal.relationship.trust = maxf(animal.relationship.trust, 0.64)
		animal.relationship_label = animal.relationship.get_relationship_label(0.0)
	animal.refresh_command_authority()
	animal.force_decision(true)
	animal.persist_named_state(true)
	_show_message("Fear cleared. Juniper resumes the retained command.")


func toggle_follow() -> Dictionary:
	if animal == null:
		return {"ok": false, "error": "animal unavailable"}
	var command_data: Dictionary = animal.get_companion_command_data()
	if str(command_data.get("command_id", "none")) == animal.COMMAND_FOLLOW:
		return command_stay_here()
	return command_follow()


func _build_command_marker() -> void:
	var marker := Node3D.new()
	marker.name = "CommandCourseMarker"
	marker.position = COMMAND_MARKER_POSITION
	add_child(marker)
	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 0.85
	disc_mesh.bottom_radius = 0.85
	disc_mesh.height = 0.06
	disc.mesh = disc_mesh
	var disc_material := StandardMaterial3D.new()
	disc_material.albedo_color = Color(0.2, 0.84, 1.0, 0.7)
	disc_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_material.emission_enabled = true
	disc_material.emission = Color(0.12, 0.7, 1.0)
	disc_material.emission_energy_multiplier = 1.8
	disc.material_override = disc_material
	marker.add_child(disc)
	var light := OmniLight3D.new()
	light.light_color = Color(0.2, 0.84, 1.0)
	light.light_energy = 1.6
	light.omni_range = 3.5
	light.position.y = 0.7
	marker.add_child(light)
	var label := Label3D.new()
	label.text = "GO THERE MARKER"
	label.position = Vector3(0.0, 1.25, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 23
	label.pixel_size = 0.006
	label.outline_size = 8
	label.modulate = Color(0.42, 0.9, 1.0)
	marker.add_child(label)


func _build_command_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 36
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -425.0
	panel.offset_right = -18.0
	panel.offset_top = 72.0
	canvas.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.025, 0.06, 0.95)
	style.border_color = Color(0.65, 0.45, 0.96, 0.82)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	var title := Label.new()
	title.text = "COMPANION COMMAND AUTHORITY"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.86, 0.72, 1.0))
	box.add_child(title)
	command_status_label = Label.new()
	command_status_label.add_theme_font_size_override("font_size", 14)
	command_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(command_status_label)
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	_add_button(grid, "Follow", Callable(self, "command_follow"))
	_add_button(grid, "Stay Here", Callable(self, "command_stay_here"))
	_add_button(grid, "Come Here", Callable(self, "command_come_here"))
	_add_button(grid, "Go to Marker", Callable(self, "command_go_to_marker"))
	_add_button(grid, "Trigger Fear", Callable(self, "trigger_command_fear"))
	_add_button(grid, "Clear Fear", Callable(self, "clear_command_fear"))
	var hint := Label.new()
	hint.text = "Stay cancels an active follow immediately and owns an anchor. Fear interrupts movement without erasing the command. Come Here and Go There are one-shot commands that complete into Follow or Stay."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.72, 0.68, 0.82))
	box.add_child(hint)


func _update_command_status() -> void:
	if command_status_label == null or animal == null:
		return
	var data: Dictionary = animal.get_companion_command_data()
	var anchor_text: String = _short_vector(data.get("anchor", Vector3.ZERO) as Vector3) if bool(data.get("has_anchor", false)) else "none"
	var destination_text: String = _short_vector(data.get("destination", Vector3.ZERO) as Vector3) if bool(data.get("has_destination", false)) else "none"
	var suspend_text: String = (
		"YES • " + str(data.get("suspend_reason", "unknown"))
		if bool(data.get("suspended", false))
		else "NO"
	)
	command_status_label.text = (
		"Command: " + str(data.get("command_id", "none")).replace("_", " ").capitalize()
		+ "   Sequence " + str(data.get("sequence", 0))
		+ "\nSuspended: " + suspend_text
		+ "\nStay anchor: " + anchor_text
		+ "\nDestination: " + destination_text
		+ "\nLast completed: " + str(data.get("last_completed_command_id", "none")).replace("_", " ").capitalize()
		+ "   Count " + str(data.get("completion_count", 0))
	)


func _short_vector(value: Vector3) -> String:
	return (
		"(" + str(snappedf(value.x, 0.1))
		+ ", " + str(snappedf(value.y, 0.1))
		+ ", " + str(snappedf(value.z, 0.1)) + ")"
	)
