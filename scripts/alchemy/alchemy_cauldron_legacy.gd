extends Area3D
class_name AlchemyCauldron

signal brew_completed(recipe_id: String, output_item_id: String)
signal brew_failed(ingredient_key: String, catalyst: String)
signal catalyst_changed(element: String)

const INGREDIENTS: Array[Dictionary] = [
	{"id": "life_bloom", "name": "Life Bloom", "symbol": "✿", "color": Color(0.35, 0.95, 0.45), "traits": "Life • Body"},
	{"id": "springwater", "name": "Springwater", "symbol": "≈", "color": Color(0.25, 0.72, 1.0), "traits": "Water • Cleanse"},
	{"id": "echo_reed", "name": "Echo Reed", "symbol": "◉", "color": Color(0.8, 0.38, 1.0), "traits": "Sound • Air"},
	{"id": "frost_salt", "name": "Frost Salt", "symbol": "❄", "color": Color(0.55, 0.93, 1.0), "traits": "Ice • Poison"},
	{"id": "spark_ore", "name": "Spark Ore", "symbol": "ϟ", "color": Color(1.0, 0.78, 0.18), "traits": "Metal • Lightning"},
]

const RECIPES: Dictionary = {
	"life_bloom|springwater": {
		"id": "healing_potion",
		"name": "Healing Potion",
		"catalyst": "fire",
		"output": "healing_potion",
		"description": "Life opens in warm Water.",
	},
	"echo_reed|springwater": {
		"id": "resonance_tonic",
		"name": "Resonance Tonic",
		"catalyst": "air",
		"output": "resonance_tonic",
		"description": "Air suspends Sound through the solvent.",
	},
	"frost_salt|life_bloom": {
		"id": "frost_vigor_draught",
		"name": "Frost Vigor Draught",
		"catalyst": "ice",
		"output": "frost_vigor_draught",
		"description": "Ice braces the body's living energy.",
	},
	"frost_salt|springwater": {
		"id": "antidote",
		"name": "Clarifying Antidote",
		"catalyst": "water",
		"output": "antidote",
		"description": "Water separates poison from its cure.",
	},
	"spark_ore|springwater": {
		"id": "conductive_elixir",
		"name": "Conductive Elixir",
		"catalyst": "lightning",
		"output": "conductive_elixir",
		"description": "Lightning charges Metal held in solution.",
	},
}

@export var prompt_text: String = "Use alchemy cauldron"
@export var default_catalyst: String = "none"

var catalyst: String = "none"
var selected_ingredients: Array[String] = []
var cursor_index: int = 0
var menu_open: bool = false
var status_message: String = "Select two ingredients."
var layer: CanvasLayer
var panel: PanelContainer
var ingredient_box: VBoxContainer
var selection_label: Label
var catalyst_label: Label
var status_label: Label
var recipe_label: RichTextLabel
var liquid: MeshInstance3D
var liquid_material: StandardMaterial3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	catalyst = default_catalyst
	add_to_group("interactable_target")
	add_to_group("alchemy_cauldron")
	add_to_group("debuggable")
	add_to_group("lab_resettable")
	build_world_visual()
	build_menu()


func interact() -> Dictionary:
	if menu_open:
		return {}
	call_deferred("open_menu")
	return {}


func open_menu() -> void:
	if menu_open:
		return
	menu_open = true
	cursor_index = 0
	status_message = "Select two ingredients, then brew."
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
	if event.is_action_pressed("ui_up"):
		cursor_index = wrapi(cursor_index - 1, 0, INGREDIENTS.size() + 2)
		refresh_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		cursor_index = wrapi(cursor_index + 1, 0, INGREDIENTS.size() + 2)
		refresh_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		activate_cursor()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if not selected_ingredients.is_empty():
			selected_ingredients.pop_back()
			status_message = "Removed the last ingredient."
			refresh_menu()
		else:
			close_menu()
		get_viewport().set_input_as_handled()


func activate_cursor() -> void:
	if cursor_index < INGREDIENTS.size():
		select_ingredient(cursor_index)
	elif cursor_index == INGREDIENTS.size():
		brew()
	else:
		selected_ingredients.clear()
		status_message = "Cauldron cleared."
		refresh_menu()


