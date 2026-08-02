extends "res://scripts/ui/full_menu_director_core.gd"

const FullMenuLoadoutShellScript = preload(
	"res://scripts/ui/full_menu_shell_feedback_v1.gd"
)
const ProgressionTrackerScript = preload(
	"res://scripts/progression/progression_tracker_feedback.gd"
)
const ProgressionFeedbackHUDScript = preload(
	"res://scripts/progression/progression_feedback_hud.gd"
)
const SpellcastingMasteryServiceScript = preload(
	"res://scripts/progression/spellcasting_mastery_service.gd"
)
const SpellcastingTraditionCatalogScript = preload(
	"res://scripts/progression/spellcasting_tradition_catalog.gd"
)
const SpellcastingTraditionResolverScript = preload(
	"res://scripts/abilities/spellcasting_tradition_resolver.gd"
)

const MENU_HIDDEN_CANVAS_LAYER_GROUPS: Array[String] = [
	"player_hud_v2",
	"divine_special_hud",
	"progression_feedback_hud",
]
const MENU_HIDDEN_CANVAS_ITEM_GROUPS: Array[String] = [
	"menu_suppressed_hud",
]

var menu_hidden_canvas_items: Array[CanvasItem] = []
var menu_hidden_canvas_item_visibility: Array[bool] = []
var menu_hidden_canvas_layers: Array[CanvasLayer] = []
var menu_hidden_canvas_layer_visibility: Array[bool] = []


func _ready() -> void:
	super._ready()
	var tracker: Node = _ensure_progression_tracker()
	_ensure_progression_feedback_hud(tracker)


func _ensure_progression_tracker() -> Node:
	var tracker: Node = get_node_or_null("ProgressionTracker")
	if tracker != null:
		return tracker
	tracker = ProgressionTrackerScript.new()
	tracker.name = "ProgressionTracker"
	tracker.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(tracker)
	return tracker


func _ensure_progression_feedback_hud(tracker: Node = null) -> CanvasLayer:
	var feedback: CanvasLayer = get_node_or_null("ProgressionFeedbackHUD") as CanvasLayer
	if feedback == null:
		feedback = ProgressionFeedbackHUDScript.new() as CanvasLayer
		feedback.name = "ProgressionFeedbackHUD"
		feedback.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(feedback)
	if tracker == null:
		tracker = _ensure_progression_tracker()
	if feedback.has_method("bind_tracker"):
		feedback.call("bind_tracker", tracker)
	return feedback


func _input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	if event.is_action_pressed("full_menu"):
		toggle_full_menu()
		get_viewport().set_input_as_handled()
		return
	if not is_full_menu_open():
		return
	ensure_full_menu_shell()
	if full_menu_shell == null:
		return
	var consumed: bool = false
	if full_menu_shell.has_method("handle_menu_input"):
		consumed = bool(full_menu_shell.call("handle_menu_input", event))
	var cancel_requested: bool = false
	if full_menu_shell.has_method("is_menu_cancel_event"):
		cancel_requested = bool(full_menu_shell.call("is_menu_cancel_event", event))
	else:
		cancel_requested = event.is_action_pressed("ui_cancel")
	if cancel_requested and not consumed:
		close_full_menu()
		get_viewport().set_input_as_handled()
		return
	if consumed:
		get_viewport().set_input_as_handled()


func ensure_full_menu_shell() -> void:
	if full_menu_shell != null and is_instance_valid(full_menu_shell):
		return
	var game_ui: Node = get_tree().get_first_node_in_group("game_ui")
	if game_ui == null:
		return
	var existing_shell: Node = game_ui.get_node_or_null("FullMenuShell")
	if existing_shell is Control and existing_shell.has_method("show_menu"):
		full_menu_shell = existing_shell as Control
		return
	full_menu_shell = FullMenuLoadoutShellScript.new()
	full_menu_shell.name = "FullMenuShell"
	full_menu_shell.process_mode = Node.PROCESS_MODE_ALWAYS
	game_ui.add_child(full_menu_shell)


func open_full_menu() -> void:
	var tracker: Node = _ensure_progression_tracker()
	_ensure_progression_feedback_hud(tracker)
	ensure_full_menu_shell()
	if full_menu_shell == null:
		print("FullMenuDirector: no shell available.")
		return
	was_paused_before_menu = get_tree().paused
	_hide_gameplay_hud()
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if full_menu_shell.has_method("show_menu"):
		full_menu_shell.call("show_menu", build_menu_data())


func close_full_menu() -> void:
	if full_menu_shell != null and full_menu_shell.has_method("hide_menu"):
		full_menu_shell.call("hide_menu")
	_restore_gameplay_hud()
	get_tree().paused = was_paused_before_menu
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _exit_tree() -> void:
	_restore_gameplay_hud()


func _hide_gameplay_hud() -> void:
	_restore_gameplay_hud()
	var game_ui: Node = get_tree().get_first_node_in_group("game_ui")
	if game_ui != null:
		for child: Node in game_ui.get_children():
			if child == full_menu_shell or not child is CanvasItem:
				continue
			_capture_canvas_item(child as CanvasItem)
	for group_name: String in MENU_HIDDEN_CANVAS_ITEM_GROUPS:
		for node: Node in get_tree().get_nodes_in_group(group_name):
			if node is CanvasItem:
				_capture_canvas_item(node as CanvasItem)
	for group_name: String in MENU_HIDDEN_CANVAS_LAYER_GROUPS:
		for node: Node in get_tree().get_nodes_in_group(group_name):
			if node is CanvasLayer:
				_capture_canvas_layer(node as CanvasLayer)


