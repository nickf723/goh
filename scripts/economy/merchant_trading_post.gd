extends Area3D
class_name MerchantTradingPost

signal transaction_completed(kind: String, item_id: String, price: int)
signal transaction_failed(reason: String)

const EconomyCatalogScript = preload("res://scripts/economy/economy_catalog.gd")

const TAB_BUY: int = 0
const TAB_SELL: int = 1
const TAB_BUYBACK: int = 2
const TAB_NAMES: Array[String] = ["BUY", "SELL", "BUYBACK"]

@export var merchant_name: String = "Mara's Field Goods"
@export var prompt_text: String = "Browse merchant wares"

var stock: Dictionary = {}
var buyback: Array[Dictionary] = []
var menu_open: bool = false
var active_tab: int = TAB_BUY
var cursor_index: int = 0
var status_message: String = "Browse the wares."
var layer: CanvasLayer
var panel: PanelContainer
var tabs_label: Label
var wallet_label: Label
var rows_box: VBoxContainer
var description_label: Label
var status_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("interactable_target")
	add_to_group("merchant")
	add_to_group("debuggable")
	add_to_group("lab_resettable")
	initialize_stock()
	build_world_visual()
	build_menu()


func initialize_stock() -> void:
	stock.clear()
	for row: Dictionary in EconomyCatalogScript.DEFAULT_STOCK:
		stock[str(row.get("item_id", ""))] = maxi(int(row.get("stock", 0)), 0)


func interact() -> Dictionary:
	if not menu_open:
		call_deferred("open_menu")
	return {}


func open_menu() -> void:
	if menu_open:
		return
	menu_open = true
	active_tab = TAB_BUY
	cursor_index = 0
	status_message = "Choose something useful."
	refresh_menu()
	layer.visible = true
	get_tree().paused = true


func close_menu() -> void:
	if not menu_open:
		return
	menu_open = false
	layer.visible = false
	get_tree().paused = false