func select_ingredient(index: int) -> void:
	if index < 0 or index >= INGREDIENTS.size():
		return
	var ingredient: Dictionary = INGREDIENTS[index]
	var ingredient_id: String = str(ingredient.get("id", ""))
	if GameState.get_inventory_count(ingredient_id) <= selected_ingredients.count(ingredient_id):
		status_message = "No more " + str(ingredient.get("name", "ingredient")) + " available."
		refresh_menu()
		return
	if selected_ingredients.size() >= 2:
		status_message = "The cauldron holds two ingredients. Brew or clear it."
		refresh_menu()
		return
	selected_ingredients.append(ingredient_id)
	status_message = str(ingredient.get("name", "Ingredient")) + " added."
	refresh_menu()


func brew() -> void:
	if selected_ingredients.size() != 2:
		status_message = "Two ingredients are required."
		refresh_menu()
		return
	var key: String = get_recipe_key(selected_ingredients)
	var recipe: Dictionary = RECIPES.get(key, {})
	if recipe.is_empty():
		consume_selected_ingredients()
		GameState.set_flag("alchemy_failed_" + key.replace("|", "_"), true)
		status_message = "The mixture curdles into unstable sludge. Recipe failed."
		brew_failed.emit(key, catalyst)
		selected_ingredients.clear()
		flash_liquid(Color(0.28, 0.32, 0.18))
		refresh_menu()
		return
	var required_catalyst: String = str(recipe.get("catalyst", "none"))
	if catalyst != required_catalyst:
		consume_selected_ingredients()
		status_message = "The ingredients react, but " + required_catalyst.capitalize() + " treatment was required. Unstable sludge."
		brew_failed.emit(key, catalyst)
		selected_ingredients.clear()
		flash_liquid(Color(0.42, 0.22, 0.48))
		refresh_menu()
		return
	var output_id: String = str(recipe.get("output", ""))
	var added: int = GameState.add_inventory_item(output_id, 1)
	if added <= 0:
		status_message = str(recipe.get("name", "Potion")) + " inventory is full. Ingredients were preserved."
		refresh_menu()
		return
	consume_selected_ingredients()
	var recipe_id: String = str(recipe.get("id", output_id))
	var newly_discovered: bool = not GameState.get_flag("recipe_discovered_" + recipe_id)
	GameState.set_flag("recipe_discovered_" + recipe_id, true)
	var assigned_slot: int = assign_first_open_quick_slot(output_id)
	status_message = "Discovered " if newly_discovered else "Brewed "
	status_message += str(recipe.get("name", "Potion")) + "."
	if assigned_slot >= 0:
		status_message += " Assigned to " + slot_name(assigned_slot) + "."
	selected_ingredients.clear()
	flash_liquid(recipe_color(output_id))
	brew_completed.emit(recipe_id, output_id)
	refresh_menu()


func consume_selected_ingredients() -> void:
	for ingredient_id: String in selected_ingredients:
		GameState.consume_inventory_item(ingredient_id, 1)


func assign_first_open_quick_slot(item_id: String) -> int:
	for slot_index: int in [1, 2, 0, 3]:
		if GameState.get_quick_item_slot(slot_index) == "":
			if GameState.set_quick_item_slot(slot_index, item_id):
				return slot_index
	return -1


func slot_name(index: int) -> String:
	match index:
		0:
			return "Quick Up"
		1:
			return "Quick Left"
		2:
			return "Quick Right"
		3:
			return "Quick Down"
		_:
			return "Quick Belt"


func apply_element(element: String) -> void:
	var normalized: String = element.to_lower().strip_edges()
	if normalized not in ["fire", "air", "ice", "water", "lightning"]:
		return
	catalyst = normalized
	status_message = normalized.capitalize() + " treatment prepared."
	update_liquid_color()
	catalyst_changed.emit(catalyst)
	if menu_open:
		refresh_menu()


func get_recipe_key(ingredients: Array[String]) -> String:
	var sorted: Array[String] = ingredients.duplicate()
	sorted.sort()
	var key: String = ""
	for ingredient_id: String in sorted:
		if key != "":
			key += "|"
		key += ingredient_id
	return key