func _capture_canvas_item(canvas_item: CanvasItem) -> void:
	if canvas_item == null or menu_hidden_canvas_items.has(canvas_item):
		return
	menu_hidden_canvas_items.append(canvas_item)
	menu_hidden_canvas_item_visibility.append(canvas_item.visible)
	canvas_item.visible = false


func _capture_canvas_layer(canvas_layer: CanvasLayer) -> void:
	if canvas_layer == null or menu_hidden_canvas_layers.has(canvas_layer):
		return
	menu_hidden_canvas_layers.append(canvas_layer)
	menu_hidden_canvas_layer_visibility.append(canvas_layer.visible)
	canvas_layer.visible = false


func _restore_gameplay_hud() -> void:
	var item_restore_count: int = mini(
		menu_hidden_canvas_items.size(),
		menu_hidden_canvas_item_visibility.size()
	)
	for index: int in range(item_restore_count):
		var canvas_item: CanvasItem = menu_hidden_canvas_items[index]
		if canvas_item != null and is_instance_valid(canvas_item):
			canvas_item.visible = menu_hidden_canvas_item_visibility[index]
	menu_hidden_canvas_items.clear()
	menu_hidden_canvas_item_visibility.clear()
	var layer_restore_count: int = mini(
		menu_hidden_canvas_layers.size(),
		menu_hidden_canvas_layer_visibility.size()
	)
	for index: int in range(layer_restore_count):
		var canvas_layer: CanvasLayer = menu_hidden_canvas_layers[index]
		if canvas_layer != null and is_instance_valid(canvas_layer):
			canvas_layer.visible = menu_hidden_canvas_layer_visibility[index]
	menu_hidden_canvas_layers.clear()
	menu_hidden_canvas_layer_visibility.clear()


func build_menu_data() -> Dictionary:
	var data: Dictionary = super.build_menu_data()
	data["spellcasting_mastery"] = get_spellcasting_mastery_data()
	data["familiar_mastery"] = get_familiar_mastery_data()
	return data


func make_spell_row(
	ability: AbilityDefinition,
	slot_index: int,
	current_index: int,
	learned_index: int = -1
) -> Dictionary:
	var row: Dictionary = super.make_spell_row(
		ability,
		slot_index,
		current_index,
		learned_index
	)
	if ability == null:
		row["compatible_traditions"] = []
		row["spell_id"] = ""
		return row
	row["spell_id"] = ability.get_spell_id()
	row["compatible_traditions"] = SpellcastingTraditionResolverScript.resolve(ability)
	return row


func get_spellcasting_mastery_data() -> Dictionary:
	SpellcastingMasteryServiceScript.ensure_story_baseline()
	var compatible_spell_names: Dictionary = {}
	for tradition_id: String in SpellcastingTraditionCatalogScript.TRADITION_IDS:
		compatible_spell_names[tradition_id] = []
	var ability_caster: Node = get_ability_caster()
	var loadout: AbilityLoadout = get_ability_loadout(ability_caster)
	if loadout != null:
		for ability_variant: Variant in get_learned_abilities(loadout):
			if not ability_variant is AbilityDefinition:
				continue
			var ability: AbilityDefinition = ability_variant as AbilityDefinition
			for tradition_id: String in SpellcastingTraditionResolverScript.resolve(ability):
				var names: Array[String] = _mastery_copy_string_array(
					compatible_spell_names.get(tradition_id, [])
				)
				if not names.has(ability.display_name):
					names.append(ability.display_name)
				compatible_spell_names[tradition_id] = names
	var rows: Array[Dictionary] = SpellcastingMasteryServiceScript.get_progress_rows()
	for row: Dictionary in rows:
		var tradition_id: String = str(row.get("id", ""))
		var names: Array[String] = _mastery_copy_string_array(
			compatible_spell_names.get(tradition_id, [])
		)
		row["compatible_spell_names"] = names
		row["compatible_spell_count"] = names.size()
	return {
		"rows": rows,
		"summary": SpellcastingMasteryServiceScript.get_summary(),
		"persistence_scope": "save_slot",
	}


func get_familiar_mastery_data() -> Dictionary:
	var service: Node = get_node_or_null("/root/SpeciesKnowledge")
	if service == null:
		return {
			"rows": [],
			"summary": {},
			"equipped_species_id": "",
			"equipped_name": "None",
			"persistence_scope": "save_slot",
		}
	var rows: Array = []
	var summary: Dictionary = {}
	var equipped_species_id: String = ""
	if service.has_method("get_familiar_rows"):
		var rows_value: Variant = service.call("get_familiar_rows")
		if rows_value is Array:
			rows = rows_value as Array
	if service.has_method("get_summary"):
		var summary_value: Variant = service.call("get_summary")
		if summary_value is Dictionary:
			summary = summary_value as Dictionary
	if service.has_method("get_equipped_familiar_species_id"):
		equipped_species_id = str(service.call("get_equipped_familiar_species_id"))
	var equipped_name: String = "None"
	for row_value: Variant in rows:
		if not row_value is Dictionary:
			continue
		var row: Dictionary = row_value as Dictionary
		if str(row.get("species_id", "")) == equipped_species_id:
			equipped_name = str(row.get("display_name", equipped_species_id.capitalize()))
			break
	return {
		"rows": rows,
		"summary": summary,
		"equipped_species_id": equipped_species_id,
		"equipped_name": equipped_name,
		"persistence_scope": "save_slot",
	}


func _mastery_copy_string_array(raw_values: Variant) -> Array[String]:
	var values: Array[String] = []
	if not raw_values is Array:
		return values
	for raw_value: Variant in raw_values as Array:
		var value: String = str(raw_value)
		if value != "":
			values.append(value)
	return values