func _input(event: InputEvent) -> void:
	if not menu_open or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("ui_left"):
		active_tab = wrapi(active_tab - 1, 0, TAB_NAMES.size())
		cursor_index = 0
		status_message = TAB_NAMES[active_tab].capitalize() + " inventory."
		refresh_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		active_tab = wrapi(active_tab + 1, 0, TAB_NAMES.size())
		cursor_index = 0
		status_message = TAB_NAMES[active_tab].capitalize() + " inventory."
		refresh_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		move_cursor(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		move_cursor(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		activate_current_row()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()


func move_cursor(direction: int) -> void:
	var rows: Array[Dictionary] = get_active_rows()
	if rows.is_empty():
		cursor_index = 0
	else:
		cursor_index = wrapi(cursor_index + direction, 0, rows.size())
	refresh_menu()


func activate_current_row() -> void:
	var rows: Array[Dictionary] = get_active_rows()
	if rows.is_empty() or cursor_index < 0 or cursor_index >= rows.size():
		status_message = "There is nothing here."
		refresh_menu()
		return
	var row: Dictionary = rows[cursor_index]
	var succeeded: bool = false
	match active_tab:
		TAB_BUY:
			succeeded = buy_item(str(row.get("item_id", "")))
		TAB_SELL:
			succeeded = sell_item(str(row.get("item_id", "")))
		TAB_BUYBACK:
			succeeded = buyback_item(int(row.get("buyback_index", -1)))
	if succeeded:
		var refreshed: Array[Dictionary] = get_active_rows()
		cursor_index = clampi(cursor_index, 0, maxi(refreshed.size() - 1, 0))
	refresh_menu()


func buy_item(item_id: String) -> bool:
	var remaining: int = int(stock.get(item_id, 0))
	var price: int = EconomyCatalogScript.get_buy_price(item_id)
	if remaining <= 0 or price <= 0:
		return fail_transaction("That item is sold out.")
	if GameState.get_currency() < price:
		return fail_transaction("Not enough crowns.")
	var added: int = GameState.add_inventory_item(item_id, 1)
	if added <= 0:
		return fail_transaction("Your stack is full.")
	if not GameState.spend_currency(price):
		GameState.consume_inventory_item(item_id, 1)
		return fail_transaction("The payment could not be completed.")
	stock[item_id] = remaining - 1
	status_message = "Bought " + EconomyCatalogScript.get_display_name(item_id) + " for " + str(price) + " crowns."
	transaction_completed.emit("buy", item_id, price)
	return true


func sell_item(item_id: String) -> bool:
	var price: int = EconomyCatalogScript.get_sell_price(item_id)
	if price <= 0:
		return fail_transaction("The merchant will not buy that.")
	if not GameState.consume_inventory_item(item_id, 1):
		return fail_transaction("You do not have that item.")
	GameState.add_currency(price)
	buyback.push_front({"item_id": item_id, "price": price})
	if buyback.size() > 8:
		buyback.pop_back()
	status_message = "Sold " + EconomyCatalogScript.get_display_name(item_id) + " for " + str(price) + " crowns."
	transaction_completed.emit("sell", item_id, price)
	return true


func buyback_item(index: int) -> bool:
	if index < 0 or index >= buyback.size():
		return fail_transaction("That buyback is no longer available.")
	var row: Dictionary = buyback[index]
	var item_id: String = str(row.get("item_id", ""))
	var price: int = maxi(int(row.get("price", 0)), 0)
	if GameState.get_currency() < price:
		return fail_transaction("Not enough crowns.")
	var added: int = GameState.add_inventory_item(item_id, 1)
	if added <= 0:
		return fail_transaction("Your stack is full.")
	if not GameState.spend_currency(price):
		GameState.consume_inventory_item(item_id, 1)
		return fail_transaction("The payment could not be completed.")
	buyback.remove_at(index)
	status_message = "Bought back " + EconomyCatalogScript.get_display_name(item_id) + "."
	transaction_completed.emit("buyback", item_id, price)
	return true


func fail_transaction(reason: String) -> bool:
	status_message = reason
	transaction_failed.emit(reason)
	return false


func get_active_rows() -> Array[Dictionary]:
	match active_tab:
		TAB_BUY:
			return get_buy_rows()
		TAB_SELL:
			return EconomyCatalogScript.get_sellable_rows(GameState.get_inventory_snapshot())
		TAB_BUYBACK:
			return get_buyback_rows()
		_:
			return []


func get_buy_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for stock_row: Dictionary in EconomyCatalogScript.DEFAULT_STOCK:
		var item_id: String = str(stock_row.get("item_id", ""))
		var row: Dictionary = EconomyCatalogScript.get_item(item_id)
		row["item_id"] = item_id
		row["count"] = int(stock.get(item_id, 0))
		row["price"] = EconomyCatalogScript.get_buy_price(item_id)
		rows.append(row)
	return rows


func get_buyback_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for index: int in range(buyback.size()):
		var source: Dictionary = buyback[index]
		var item_id: String = str(source.get("item_id", ""))
		var row: Dictionary = EconomyCatalogScript.get_item(item_id)
		row["item_id"] = item_id
		row["count"] = 1
		row["price"] = int(source.get("price", 0))
		row["buyback_index"] = index
		rows.append(row)
	return rows


func refresh_menu() -> void:
	if rows_box == null:
		return
	wallet_label.text = "WALLET   " + str(GameState.get_currency()) + " CROWNS"
	var tab_parts: Array[String] = []
	for index: int in range(TAB_NAMES.size()):
		var name: String = TAB_NAMES[index]
		tab_parts.append(("◆ " + name + " ◆") if index == active_tab else name)
	tabs_label.text = "     ".join(tab_parts)
	for child: Node in rows_box.get_children():
		child.free()
	var rows: Array[Dictionary] = get_active_rows()
	if rows.is_empty():
		var empty := Label.new()
		empty.text = "Nothing available."
		empty.add_theme_font_size_override("font_size", 21)
		empty.add_theme_color_override("font_color", Color(0.48, 0.55, 0.64))
		rows_box.add_child(empty)
		description_label.text = "Change tabs to browse other transactions."
	else:
		cursor_index = clampi(cursor_index, 0, rows.size() - 1)
		for index: int in range(rows.size()):
			var row: Dictionary = rows[index]
			var selected: bool = index == cursor_index
			var label := Label.new()
			label.custom_minimum_size = Vector2(0.0, 48.0)
			label.add_theme_font_size_override("font_size", 21)
			var prefix: String = "◆  " if selected else "    "
			var item_id: String = str(row.get("item_id", ""))
			var count_text: String = ""
			if active_tab == TAB_BUY:
				count_text = "   STOCK " + str(row.get("count", 0))
			elif active_tab == TAB_SELL:
				count_text = "   OWNED " + str(row.get("count", 0))
			label.text = prefix + str(row.get("icon", "◇")) + "  " + str(row.get("name", item_id.capitalize()))
			label.text += count_text + "        " + str(row.get("price", 0)) + " C"
			label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.36) if selected else Color(0.8, 0.86, 0.92))
			rows_box.add_child(label)
		var current: Dictionary = rows[cursor_index]
		description_label.text = str(current.get("category", "Goods")).to_upper() + "\n" + str(current.get("description", ""))
	status_label.text = status_message


