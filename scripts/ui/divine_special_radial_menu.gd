extends CanvasLayer


const RadialSurfaceScript = preload(
	"res://scripts/ui/divine_special_radial_surface.gd"
)

var definitions: Array[DivineSpecialDefinition] = []
var selected_index: int = 0
var active_device: int = -1
var menu_open: bool = false

var root: Control
var radial_surface: Control
var patron_label: Label
var selected_label: Label
var description_label: Label
var footer_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 34
	_build_menu()
	add_to_group("divine_special_radial_menu")


func open_menu(
	new_definitions: Array[DivineSpecialDefinition],
	new_selected_index: int,
	device: int
) -> void:
	definitions = new_definitions.duplicate()
	if definitions.is_empty():
		close_menu()
		return
	selected_index = posmod(new_selected_index, definitions.size())
	active_device = device
	menu_open = true
	root.visible = true
	radial_surface.call("configure", definitions, selected_index)
	footer_label.text = _build_controller_hint(device)
	_update_center_copy()


func close_menu() -> void:
	menu_open = false
	active_device = -1
	if root != null:
		root.visible = false


func set_selection(value: int) -> void:
	if definitions.is_empty():
		return
	selected_index = posmod(value, definitions.size())
	radial_surface.call("set_selected_index", selected_index)
	_update_center_copy()


func get_selected_index() -> int:
	return selected_index


func is_menu_open() -> bool:
	return menu_open


func _build_menu() -> void:
	root = Control.new()
	root.name = "DivineSpecialRadialRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 0.0
	root.offset_top = 0.0
	root.offset_right = 0.0
	root.offset_bottom = 0.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	add_child(root)

	var dimmer: ColorRect = ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.offset_left = 0.0
	dimmer.offset_top = 0.0
	dimmer.offset_right = 0.0
	dimmer.offset_bottom = 0.0
	dimmer.color = Color(0.012, 0.006, 0.009, 0.68)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dimmer)

	var header: Label = Label.new()
	header.name = "Header"
	header.set_anchors_preset(Control.PRESET_CENTER_TOP)
	header.offset_left = -300.0
	header.offset_top = 34.0
	header.offset_right = 300.0
	header.offset_bottom = 78.0
	header.text = "DIVINE SPECIALS"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 25)
	header.add_theme_constant_override("outline_size", 7)
	header.add_theme_color_override("font_color", Color(1.0, 0.73, 0.22, 1.0))
	header.add_theme_color_override("font_outline_color", Color(0.02, 0.008, 0.006, 0.98))
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(header)

	radial_surface = RadialSurfaceScript.new() as Control
	radial_surface.name = "RadialSurface"
	radial_surface.set_anchors_preset(Control.PRESET_CENTER)
	radial_surface.offset_left = -360.0
	radial_surface.offset_top = -360.0
	radial_surface.offset_right = 360.0
	radial_surface.offset_bottom = 360.0
	radial_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(radial_surface)

	var center_panel: PanelContainer = PanelContainer.new()
	center_panel.name = "CenterPanel"
	center_panel.set_anchors_preset(Control.PRESET_CENTER)
	center_panel.offset_left = -148.0
	center_panel.offset_top = -94.0
	center_panel.offset_right = 148.0
	center_panel.offset_bottom = 94.0
	center_panel.add_theme_stylebox_override("panel", _make_center_style())
	center_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center_panel)

	var center_margin: MarginContainer = MarginContainer.new()
	center_margin.add_theme_constant_override("margin_left", 16)
	center_margin.add_theme_constant_override("margin_right", 16)
	center_margin.add_theme_constant_override("margin_top", 14)
	center_margin.add_theme_constant_override("margin_bottom", 14)
	center_panel.add_child(center_margin)

	var center_stack: VBoxContainer = VBoxContainer.new()
	center_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	center_stack.add_theme_constant_override("separation", 4)
	center_margin.add_child(center_stack)

	patron_label = Label.new()
	patron_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	patron_label.add_theme_font_size_override("font_size", 12)
	patron_label.add_theme_color_override("font_color", Color(1.0, 0.48, 0.1, 0.9))
	center_stack.add_child(patron_label)

	selected_label = Label.new()
	selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_label.add_theme_font_size_override("font_size", 19)
	selected_label.add_theme_constant_override("outline_size", 4)
	selected_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.94))
	center_stack.add_child(selected_label)

	description_label = Label.new()
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 10)
	description_label.add_theme_color_override("font_color", Color(0.9, 0.78, 0.7, 0.82))
	center_stack.add_child(description_label)

	footer_label = Label.new()
	footer_label.name = "Footer"
	footer_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	footer_label.offset_left = -430.0
	footer_label.offset_top = -82.0
	footer_label.offset_right = 430.0
	footer_label.offset_bottom = -34.0
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer_label.add_theme_font_size_override("font_size", 14)
	footer_label.add_theme_constant_override("outline_size", 5)
	footer_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.48, 0.96))
	footer_label.add_theme_color_override("font_outline_color", Color(0.02, 0.008, 0.006, 0.98))
	footer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(footer_label)


func _update_center_copy() -> void:
	if definitions.is_empty():
		patron_label.text = ""
		selected_label.text = "NO SPECIALS"
		description_label.text = ""
		return
	var definition: DivineSpecialDefinition = definitions[selected_index]
	patron_label.text = definition.patron_id.to_upper() + " • SELECTED"
	selected_label.text = definition.display_name.to_upper()
	description_label.text = _compact_description(definition.description)


func _compact_description(value: String) -> String:
	var compact: String = value.strip_edges().replace("\n", " ")
	if compact.length() <= 96:
		return compact
	return compact.left(93).strip_edges() + "..."


func _build_controller_hint(device: int) -> String:
	var controller_name: String = Input.get_joy_name(device).to_lower()
	var cancel_text: String = "B"
	if (
		"playstation" in controller_name
		or "dualsense" in controller_name
		or "dualshock" in controller_name
	):
		cancel_text = "CIRCLE"
	return (
		"RIGHT STICK SELECT  •  RELEASE DOWN KEEP SELECTION  •  "
		+ cancel_text
		+ " CANCEL"
	)


func _make_center_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.01, 0.012, 0.97)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.42, 0.07, 0.72)
	style.corner_radius_top_left = 96
	style.corner_radius_top_right = 96
	style.corner_radius_bottom_left = 96
	style.corner_radius_bottom_right = 96
	return style
