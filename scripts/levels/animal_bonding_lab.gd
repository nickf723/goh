extends AnimalBehaviorLab
class_name AnimalBondingLab

const BondedAnimalType = preload("res://scripts/animals/bonded_animal_actor.gd")

var bond_store: AnimalBondStore
var bond_overlay_label: Label


func _ready() -> void:
	super._ready()
	bond_store = AnimalBondStore.get_or_create(get_tree())
	_ensure_lab_treats(6)
	_build_bond_overlay()


func _process(delta: float) -> void:
	super._process(delta)
	_update_bond_overlay()


func _spawn_animal(
	name_value: String,
	species: String,
	position_value: Vector3,
	profile: String,
	speed: float,
	initial_mode: String = ""
) -> void:
	var animal := BondedAnimalType.new() as BondedAnimalType
	animal.animal_name = name_value
	animal.species_id = species
	animal.personality_profile_id = profile
	animal.persistent_animal_id = "animal_behavior_lab:" + name_value.to_lower().replace(" ", "_")
	animal.move_speed = speed
	animal.initial_locomotion_mode = initial_mode
	animal.position = position_value
	add_child(animal)
	animals.append(animal)


func _interact_selected(interaction_id: String) -> void:
	var animal: BondedAnimalType = _selected_bonded_animal()
	if animal == null:
		return
	var result: Dictionary = animal.interact_with_grace(interaction_id)
	if bool(result.get("ok", false)):
		var suffix: String = ""
		if interaction_id == "feed":
			suffix = " • " + str(GameState.get_inventory_count("field_treat")) + " treats left"
		_show_message(
			interaction_id.capitalize() + " changed " + animal.animal_name
			+ " to " + animal.get_relationship_label().capitalize() + suffix
		)
		return
	var error: String = str(result.get("error", "interaction failed"))
	if error == "no treats":
		_show_message("Grace has no Field Treats. Use Add Treats in the bonding panel.")
	elif error == "too far":
		_show_message("Move closer to " + animal.animal_name + " before using " + interaction_id.capitalize() + ".")
	else:
		_show_message(interaction_id.capitalize() + " failed: " + error)


func _reset_lab() -> void:
	super._reset_lab()
	_show_message("Lab reset. Named animal relationships remained saved.")


func _update_objective() -> void:
	var objective: String = "Compare ground, swimming, and flight animals in the shared habitat; then build trust, test follow behavior, and save a named bond."
	GameState.set_objective(objective)
	var game_ui: Node = get_tree().get_first_node_in_group("game_ui")
	if game_ui != null and game_ui.has_method("set_objective"):
		game_ui.call("set_objective", objective)


func _build_bond_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 31
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -392.0
	panel.offset_right = -18.0
	panel.offset_top = 78.0
	canvas.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.025, 0.055, 0.94)
	style.border_color = Color(0.72, 0.48, 0.92, 0.78)
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
	title.text = "NAMED ANIMAL BONDING"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.88, 0.68, 1.0))
	box.add_child(title)
	bond_overlay_label = Label.new()
	bond_overlay_label.add_theme_font_size_override("font_size", 14)
	bond_overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(bond_overlay_label)

	var relationship_grid := GridContainer.new()
	relationship_grid.columns = 2
	box.add_child(relationship_grid)
	_add_button(relationship_grid, "Bond Selected", Callable(self, "_bond_selected"))
	_add_button(relationship_grid, "Follow / Stay", Callable(self, "_toggle_selected_follow"))
	_add_button(relationship_grid, "Help / Heal", Callable(self, "_report_selected_event").bind("heal"))
	_add_button(relationship_grid, "Report Attack", Callable(self, "_report_selected_event").bind("attack"))
	_add_button(relationship_grid, "Add 6 Treats", Callable(self, "_add_lab_treats"))
	_add_button(relationship_grid, "Clear This Bond", Callable(self, "_clear_selected_bond"))

	var persistence_label := Label.new()
	persistence_label.text = "Persistence"
	persistence_label.add_theme_color_override("font_color", Color(0.86, 0.78, 0.96))
	box.add_child(persistence_label)
	var persistence_grid := GridContainer.new()
	persistence_grid.columns = 2
	box.add_child(persistence_grid)
	_add_button(persistence_grid, "Save Bonds", Callable(self, "_save_all_bonds"))
	_add_button(persistence_grid, "Reload Bonds", Callable(self, "_reload_all_bonds"))

	var hint := Label.new()
	hint.text = "Feed three times, Bond Selected, then walk away. A bonded animal can voluntarily follow Grace. Save and reload to verify that the same named animal remembers her."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.72, 0.68, 0.78))
	box.add_child(hint)


