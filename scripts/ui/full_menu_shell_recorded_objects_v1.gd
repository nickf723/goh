extends "res://scripts/ui/full_menu_shell_feedback_v1.gd"
class_name FullMenuShellRecordedObjectsV1

signal recorded_object_prepare_requested(blueprint_id: String)

const RecordedObjectCatalogScript = preload(
	"res://scripts/objects/recorded_object_catalog.gd"
)

var armed_recorded_object_item_id: String = ""


func show_menu(new_menu_data: Dictionary) -> void:
	armed_recorded_object_item_id = ""
	super.show_menu(new_menu_data)


func hide_menu() -> void:
	armed_recorded_object_item_id = ""
	super.hide_menu()


func activate_action(action: Dictionary) -> void:
	var kind: String = str(action.get("kind", ""))
	if (
		kind == "select_inventory_record"
		and get_current_tab_id() == "items"
		and selected_item_category == "objects"
	):
		var item_id: String = str(action.get("item_id", ""))
		var blueprint_id: String = RecordedObjectCatalogScript.get_blueprint_id_for_item(
			item_id
		)
		if blueprint_id != "" and RecordedObjectCatalogScript.is_recorded(blueprint_id):
			if armed_recorded_object_item_id != item_id:
				armed_recorded_object_item_id = item_id
				selected_inventory_item_id = item_id
				RecordedObjectCatalogScript.select_blueprint(blueprint_id)
				rebuild_menu()
				return
			RecordedObjectCatalogScript.select_blueprint(blueprint_id)
			recorded_object_prepare_requested.emit(blueprint_id)
			return
	if kind == "select_inventory_record":
		armed_recorded_object_item_id = ""
	super.activate_action(action)


func _toggle_item_category(category_id: String) -> void:
	armed_recorded_object_item_id = ""
	super._toggle_item_category(category_id)


func _reset_item_workspace() -> void:
	armed_recorded_object_item_id = ""
	super._reset_item_workspace()


func _make_inventory_detail_panel(
	row: Dictionary,
	category_definition: Dictionary,
	row_count: int
) -> PanelContainer:
	var panel: PanelContainer = super._make_inventory_detail_panel(
		row,
		category_definition,
		row_count
	)
	if row.is_empty():
		return panel
	var item_id: String = str(row.get("id", ""))
	var blueprint_id: String = RecordedObjectCatalogScript.get_blueprint_id_for_item(
		item_id
	)
	if blueprint_id == "":
		return panel
	var margin: MarginContainer = panel.get_child(0) as MarginContainer
	if margin == null or margin.get_child_count() == 0:
		return panel
	var stack: VBoxContainer = margin.get_child(0) as VBoxContainer
	if stack == null:
		return panel
	var definition: Dictionary = RecordedObjectCatalogScript.get_definition(blueprint_id)
	var selected: bool = (
		RecordedObjectCatalogScript.get_selected_blueprint_id() == blueprint_id
	)
	var armed: bool = armed_recorded_object_item_id == item_id
	var rule := HSeparator.new()
	stack.add_child(rule)
	var heading := Label.new()
	heading.text = "REPRODUCTION BLUEPRINT"
	heading.add_theme_font_size_override("font_size", 10)
	heading.add_theme_color_override("font_color", ITEM_CATEGORY_ACTIVE_BORDER)
	stack.add_child(heading)
	var state := Label.new()
	state.text = (
		("SELECTED • " if selected else "RECORDED • ")
		+ str(definition.get("mana_cost", 0))
		+ " MANA • "
		+ str(definition.get("maximum_active", 1))
		+ " ACTIVE MAX"
	)
	state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state.add_theme_font_size_override("font_size", 11)
	state.add_theme_color_override("font_color", TEXT_MAIN)
	stack.add_child(state)
	var instruction := Label.new()
	instruction.text = (
		"Press A again to close the menu and begin placement."
		if armed
		else "Press A to prepare this blueprint."
	)
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.add_theme_font_size_override("font_size", 11)
	instruction.add_theme_color_override(
		"font_color",
		ACTIVE_SELECTION_BORDER if armed else TEXT_SOFT
	)
	stack.add_child(instruction)
	return panel


func get_footer_text() -> String:
	if (
		get_current_tab_id() == "items"
		and selected_item_category == "objects"
		and items_page == ITEMS_CATEGORY
		and not is_assignment_active()
	):
		return "D-pad: choose blueprint  •  A: prepare / press again to place  •  B: collapse  •  ZL/ZR: main tabs  •  L/R: subtabs"
	return super.get_footer_text()


func get_recorded_object_menu_debug_data() -> Dictionary:
	return {
		"armed_item_id": armed_recorded_object_item_id,
		"selected_blueprint_id": RecordedObjectCatalogScript.get_selected_blueprint_id(),
		"recorded_count": RecordedObjectCatalogScript.get_recorded_blueprint_ids().size(),
		"prepare_signal": has_signal("recorded_object_prepare_requested"),
	}
