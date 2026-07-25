extends Area3D
class_name EquipmentOutfitter

const GameplayEffectAccessScript = preload("res://scripts/effects/gameplay_effect_access.gd")

signal equipment_transaction(kind: String, item_id: String, price: int)

const EquipmentCatalogScript = preload("res://scripts/equipment/equipment_catalog.gd")

const TAB_SHOP: int = 0
const TAB_OWNED: int = 1
const TAB_SELL: int = 2
const TAB_NAMES: Array[String] = ["SHOP", "EQUIP", "SELL"]

@export var outfitter_name: String = "The Wayfarer's Wardrobe"
@export var prompt_text: String = "Browse equipment"

var menu_open: bool = false
var active_tab: int = TAB_SHOP
var cursor_index: int = 0
var confirmation_pending: bool = false
var pending_key: String = ""
var status_message: String = "Find something that suits the road ahead."
var layer: CanvasLayer
var panel: PanelContainer
var wallet_label: Label
var tabs_label: Label
var slots_label: Label
var rows_box: VBoxContainer
var detail_label: Label
var comparison_label: Label
var status_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("interactable_target")
	add_to_group("equipment_outfitter")
	add_to_group("debuggable")
	build_world_visual()
	build_menu()


func interact() -> Dictionary:
	if not menu_open:
		call_deferred("open_menu")
	return {}


func open_menu() -> void:
	if menu_open:
		return
	menu_open = true
	active_tab = TAB_SHOP
	cursor_index = 0
	clear_confirmation()
	status_message = "Find something that suits the road ahead."
	refresh_menu()
	layer.visible = true
	get_tree().paused = true


func close_menu() -> void:
	if not menu_open:
		return
	menu_open = false
	clear_confirmation()
	layer.visible = false
	get_tree().paused = false