func _update_bond_overlay() -> void:
	if bond_overlay_label == null:
		return
	var animal: BondedAnimalType = _selected_bonded_animal()
	if animal == null:
		bond_overlay_label.text = "No bonded animal actor selected."
		return
	var bond_data: Dictionary = animal.get_bond_data()
	var requirements: Dictionary = bond_data.get("requirements", {}) as Dictionary
	var follow_text: String = "FOLLOWING" if bool(bond_data.get("follow_enabled", false)) else "STAYING"
	bond_overlay_label.text = (
		"Identity: " + animal.persistent_animal_id
		+ "\nField Treats: " + str(GameState.get_inventory_count("field_treat"))
		+ "\nBond: " + ("BONDED" if bool(bond_data.get("bonded", false)) else "NOT BONDED")
		+ "   Mode: " + follow_text
		+ "\nEligible now: " + ("YES" if bool(requirements.get("eligible", false)) else "NO")
		+ "\nNeed Trust 58%: " + _signed_percent(float(requirements.get("trust", 0.0)))
		+ "   Familiarity 45%: " + _percent(float(requirements.get("familiarity", 0.0)))
		+ "\nFear memory max 30%: " + _percent(float(requirements.get("fear_association", 0.0)))
		+ "   Current fear max 35%: " + _percent(float(requirements.get("current_fear", 0.0)))
	)


func _bond_selected() -> void:
	var animal: BondedAnimalType = _selected_bonded_animal()
	if animal == null:
		return
	var result: Dictionary = animal.attempt_bond()
	if bool(result.get("ok", false)):
		_show_message(animal.animal_name + " bonded with Grace and will follow her.")
		return
	var error: String = str(result.get("error", "bond failed"))
	if error == "relationship requirements not met":
		_show_message("Build more trust and familiarity, then calm any remaining fear before bonding.")
	elif error == "too far":
		_show_message("Grace must stand near " + animal.animal_name + " to form the bond.")
	else:
		_show_message("Bond failed: " + error)


func _toggle_selected_follow() -> void:
	var animal: BondedAnimalType = _selected_bonded_animal()
	if animal == null:
		return
	var result: Dictionary = animal.toggle_follow()
	if bool(result.get("ok", false)):
		_show_message(
			animal.animal_name + (" is following Grace." if bool(result.get("follow_enabled", false)) else " will stay nearby.")
		)
	else:
		_show_message("Bond with " + animal.animal_name + " before changing follow behavior.")


func _report_selected_event(event_id: String) -> void:
	var animal: BondedAnimalType = _selected_bonded_animal()
	if animal == null:
		return
	var result: Dictionary = animal.report_grace_event(event_id)
	if bool(result.get("ok", false)):
		_show_message(event_id.capitalize() + " changed " + animal.animal_name + " to " + animal.get_relationship_label().capitalize() + ".")
	else:
		_show_message("Event failed: " + str(result.get("error", "unknown")))


func _save_all_bonds() -> void:
	if bond_store == null:
		bond_store = AnimalBondStore.get_or_create(get_tree())
	for animal: GenericAnimalActor in animals:
		if animal is BondedAnimalType:
			(animal as BondedAnimalType).persist_named_state(false)
	var result: Dictionary = bond_store.save_to_disk() if bond_store != null else {"ok": false}
	_show_message(
		"Saved " + str(result.get("record_count", 0)) + " named animal records."
		if bool(result.get("ok", false))
		else "Animal bond save failed."
	)


func _reload_all_bonds() -> void:
	if bond_store == null:
		bond_store = AnimalBondStore.get_or_create(get_tree())
	var loaded: bool = bond_store != null and bond_store.load_from_disk()
	for animal: GenericAnimalActor in animals:
		if animal is BondedAnimalType:
			(animal as BondedAnimalType).reload_persistent_state()
	_show_message("Reloaded named animal relationships." if loaded else "No saved animal relationships were found.")


func _clear_selected_bond() -> void:
	var animal: BondedAnimalType = _selected_bonded_animal()
	if animal == null:
		return
	animal.clear_persistent_bond()
	_show_message("Cleared the saved relationship for " + animal.animal_name + ".")


func _add_lab_treats() -> void:
	GameState.add_inventory_item("field_treat", 6)
	_show_message("Added Field Treats. Grace now has " + str(GameState.get_inventory_count("field_treat")) + ".")


func _ensure_lab_treats(minimum_count: int) -> void:
	var missing: int = maxi(minimum_count - GameState.get_inventory_count("field_treat"), 0)
	if missing > 0:
		GameState.add_inventory_item("field_treat", missing)


func _selected_bonded_animal() -> BondedAnimalType:
	var animal: GenericAnimalActor = _selected_animal()
	return animal as BondedAnimalType if animal is BondedAnimalType else null