func ingredient_name(ingredient_id: String) -> String:
	for ingredient: Dictionary in INGREDIENTS:
		if str(ingredient.get("id", "")) == ingredient_id:
			return str(ingredient.get("name", ingredient_id.capitalize()))
	return ingredient_id.capitalize()


func recipe_color(output_id: String) -> Color:
	match output_id:
		"healing_potion":
			return Color(0.92, 0.2, 0.34)
		"resonance_tonic":
			return Color(0.82, 0.36, 1.0)
		"frost_vigor_draught":
			return Color(0.45, 0.9, 1.0)
		"antidote":
			return Color(0.52, 0.92, 0.24)
		"conductive_elixir":
			return Color(1.0, 0.78, 0.18)
		_:
			return Color(0.3, 0.52, 0.7)


func reset_target() -> void:
	selected_ingredients.clear()
	catalyst = default_catalyst
	status_message = "Select two ingredients."
	update_liquid_color()
	if menu_open:
		close_menu()


func refresh_menu() -> void:
	if ingredient_box == null:
		return
	for child: Node in ingredient_box.get_children():
		child.free()
	for index: int in range(INGREDIENTS.size()):
		var ingredient: Dictionary = INGREDIENTS[index]
		var row := Label.new()
		row.custom_minimum_size = Vector2(0.0, 42.0)
		row.add_theme_font_size_override("font_size", 19)
		var prefix: String = "◆  " if cursor_index == index else "   "
		var ingredient_id: String = str(ingredient.get("id", ""))
		row.text = prefix + str(ingredient.get("symbol", "◇")) + "  " + str(ingredient.get("name", "Ingredient"))
		row.text += "   ×" + str(GameState.get_inventory_count(ingredient_id))
		row.text += "    " + str(ingredient.get("traits", ""))
		row.add_theme_color_override("font_color", Color(1.0, 0.82, 0.36) if cursor_index == index else ingredient.get("color", Color.WHITE))
		ingredient_box.add_child(row)
	for action_index: int in range(2):
		var row := Label.new()
		row.custom_minimum_size = Vector2(0.0, 42.0)
		row.add_theme_font_size_override("font_size", 20)
		var absolute_index: int = INGREDIENTS.size() + action_index
		var selected: bool = cursor_index == absolute_index
		var action_text: String = "BREW MIXTURE" if action_index == 0 else "CLEAR CAULDRON"
		row.text = ("◆  " if selected else "   ") + action_text
		row.add_theme_color_override("font_color", Color(1.0, 0.82, 0.36) if selected else Color(0.72, 0.78, 0.86))
		ingredient_box.add_child(row)
	var selection_names: Array[String] = []
	for ingredient_id: String in selected_ingredients:
		selection_names.append(ingredient_name(ingredient_id))
	selection_label.text = "CAULDRON  " + (" + ".join(selection_names) if not selection_names.is_empty() else "Empty")
	catalyst_label.text = "TREATMENT  " + catalyst.to_upper()
	status_label.text = status_message
	refresh_recipe_book()


func refresh_recipe_book() -> void:
	var text: String = "[color=#efc765][font_size=22]DISCOVERED RECIPES[/font_size][/color]\n\n"
	var discovered: int = 0
	for key_variant: Variant in RECIPES.keys():
		var recipe: Dictionary = RECIPES[key_variant] as Dictionary
		var recipe_id: String = str(recipe.get("id", ""))
		if GameState.get_flag("recipe_discovered_" + recipe_id):
			discovered += 1
			text += "[color=#dce8f3][b]" + str(recipe.get("name", recipe_id.capitalize())) + "[/b][/color]\n"
			text += "[color=#8296a8]" + str(recipe.get("description", "")) + "[/color]\n"
			text += "[color=#66cde8]Treatment: " + str(recipe.get("catalyst", "none")).capitalize() + "[/color]\n\n"
	if discovered == 0:
		text += "[color=#718092]Experiment to record recipes.[/color]"
	recipe_label.text = text


