extends Control
class_name RegionalExpeditionMap

const RegionalStoreScript = preload("res://scripts/expedition/regional_expedition_store.gd")
const ExpeditionStoreScript = preload("res://scripts/expedition/expedition_record_store.gd")

@export var network_record_path: String = RegionalStoreScript.DEFAULT_RECORD_PATH
@export var expedition_record_path: String = ExpeditionStoreScript.DEFAULT_RECORD_PATH
@export var wilds_scene_path: String = "res://scenes/levels/prototypes/prototype_wilds_expedition_v1.tscn"
@export var map_scene_path: String = "res://scenes/levels/prototypes/prototype_regional_expedition_map_v1.tscn"
@export var allow_scene_launch: bool = true

const NODE_POSITIONS: Dictionary = {
	RegionalStoreScript.NODE_CYPRESS: Vector2(245.0, 430.0),
	RegionalStoreScript.NODE_CAIRN: Vector2(520.0, 265.0),
	RegionalStoreScript.NODE_BLUE_RIDGE: Vector2(785.0, 145.0),
}

var network_record: Dictionary = {}
var selected_node_id: String = ""
var selected_route_id: String = ""
var node_buttons: Dictionary = {}

var current_location_label: Label
var selection_title: Label
var selection_body: Label
var route_state_label: Label
var launch_button: Button
var hint_label: Label


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	set_process_unhandled_input(true)
	build_interface()
	load_and_sync_network()
	select_default_destination()
	refresh_interface()


func _draw() -> void:
	var size: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.055, 0.07, 1.0))
	draw_circle(Vector2(205.0, 455.0), 210.0, Color(0.08, 0.18, 0.14, 0.72))
	draw_circle(Vector2(775.0, 105.0), 245.0, Color(0.11, 0.14, 0.2, 0.68))
	draw_rect(Rect2(870.0, 82.0, 330.0, 500.0), Color(0.055, 0.075, 0.095, 0.96), true)
	draw_rect(Rect2(870.0, 82.0, 330.0, 500.0), Color(0.28, 0.42, 0.5, 0.75), false, 2.0)

	draw_route_line(
		RegionalStoreScript.NODE_CYPRESS,
		RegionalStoreScript.NODE_BLUE_RIDGE,
		RegionalStoreScript.ROUTE_MAIN,
		Vector2(0.0, 0.0)
	)
	if RegionalStoreScript.is_node_discovered(network_record, RegionalStoreScript.NODE_CAIRN):
		draw_route_line(
			RegionalStoreScript.NODE_CYPRESS,
			RegionalStoreScript.NODE_CAIRN,
			RegionalStoreScript.ROUTE_CYPRESS_CAIRN,
			Vector2(0.0, 0.0)
		)
		draw_route_line(
			RegionalStoreScript.NODE_CAIRN,
			RegionalStoreScript.NODE_BLUE_RIDGE,
			RegionalStoreScript.ROUTE_CAIRN_BLUE_RIDGE,
			Vector2(0.0, 0.0)
		)
	else:
		draw_dashed_unknown_route(
			NODE_POSITIONS[RegionalStoreScript.NODE_CYPRESS],
			NODE_POSITIONS[RegionalStoreScript.NODE_CAIRN]
		)


func draw_route_line(from_node: String, to_node: String, route_id: String, offset: Vector2) -> void:
	var from_position: Vector2 = NODE_POSITIONS[from_node] + offset
	var to_position: Vector2 = NODE_POSITIONS[to_node] + offset
	var state_name: String = RegionalStoreScript.get_route_state(network_record, route_id)
	var color: Color = get_route_state_color(state_name)
	var width: float = 8.0 if route_id == selected_route_id else 4.0
	draw_line(from_position, to_position, color, width, true)
	var midpoint: Vector2 = from_position.lerp(to_position, 0.5)
	draw_circle(midpoint, 5.0, color.lightened(0.18))


func draw_dashed_unknown_route(from_position: Vector2, to_position: Vector2) -> void:
	for index: int in range(8):
		if index % 2 == 0:
			var start: Vector2 = from_position.lerp(to_position, float(index) / 8.0)
			var finish: Vector2 = from_position.lerp(to_position, float(index + 1) / 8.0)
			draw_line(start, finish, Color(0.28, 0.34, 0.37, 0.72), 3.0, true)


