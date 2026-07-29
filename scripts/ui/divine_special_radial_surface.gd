extends Control


var definitions: Array[DivineSpecialDefinition] = []
var selected_index: int = 0
var name_labels: Array[Label] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	queue_redraw()


func configure(
	new_definitions: Array[DivineSpecialDefinition],
	new_selected_index: int
) -> void:
	definitions = new_definitions.duplicate()
	selected_index = clampi(new_selected_index, 0, maxi(definitions.size() - 1, 0))
	_rebuild_labels()
	queue_redraw()


func set_selected_index(value: int) -> void:
	if definitions.is_empty():
		selected_index = 0
	else:
		selected_index = posmod(value, definitions.size())
	_refresh_label_styles()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_labels()
		queue_redraw()


func _draw() -> void:
	if definitions.is_empty():
		return
	var center: Vector2 = size * 0.5
	var outer_radius: float = minf(size.x, size.y) * 0.46
	var inner_radius: float = outer_radius * 0.34
	var sector_angle: float = TAU / float(definitions.size())
	var arc_steps: int = 24

	for definition_index: int in range(definitions.size()):
		var center_angle: float = -PI * 0.5 + sector_angle * float(definition_index)
		var start_angle: float = center_angle - sector_angle * 0.5
		var end_angle: float = center_angle + sector_angle * 0.5
		var polygon: PackedVector2Array = PackedVector2Array([center])
		for step_index: int in range(arc_steps + 1):
			var ratio: float = float(step_index) / float(arc_steps)
			var angle: float = lerpf(start_angle, end_angle, ratio)
			polygon.append(
				center + Vector2(cos(angle), sin(angle)) * outer_radius
			)
		var is_selected: bool = definition_index == selected_index
		var fill_color: Color = (
			Color(1.0, 0.24, 0.035, 0.94)
			if is_selected
			else Color(0.055, 0.026, 0.025, 0.92)
		)
		draw_colored_polygon(polygon, fill_color)
		var border_color: Color = (
			Color(1.0, 0.82, 0.2, 1.0)
			if is_selected
			else Color(0.72, 0.22, 0.08, 0.64)
		)
		draw_arc(
			center,
			outer_radius,
			start_angle,
			end_angle,
			arc_steps,
			border_color,
			3.0 if is_selected else 1.5,
			true
		)
		for boundary_angle: float in [start_angle, end_angle]:
			draw_line(
				center + Vector2(cos(boundary_angle), sin(boundary_angle)) * inner_radius,
				center + Vector2(cos(boundary_angle), sin(boundary_angle)) * outer_radius,
				border_color,
				2.0 if is_selected else 1.0,
				true
			)

	draw_circle(center, inner_radius, Color(0.018, 0.012, 0.014, 0.98))
	draw_arc(
		center,
		inner_radius,
		0.0,
		TAU,
		64,
		Color(1.0, 0.46, 0.08, 0.76),
		2.0,
		true
	)


func _rebuild_labels() -> void:
	for label: Label in name_labels:
		if is_instance_valid(label):
			label.queue_free()
	name_labels.clear()
	for definition: DivineSpecialDefinition in definitions:
		var label: Label = Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = definition.display_name.to_upper()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 17)
		label.add_theme_constant_override("outline_size", 5)
		label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.01, 0.96))
		add_child(label)
		name_labels.append(label)
	_layout_labels()
	_refresh_label_styles()


func _layout_labels() -> void:
	if definitions.is_empty():
		return
	var center: Vector2 = size * 0.5
	var outer_radius: float = minf(size.x, size.y) * 0.46
	var label_radius: float = outer_radius * 0.69
	var label_size: Vector2 = Vector2(220.0, 76.0)
	var sector_angle: float = TAU / float(definitions.size())
	for definition_index: int in range(name_labels.size()):
		var angle: float = -PI * 0.5 + sector_angle * float(definition_index)
		var label: Label = name_labels[definition_index]
		label.position = (
			center
			+ Vector2(cos(angle), sin(angle)) * label_radius
			- label_size * 0.5
		)
		label.size = label_size


func _refresh_label_styles() -> void:
	for label_index: int in range(name_labels.size()):
		var label: Label = name_labels[label_index]
		var is_selected: bool = label_index == selected_index
		label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.92, 0.62, 1.0)
			if is_selected
			else Color(0.92, 0.78, 0.7, 0.86)
		)
		label.add_theme_font_size_override(
			"font_size",
			20 if is_selected else 17
		)