func build_world_visual() -> void:
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.0
	shape.height = 1.2
	collision.shape = shape
	collision.position.y = 0.65
	add_child(collision)
	var body := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 0.78
	mesh.height = 1.0
	body.mesh = mesh
	body.position.y = 0.5
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.08, 0.1, 0.13)
	iron.metallic = 0.82
	iron.roughness = 0.32
	body.material_override = iron
	add_child(body)
	liquid = MeshInstance3D.new()
	var liquid_mesh := CylinderMesh.new()
	liquid_mesh.top_radius = 0.82
	liquid_mesh.bottom_radius = 0.82
	liquid_mesh.height = 0.08
	liquid.mesh = liquid_mesh
	liquid.position.y = 1.02
	liquid_material = StandardMaterial3D.new()
	liquid_material.emission_enabled = true
	liquid.material_override = liquid_material
	add_child(liquid)
	var label := Label3D.new()
	label.text = "ALCHEMY CAULDRON"
	label.position = Vector3(0.0, 2.0, 0.0)
	label.font_size = 28
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 7
	label.modulate = Color(0.65, 0.9, 1.0)
	add_child(label)
	update_liquid_color()


func update_liquid_color() -> void:
	if liquid_material == null:
		return
	var colors: Dictionary = {
		"none": Color(0.18, 0.36, 0.46),
		"fire": Color(1.0, 0.25, 0.06),
		"air": Color(0.95, 0.55, 0.82),
		"ice": Color(0.42, 0.9, 1.0),
		"water": Color(0.18, 0.62, 1.0),
		"lightning": Color(1.0, 0.82, 0.18),
	}
	var color: Color = colors.get(catalyst, colors["none"]) as Color
	liquid_material.albedo_color = color
	liquid_material.emission = color.darkened(0.25)
	liquid_material.emission_energy_multiplier = 1.4


func flash_liquid(color: Color) -> void:
	if liquid_material == null:
		return
	liquid_material.albedo_color = color
	liquid_material.emission = color
	liquid_material.emission_energy_multiplier = 3.5
	var tween := create_tween()
	tween.tween_property(liquid_material, "emission_energy_multiplier", 1.4, 0.45)
	tween.finished.connect(update_liquid_color)


func build_menu() -> void:
	layer = CanvasLayer.new()
	layer.layer = 92
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.visible = false
	add_child(layer)
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-620.0, -365.0)
	panel.custom_minimum_size = Vector2(1240.0, 730.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.028, 0.045, 0.985)
	style.border_color = Color(0.26, 0.72, 0.88, 0.95)
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
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	var title := Label.new()
	title.text = "ELEMENTAL ALCHEMY"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.66, 0.9, 1.0))
	root.add_child(title)
	var divider := HSeparator.new()
	root.add_child(divider)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 30)
	root.add_child(columns)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(720.0, 0.0)
	columns.add_child(left)
	selection_label = Label.new()
	selection_label.add_theme_font_size_override("font_size", 22)
	selection_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.36))
	left.add_child(selection_label)
	catalyst_label = Label.new()
	catalyst_label.add_theme_font_size_override("font_size", 17)
	catalyst_label.add_theme_color_override("font_color", Color(0.52, 0.82, 1.0))
	left.add_child(catalyst_label)
	ingredient_box = VBoxContainer.new()
	ingredient_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(ingredient_box)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(0.0, 55.0)
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color(0.88, 0.9, 0.94))
	left.add_child(status_label)
	recipe_label = RichTextLabel.new()
	recipe_label.bbcode_enabled = true
	recipe_label.custom_minimum_size = Vector2(410.0, 0.0)
	recipe_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	recipe_label.add_theme_font_size_override("normal_font_size", 17)
	columns.add_child(recipe_label)
	var hint := Label.new()
	hint.text = "Up / Down  Select     Confirm  Add or Brew     Cancel  Remove / Close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_color_override("font_color", Color(0.48, 0.58, 0.68))
	root.add_child(hint)


func get_debug_data() -> Dictionary:
	return {
		"menu_open": menu_open,
		"catalyst": catalyst,
		"selected": selected_ingredients.duplicate(),
		"discovered": get_discovered_count(),
	}


func get_discovered_count() -> int:
	var count: int = 0
	for recipe_variant: Variant in RECIPES.values():
		var recipe: Dictionary = recipe_variant as Dictionary
		if GameState.get_flag("recipe_discovered_" + str(recipe.get("id", ""))):
			count += 1
	return count