func build_interface() -> void:
	var title: Label = Label.new()
	title.text = "REGIONAL EXPEDITION MAP"
	title.position = Vector2(38.0, 24.0)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.78, 0.94, 1.0, 1.0))
	add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "Choose a known destination. The Wilds assemble before Grace departs."
	subtitle.position = Vector2(40.0, 60.0)
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.62, 0.72, 0.78, 1.0))
	add_child(subtitle)

	current_location_label = Label.new()
	current_location_label.position = Vector2(38.0, 96.0)
	current_location_label.add_theme_font_size_override("font_size", 17)
	current_location_label.add_theme_color_override("font_color", Color(0.72, 1.0, 0.74, 1.0))
	add_child(current_location_label)

	create_node_button(
		RegionalStoreScript.NODE_CYPRESS,
		"CYPRESS\nFIELD CAMP",
		NODE_POSITIONS[RegionalStoreScript.NODE_CYPRESS],
		Color(0.42, 0.82, 0.52, 1.0)
	)
	create_node_button(
		RegionalStoreScript.NODE_CAIRN,
		"OLD SURVEY\nCAIRN",
		NODE_POSITIONS[RegionalStoreScript.NODE_CAIRN],
		Color(0.48, 0.86, 1.0, 1.0)
	)
	create_node_button(
		RegionalStoreScript.NODE_BLUE_RIDGE,
		"BLUE RIDGE\nWAYSTATION",
		NODE_POSITIONS[RegionalStoreScript.NODE_BLUE_RIDGE],
		Color(0.55, 0.7, 1.0, 1.0)
	)

	selection_title = Label.new()
	selection_title.position = Vector2(895.0, 112.0)
	selection_title.size = Vector2(280.0, 64.0)
	selection_title.add_theme_font_size_override("font_size", 22)
	selection_title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0, 1.0))
	selection_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(selection_title)

	selection_body = Label.new()
	selection_body.position = Vector2(895.0, 184.0)
	selection_body.size = Vector2(280.0, 195.0)
	selection_body.add_theme_font_size_override("font_size", 15)
	selection_body.add_theme_color_override("font_color", Color(0.72, 0.8, 0.84, 1.0))
	selection_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(selection_body)

	route_state_label = Label.new()
	route_state_label.position = Vector2(895.0, 385.0)
	route_state_label.size = Vector2(280.0, 64.0)
	route_state_label.add_theme_font_size_override("font_size", 16)
	add_child(route_state_label)

	launch_button = Button.new()
	launch_button.text = "ASSEMBLE EXPEDITION"
	launch_button.position = Vector2(895.0, 470.0)
	launch_button.size = Vector2(280.0, 54.0)
	launch_button.pressed.connect(launch_selected_route)
	add_child(launch_button)

	hint_label = Label.new()
	hint_label.text = "Controller: D-pad / stick + Confirm\nMouse: select a node, then launch"
	hint_label.position = Vector2(895.0, 535.0)
	hint_label.size = Vector2(280.0, 46.0)
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color(0.5, 0.62, 0.68, 1.0))
	add_child(hint_label)


func create_node_button(node_id: String, label_text: String, center: Vector2, accent: Color) -> void:
	var button: Button = Button.new()
	button.name = "Node_" + node_id
	button.text = label_text
	button.position = center - Vector2(76.0, 36.0)
	button.size = Vector2(152.0, 72.0)
	button.add_theme_color_override("font_color", accent)
	button.add_theme_color_override("font_hover_color", accent.lightened(0.2))
	button.add_theme_color_override("font_focus_color", accent.lightened(0.2))
	button.pressed.connect(select_node.bind(node_id))
	add_child(button)
	node_buttons[node_id] = button


func load_and_sync_network() -> void:
	network_record = RegionalStoreScript.load_or_create(network_record_path)
	var expedition_record: Dictionary = ExpeditionStoreScript.load_or_create(
		RegionalStoreScript.ROUTE_MAIN,
		18890417,
		expedition_record_path
	)
	network_record = RegionalStoreScript.sync_from_expedition_record(network_record, expedition_record)
	RegionalStoreScript.save_record(network_record, network_record_path)


func select_default_destination() -> void:
	var current_node_id: String = str(network_record.get("current_node_id", RegionalStoreScript.NODE_CYPRESS))
	match current_node_id:
		RegionalStoreScript.NODE_CYPRESS:
			select_node(RegionalStoreScript.NODE_BLUE_RIDGE)
		RegionalStoreScript.NODE_BLUE_RIDGE:
			select_node(RegionalStoreScript.NODE_CYPRESS)
		RegionalStoreScript.NODE_CAIRN:
			select_node(RegionalStoreScript.NODE_BLUE_RIDGE)


func select_node(node_id: String) -> void:
	selected_node_id = node_id
	selected_route_id = get_route_between(
		str(network_record.get("current_node_id", RegionalStoreScript.NODE_CYPRESS)),
		selected_node_id
	)
	refresh_interface()


func get_route_between(from_node: String, to_node: String) -> String:
	if from_node == to_node:
		return ""
	var pair: Array[String] = [from_node, to_node]
	if pair.has(RegionalStoreScript.NODE_CYPRESS) and pair.has(RegionalStoreScript.NODE_BLUE_RIDGE):
		return RegionalStoreScript.ROUTE_MAIN
	if pair.has(RegionalStoreScript.NODE_CYPRESS) and pair.has(RegionalStoreScript.NODE_CAIRN):
		return RegionalStoreScript.ROUTE_CYPRESS_CAIRN
	if pair.has(RegionalStoreScript.NODE_CAIRN) and pair.has(RegionalStoreScript.NODE_BLUE_RIDGE):
		return RegionalStoreScript.ROUTE_CAIRN_BLUE_RIDGE
	return ""