func _input(event: InputEvent) -> void:
	if not menu_open or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("ui_left"):
		active_tab = wrapi(active_tab - 1, 0, TAB_NAMES.size())
		cursor_index = 0
		clear_confirmation()
		refresh_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		active_tab = wrapi(active_tab + 1, 0, TAB_NAMES.size())
		cursor_index = 0
		clear_confirmation()
		refresh_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		move_cursor(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		move_cursor(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		activate_current()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if confirmation_pending:
			clear_confirmation()
			status_message = "Action cancelled."
			refresh_menu()
		else:
			close_menu()
		get_viewport().set_input_as_handled()


func move_cursor(direction: int) -> void:
	var rows: Array[Dictionary] = get_active_rows()
	if rows.is_empty():
		cursor_index = 0
	else:
		cursor_index = wrapi(cursor_index + direction, 0, rows.size())
	clear_confirmation()
	refresh_menu()


func activate_current() -> void:
	var rows: Array[Dictionary] = get_active_rows()
	if rows.is_empty() or cursor_index < 0 or cursor_index >= rows.size():
		status_message = "There is nothing available in this section."
		refresh_menu()
		return
	var item_id: String = str(rows[cursor_index].get("id", ""))
	var action_key: String = TAB_NAMES[active_tab] + ":" + item_id
	if not confirmation_pending or pending_key != action_key:
		confirmation_pending = true
		pending_key = action_key
		status_message = confirmation_prompt(item_id)
		refresh_menu()
		return
	clear_confirmation()
	match active_tab:
		TAB_SHOP:
			buy_equipment(item_id)
		TAB_OWNED:
			equip_owned_item(item_id)
		TAB_SELL:
			sell_equipment(item_id)
	refresh_menu()


func confirmation_prompt(item_id: String) -> String:
	var name: String = EquipmentCatalogScript.get_display_name(item_id)
	match active_tab:
		TAB_SHOP:
			return "Buy " + name + " for " + str(get_buy_price(item_id)) + " crowns? Confirm again."
		TAB_OWNED:
			return "Equip " + name + "? Confirm again."
		TAB_SELL:
			return "Sell " + name + " for " + str(get_sell_price(item_id)) + " crowns? Confirm again."
		_:
			return "Confirm action?"


func clear_confirmation() -> void:
	confirmation_pending = false
	pending_key = ""


func get_buy_price(item_id: String) -> int:
	var base_price: int = maxi(int(EquipmentCatalogScript.get_definition(item_id).get("buy", 0)), 0)
	return maxi(GameplayEffectAccessScript.modify_int("shop_buy_price", base_price), 0)


func get_sell_price(item_id: String) -> int:
	var base_price: int = maxi(int(EquipmentCatalogScript.get_definition(item_id).get("sell", 0)), 0)
	return maxi(GameplayEffectAccessScript.modify_int("shop_sell_price", base_price), 0)


func buy_equipment(item_id: String) -> bool:
	if GameState.owns_equipment(item_id):
		status_message = "Grace already owns that equipment."
		return false
	var price: int = get_buy_price(item_id)
	if price <= 0:
		status_message = "That equipment is not for sale."
		return false
	if GameState.get_currency() < price:
		status_message = "Not enough crowns."
		return false
	if not GameState.grant_equipment(item_id):
		status_message = "The equipment could not be added."
		return false
	if not GameState.spend_currency(price):
		GameState.revoke_equipment(item_id)
		status_message = "The payment could not be completed."
		return false
	status_message = "Purchased " + EquipmentCatalogScript.get_display_name(item_id) + ". Equip it from the Equip tab."
	equipment_transaction.emit("buy", item_id, price)
	return true


func equip_owned_item(item_id: String) -> bool:
	if not GameState.equip_item(item_id):
		status_message = "That equipment could not be equipped."
		return false
	status_message = "Equipped " + EquipmentCatalogScript.get_display_name(item_id) + "."
	equipment_transaction.emit("equip", item_id, 0)
	return true


func sell_equipment(item_id: String) -> bool:
	if GameState.is_equipment_equipped(item_id):
		status_message = "Equipped gear cannot be sold. Equip a replacement first."
		return false
	var price: int = get_sell_price(item_id)
	if price <= 0:
		status_message = "That equipment cannot be sold."
		return false
	if not GameState.revoke_equipment(item_id):
		status_message = "That equipment could not be sold."
		return false
	GameState.add_currency(price)
	status_message = "Sold " + EquipmentCatalogScript.get_display_name(item_id) + " for " + str(price) + " crowns."
	equipment_transaction.emit("sell", item_id, price)
	return true


func get_active_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for row: Dictionary in EquipmentCatalogScript.get_all_rows():
		var item_id: String = str(row.get("id", ""))
		match active_tab:
			TAB_SHOP:
				if int(row.get("buy", 0)) > 0 and not GameState.owns_equipment(item_id):
					rows.append(row)
			TAB_OWNED:
				if GameState.owns_equipment(item_id):
					rows.append(row)
			TAB_SELL:
				if GameState.owns_equipment(item_id) and int(row.get("sell", 0)) > 0:
					rows.append(row)
	return rows


func build_comparison(item_id: String) -> String:
	var definition: Dictionary = EquipmentCatalogScript.get_definition(item_id)
	var slot_id: String = str(definition.get("slot", ""))
	var current_item_id: String = GameState.get_equipped_item(slot_id)
	var current_modifiers: Dictionary = EquipmentCatalogScript.get_modifiers(current_item_id)
	var new_modifiers: Dictionary = EquipmentCatalogScript.get_modifiers(item_id)
	var stat_ids: Array[String] = []
	for stat_variant: Variant in current_modifiers.keys():
		var stat_id: String = str(stat_variant)
		if not stat_ids.has(stat_id):
			stat_ids.append(stat_id)
	for stat_variant: Variant in new_modifiers.keys():
		var stat_id: String = str(stat_variant)
		if not stat_ids.has(stat_id):
			stat_ids.append(stat_id)
	var lines: Array[String] = []
	if stat_ids.is_empty():
		lines.append("No direct stat change.")
	for stat_id: String in stat_ids:
		var current_value: int = GameState.get_stat(stat_id)
		var projected: int = current_value - int(current_modifiers.get(stat_id, 0)) + int(new_modifiers.get(stat_id, 0))
		var arrow: String = "→"
		lines.append(stat_id.replace("max_", "Max ").capitalize() + "   " + str(current_value) + " " + arrow + " " + str(projected))
	if current_item_id == item_id:
		lines.append("\nCURRENTLY EQUIPPED")
	elif current_item_id != "":
		lines.append("\nReplaces " + EquipmentCatalogScript.get_display_name(current_item_id))
	else:
		lines.append("\nEmpty " + slot_id.capitalize() + " slot")
	return "\n".join(lines)


func refresh_menu() -> void:
	if rows_box == null:
		return
	wallet_label.text = str(GameState.get_currency()) + " CROWNS"
	var tab_parts: Array[String] = []
	for index: int in range(TAB_NAMES.size()):
		tab_parts.append(("◆ " + TAB_NAMES[index] + " ◆") if index == active_tab else TAB_NAMES[index])
	tabs_label.text = "       ".join(tab_parts)
	var slot_parts: Array[String] = []
	for slot_id: String in EquipmentCatalogScript.SLOT_ORDER:
		var item_id: String = GameState.get_equipped_item(slot_id)
		slot_parts.append(slot_id.capitalize() + ": " + (EquipmentCatalogScript.get_display_name(item_id) if item_id != "" else "Empty"))
	slots_label.text = "     ".join(slot_parts)
	for child: Node in rows_box.get_children():
		child.free()
	var rows: Array[Dictionary] = get_active_rows()
	if rows.is_empty():
		var empty := Label.new()
		empty.text = "Nothing available."
		empty.add_theme_font_size_override("font_size", 21)
		empty.add_theme_color_override("font_color", Color(0.48, 0.56, 0.66))
		rows_box.add_child(empty)
		detail_label.text = "Change tabs to browse other equipment."
		comparison_label.text = ""
	else:
		cursor_index = clampi(cursor_index, 0, rows.size() - 1)
		for index: int in range(rows.size()):
			var row: Dictionary = rows[index]
			var selected: bool = index == cursor_index
			var item_id: String = str(row.get("id", ""))
			var line := Label.new()
			line.custom_minimum_size = Vector2(0.0, 48.0)
			line.add_theme_font_size_override("font_size", 20)
			line.text = ("◆  " if selected else "    ") + str(row.get("icon", "◇")) + "  " + str(row.get("name", item_id.capitalize()))
			line.text += "   [" + str(row.get("slot", "")).to_upper() + "]"
			if active_tab == TAB_SHOP:
				line.text += "       " + str(get_buy_price(item_id)) + " C"
			elif active_tab == TAB_SELL:
				line.text += "       " + str(get_sell_price(item_id)) + " C"
				if GameState.is_equipment_equipped(item_id):
					line.text += "   EQUIPPED"
			line.add_theme_color_override("font_color", Color(1.0, 0.82, 0.36) if selected else Color(0.8, 0.87, 0.94))
			rows_box.add_child(line)
		var selected_row: Dictionary = rows[cursor_index]
		var selected_id: String = str(selected_row.get("id", ""))
		detail_label.text = str(selected_row.get("name", selected_id.capitalize())).to_upper() + "\n\n"
		detail_label.text += str(selected_row.get("description", "")) + "\n\n"
		detail_label.text += EquipmentCatalogScript.format_modifiers(selected_row.get("modifiers", {}) as Dictionary)
		var effect_text: String = EquipmentCatalogScript.format_effects(selected_id, true)
		if effect_text != "":
			detail_label.text += "\n\nTRAIT\n" + effect_text
		comparison_label.text = build_comparison(selected_id)
	status_label.text = status_message


func build_world_visual() -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.8, 3.0, 2.0)
	collision.shape = shape
	collision.position.y = 1.5
	add_child(collision)
	var counter := MeshInstance3D.new()
	var counter_mesh := BoxMesh.new()
	counter_mesh.size = Vector3(5.0, 1.1, 1.4)
	counter.mesh = counter_mesh
	counter.position.y = 0.55
	counter.material_override = make_material(Color(0.25, 0.12, 0.06), 0.0)
	add_child(counter)
	var wardrobe := MeshInstance3D.new()
	var wardrobe_mesh := BoxMesh.new()
	wardrobe_mesh.size = Vector3(5.8, 3.6, 0.55)
	wardrobe.mesh = wardrobe_mesh
	wardrobe.position = Vector3(0.0, 2.25, 0.65)
	wardrobe.material_override = make_material(Color(0.08, 0.27, 0.32), 0.25)
	add_child(wardrobe)
	var mannequin := MeshInstance3D.new()
	var mannequin_mesh := CapsuleMesh.new()
	mannequin_mesh.radius = 0.48
	mannequin_mesh.height = 1.8
	mannequin.mesh = mannequin_mesh
	mannequin.position = Vector3(0.0, 1.75, -0.25)
	mannequin.material_override = make_material(Color(0.75, 0.66, 0.52), 0.0)
	add_child(mannequin)
	var sign := Label3D.new()
	sign.text = outfitter_name.to_upper() + "\nBUY • COMPARE • EQUIP • SELL"
	sign.position = Vector3(0.0, 4.45, 0.0)
	sign.font_size = 29
	sign.pixel_size = 0.006
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.outline_size = 7
	sign.modulate = Color(0.7, 0.94, 1.0)
	add_child(sign)


func make_material(color: Color, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.55
	return material


func build_menu() -> void:
	layer = CanvasLayer.new()
	layer.layer = 96
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.visible = false
	add_child(layer)
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-650.0, -365.0)
	panel.custom_minimum_size = Vector2(1300.0, 730.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.014, 0.027, 0.04, 0.99)
	style.border_color = Color(0.25, 0.76, 0.86)
	style.set_border_width_all(2)
	style.set_corner_radius_all(22)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 11)
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = outfitter_name.to_upper()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 29)
	title.add_theme_color_override("font_color", Color(0.66, 0.92, 1.0))
	header.add_child(title)
	wallet_label = Label.new()
	wallet_label.add_theme_font_size_override("font_size", 22)
	wallet_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.36))
	header.add_child(wallet_label)
	tabs_label = Label.new()
	tabs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tabs_label.add_theme_font_size_override("font_size", 19)
	tabs_label.add_theme_color_override("font_color", Color(0.56, 0.86, 0.96))
	root.add_child(tabs_label)
	slots_label = Label.new()
	slots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slots_label.add_theme_font_size_override("font_size", 15)
	slots_label.add_theme_color_override("font_color", Color(0.62, 0.7, 0.78))
	root.add_child(slots_label)
	root.add_child(HSeparator.new())
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 25)
	root.add_child(columns)
	rows_box = VBoxContainer.new()
	rows_box.custom_minimum_size = Vector2(680.0, 0.0)
	rows_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(rows_box)
	var detail_column := VBoxContainer.new()
	detail_column.custom_minimum_size = Vector2(500.0, 0.0)
	columns.add_child(detail_column)
	detail_label = Label.new()
	detail_label.custom_minimum_size = Vector2(0.0, 220.0)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override("font_size", 18)
	detail_label.add_theme_color_override("font_color", Color(0.75, 0.83, 0.9))
	detail_column.add_child(detail_label)
	comparison_label = Label.new()
	comparison_label.add_theme_font_size_override("font_size", 19)
	comparison_label.add_theme_color_override("font_color", Color(0.56, 1.0, 0.72))
	detail_column.add_child(comparison_label)
	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(0.0, 44.0)
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	root.add_child(status_label)
	var hint := Label.new()
	hint.text = "Left / Right  Tab     Up / Down  Select     Confirm twice  Act     Cancel  Back / Close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_color_override("font_color", Color(0.46, 0.58, 0.68))
	root.add_child(hint)


func get_debug_data() -> Dictionary:
	return {
		"menu_open": menu_open,
		"tab": TAB_NAMES[active_tab],
		"owned": GameState.get_owned_equipment_snapshot(),
		"slots": GameState.get_equipped_items_snapshot(),
		"confirmation": confirmation_pending,
	}