func reset_target() -> void:
	if menu_open:
		close_menu()
	buyback.clear()
	initialize_stock()
	active_tab = TAB_BUY
	cursor_index = 0
	status_message = "Browse the wares."


func build_world_visual() -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.8, 2.6, 2.0)
	collision.shape = shape
	collision.position.y = 1.3
	add_child(collision)
	var counter := MeshInstance3D.new()
	var counter_mesh := BoxMesh.new()
	counter_mesh.size = Vector3(4.2, 1.2, 1.3)
	counter.mesh = counter_mesh
	counter.position.y = 0.6
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.3, 0.14, 0.06)
	wood.roughness = 0.72
	counter.material_override = wood
	add_child(counter)
	var canopy := MeshInstance3D.new()
	var canopy_mesh := BoxMesh.new()
	canopy_mesh.size = Vector3(5.0, 0.18, 2.4)
	canopy.mesh = canopy_mesh
	canopy.position.y = 3.0
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.08, 0.42, 0.5)
	cloth.roughness = 0.6
	canopy.material_override = cloth
	add_child(canopy)
	var sign := Label3D.new()
	sign.text = merchant_name.to_upper() + "\nBUY • SELL • BUYBACK"
	sign.position = Vector3(0.0, 2.15, 0.0)
	sign.font_size = 30
	sign.pixel_size = 0.006
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.outline_size = 7
	sign.modulate = Color(0.72, 0.94, 1.0)
	add_child(sign)


func build_menu() -> void:
	layer = CanvasLayer.new()
	layer.layer = 94
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.visible = false
	add_child(layer)
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-585.0, -350.0)
	panel.custom_minimum_size = Vector2(1170.0, 700.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.028, 0.045, 0.99)
	style.border_color = Color(0.2, 0.72, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 13)
	margin.add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	var title := Label.new()
	title.text = merchant_name.to_upper()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.65, 0.91, 1.0))
	top.add_child(title)
	wallet_label = Label.new()
	wallet_label.add_theme_font_size_override("font_size", 23)
	wallet_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.36))
	top.add_child(wallet_label)
	tabs_label = Label.new()
	tabs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tabs_label.add_theme_font_size_override("font_size", 20)
	tabs_label.add_theme_color_override("font_color", Color(0.56, 0.85, 0.96))
	root.add_child(tabs_label)
	root.add_child(HSeparator.new())
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 28)
	root.add_child(columns)
	rows_box = VBoxContainer.new()
	rows_box.custom_minimum_size = Vector2(720.0, 0.0)
	rows_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(rows_box)
	description_label = Label.new()
	description_label.custom_minimum_size = Vector2(355.0, 0.0)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 19)
	description_label.add_theme_color_override("font_color", Color(0.72, 0.8, 0.88))
	columns.add_child(description_label)
	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(0.0, 42.0)
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	root.add_child(status_label)
	var hint := Label.new()
	hint.text = "Left / Right  Change tab     Up / Down  Select     Confirm  Trade     Cancel  Close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_color_override("font_color", Color(0.46, 0.57, 0.68))
	root.add_child(hint)


func get_debug_data() -> Dictionary:
	return {
		"wallet": GameState.get_currency(),
		"tab": TAB_NAMES[active_tab],
		"stock": stock.duplicate(true),
		"buyback_count": buyback.size(),
		"menu_open": menu_open,
	}