func refresh_interface() -> void:
	var current_node_id: String = str(network_record.get("current_node_id", RegionalStoreScript.NODE_CYPRESS))
	current_location_label.text = "CURRENT LOCATION  •  " + get_node_display_name(current_node_id).to_upper()

	for node_id: String in node_buttons.keys():
		var button: Button = node_buttons[node_id] as Button
		var discovered: bool = RegionalStoreScript.is_node_discovered(network_record, node_id)
		button.disabled = not discovered or node_id == current_node_id
		button.visible = discovered or node_id == RegionalStoreScript.NODE_CAIRN
		if node_id == RegionalStoreScript.NODE_CAIRN and not discovered:
			button.text = "UNKNOWN\nLANDMARK"
			button.modulate = Color(0.45, 0.5, 0.52, 0.72)
		else:
			button.modulate = Color.WHITE

	var route_available: bool = selected_route_id != ""
	if route_available:
		var route_state: String = RegionalStoreScript.get_route_state(network_record, selected_route_id)
		route_available = route_state != RegionalStoreScript.STATE_UNKNOWN
		selection_title.text = get_node_display_name(selected_node_id)
		selection_body.text = get_route_description(selected_route_id, current_node_id, selected_node_id)
		route_state_label.text = (
			"ROUTE  •  " + route_state.to_upper()
			+ "\nCROSSINGS  •  "
			+ str(RegionalStoreScript.get_route_crossings(network_record, selected_route_id))
		)
		route_state_label.add_theme_color_override("font_color", get_route_state_color(route_state))
	else:
		selection_title.text = get_node_display_name(selected_node_id)
		selection_body.text = "No known direct expedition route connects these locations yet."
		route_state_label.text = "ROUTE  •  UNKNOWN"
		route_state_label.add_theme_color_override("font_color", Color(0.48, 0.54, 0.57, 1.0))

	launch_button.disabled = not route_available
	launch_button.text = "ASSEMBLE EXPEDITION" if route_available else "ROUTE UNAVAILABLE"
	queue_redraw()


func launch_selected_route() -> void:
	if launch_button.disabled:
		return
	var launch_context: Dictionary = build_launch_context()
	get_tree().root.set_meta("regional_expedition_launch", launch_context)
	if allow_scene_launch:
		get_tree().change_scene_to_file(wilds_scene_path)


func build_launch_context() -> Dictionary:
	return {
		"route_id": selected_route_id,
		"origin_node_id": str(network_record.get("current_node_id", RegionalStoreScript.NODE_CYPRESS)),
		"destination_node_id": selected_node_id,
		"network_record_path": network_record_path,
		"expedition_record_path": expedition_record_path,
		"map_scene_path": map_scene_path,
		"suppress_scene_transition": not allow_scene_launch,
	}


func get_node_display_name(node_id: String) -> String:
	match node_id:
		RegionalStoreScript.NODE_CYPRESS:
			return "Cypress Field Camp"
		RegionalStoreScript.NODE_BLUE_RIDGE:
			return "Blue Ridge Waystation"
		RegionalStoreScript.NODE_CAIRN:
			return "Old Survey Cairn"
	return "Unknown Location"


func get_route_description(route_id: String, from_node: String, to_node: String) -> String:
	var direction_text: String = get_node_display_name(from_node) + " → " + get_node_display_name(to_node)
	match route_id:
		RegionalStoreScript.ROUTE_MAIN:
			return direction_text + "\n\nFive assembled segments carry Grace from flooded cypress country through wet woodland, pine ridge, rocky foothills, and mountain forest.\n\nDanger: Moderate  •  Length: 5 segments"
		RegionalStoreScript.ROUTE_CYPRESS_CAIRN:
			return direction_text + "\n\nA surveyed branch leaves the main crossing through the wet woodland. The cairn preserves a stable navigation anchor between expeditions.\n\nDanger: Low  •  Length: Partial crossing"
		RegionalStoreScript.ROUTE_CAIRN_BLUE_RIDGE:
			return direction_text + "\n\nThe eastern survey leg climbs from the cairn through pine and rocky foothills toward Blue Ridge.\n\nDanger: Moderate  •  Length: Partial crossing"
	return direction_text


func get_route_state_color(state_name: String) -> Color:
	match state_name:
		RegionalStoreScript.STATE_DISCOVERED:
			return Color(0.46, 0.67, 0.76, 1.0)
		RegionalStoreScript.STATE_CROSSED:
			return Color(0.44, 0.78, 1.0, 1.0)
		RegionalStoreScript.STATE_MAPPED:
			return Color(0.64, 0.9, 0.7, 1.0)
		RegionalStoreScript.STATE_STABILIZED:
			return Color(1.0, 0.84, 0.38, 1.0)
	return Color(0.3, 0.36, 0.39, 0.75)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().root.remove_meta("regional_expedition_launch")
		get_viewport().set_input_as_handled()
