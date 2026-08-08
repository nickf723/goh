extends Node
class_name ConcentrationManager

signal effect_activated(effect_id: String, usable_mana_cap: int, reserved_mana: int)
signal effect_deactivated(effect_id: String)
signal concentration_updated(current_mana: int, usable_mana_cap: int, reserved_mana: int)

@export var passive_mana_regeneration_per_second: float = 0.0
@export var show_hud: bool = true
@export_range(0.05, 0.99, 0.01) var maximum_total_reservation_fraction: float = 0.95

# `active_effect` remains as a compatibility pointer to the most recently
# activated concentration. New code should use `has_effect()` / `active_effects`.
var active_effect: Resource = null
var active_effects: Dictionary = {}
var activation_order: Array[String] = []
var active_ability_caster: Node = null
var ability_cost_cache: Dictionary = {}
var mana_regeneration_accumulator: float = 0.0

var hud_layer: CanvasLayer = null
var hud_panel: PanelContainer = null
var hud_title: Label = null
var hud_detail: Label = null
var hud_bar: ProgressBar = null


func _ready() -> void:
	add_to_group("concentration_manager")
	add_to_group("debuggable")
	if show_hud:
		ensure_hud()
	refresh_hud()


func _process(delta: float) -> void:
	if not active_effects.is_empty():
		enforce_mana_cap()
	regenerate_mana(delta)
	refresh_hud()


func _exit_tree() -> void:
	deactivate_all_effects(false)


func activate_effect(definition: Resource, ability_caster: Node = null) -> bool:
	if definition == null:
		return false
	var effect_id: String = _definition_id(definition)
	if effect_id == "":
		return false
	if active_effects.has(effect_id):
		active_effect = definition
		return true

	var incoming_fraction: float = _definition_fraction(definition)
	var total_after: float = get_total_reservation_fraction() + incoming_fraction
	if total_after > maximum_total_reservation_fraction + 0.0001:
		show_message(
			_definition_name(definition)
			+ " needs "
			+ str(roundi(incoming_fraction * 100.0))
			+ "% concentration, but only "
			+ str(roundi(maxf(maximum_total_reservation_fraction - get_total_reservation_fraction(), 0.0) * 100.0))
			+ "% remains."
		)
		return false

	if ability_caster != null:
		active_ability_caster = ability_caster
	elif active_ability_caster == null:
		active_ability_caster = find_player_ability_caster()

	_cache_original_ability_costs()
	active_effects[effect_id] = definition
	activation_order.erase(effect_id)
	activation_order.append(effect_id)
	active_effect = definition
	mana_regeneration_accumulator = 0.0
	_reapply_ability_costs()
	enforce_mana_cap()
	refresh_hud()

	effect_activated.emit(effect_id, get_usable_mana_cap(), get_reserved_mana())
	show_message(
		_definition_name(definition)
		+ " reserves "
		+ str(roundi(incoming_fraction * 100.0))
		+ "% mana. Total concentration: "
		+ str(get_reservation_percent())
		+ "%."
	)
	return true


func deactivate_effect(
	show_feedback: bool = true,
	effect_id: String = ""
) -> void:
	var resolved_id: String = effect_id.strip_edges().to_lower()
	if resolved_id == "":
		resolved_id = get_effect_id()
	if resolved_id == "" or not active_effects.has(resolved_id):
		return

	var previous_definition: Resource = active_effects[resolved_id] as Resource
	var previous_display_name: String = _definition_name(previous_definition)
	active_effects.erase(resolved_id)
	activation_order.erase(resolved_id)
	_refresh_legacy_active_effect()
	mana_regeneration_accumulator = 0.0
	if active_effects.is_empty():
		restore_ability_costs()
		active_ability_caster = null
	else:
		_reapply_ability_costs()
	enforce_mana_cap()
	refresh_hud()
	effect_deactivated.emit(resolved_id)

	if show_feedback:
		show_message(
			previous_display_name
			+ " released. Total concentration: "
			+ str(get_reservation_percent())
			+ "%."
		)


func deactivate_effect_by_id(
	effect_id: String,
	show_feedback: bool = true
) -> void:
	deactivate_effect(show_feedback, effect_id)


func deactivate_all_effects(show_feedback: bool = false) -> void:
	var ids: Array[String] = get_active_effect_ids()
	for effect_id: String in ids:
		deactivate_effect(false, effect_id)
	if show_feedback and not ids.is_empty():
		show_message("All concentration released.")


func toggle_effect(definition: Resource, ability_caster: Node = null) -> bool:
	if definition == null:
		return false
	var incoming_id: String = _definition_id(definition)
	if has_effect(incoming_id):
		deactivate_effect(true, incoming_id)
		return false
	return activate_effect(definition, ability_caster)


func has_effect(effect_id: String) -> bool:
	return active_effects.has(effect_id.strip_edges().to_lower())


func get_active_effect(effect_id: String) -> Resource:
	var value: Variant = active_effects.get(effect_id.strip_edges().to_lower())
	return value as Resource if value is Resource else null


func get_active_effect_ids() -> Array[String]:
	var result: Array[String] = []
	for effect_id: String in activation_order:
		if active_effects.has(effect_id):
			result.append(effect_id)
	return result


func get_active_effect_count() -> int:
	return active_effects.size()


func get_total_reservation_fraction() -> float:
	var total: float = 0.0
	for value: Variant in active_effects.values():
		if value is Resource:
			total += _definition_fraction(value as Resource)
	return clampf(total, 0.0, maximum_total_reservation_fraction)


func get_usable_mana_cap() -> int:
	var maximum_mana: int = maxi(GameState.get_stat("max_mana"), 0)
	var fraction: float = get_total_reservation_fraction()
	return maxi(
		maximum_mana - int(ceil(float(maximum_mana) * fraction)),
		0
	)


func get_reserved_mana() -> int:
	return maxi(GameState.get_stat("max_mana") - get_usable_mana_cap(), 0)


func get_reservation_percent() -> int:
	return roundi(get_total_reservation_fraction() * 100.0)


func get_effect_reservation_percent(effect_id: String) -> int:
	var definition: Resource = get_active_effect(effect_id)
	return roundi(_definition_fraction(definition) * 100.0) if definition != null else 0


func is_element_free(element: String) -> bool:
	var normalized: String = element.to_lower().strip_edges()
	for value: Variant in active_effects.values():
		if not value is Resource:
			continue
		var definition: Resource = value as Resource
		if definition.has_method("makes_element_free"):
			if bool(definition.call("makes_element_free", normalized)):
				return true
			continue
		var free_elements_value: Variant = definition.get("free_elements")
		if free_elements_value is Array and (free_elements_value as Array).has(normalized):
			return true
	return false


func enforce_mana_cap() -> void:
	var cap: int = get_usable_mana_cap()
	var current_mana: int = GameState.get_stat("mana")
	if current_mana > cap:
		GameState.set_stat("mana", cap)
		current_mana = cap
	concentration_updated.emit(current_mana, cap, get_reserved_mana())


func regenerate_mana(delta: float) -> void:
	if passive_mana_regeneration_per_second <= 0.0:
		return
	var current_mana: int = GameState.get_stat("mana")
	var cap: int = get_usable_mana_cap()
	if current_mana >= cap:
		mana_regeneration_accumulator = 0.0
		return
	mana_regeneration_accumulator += maxf(delta, 0.0) * passive_mana_regeneration_per_second
	var whole_units: int = floori(mana_regeneration_accumulator)
	if whole_units <= 0:
		return
	mana_regeneration_accumulator -= float(whole_units)
	GameState.set_stat("mana", mini(current_mana + whole_units, cap))


func _cache_original_ability_costs() -> void:
	if active_ability_caster == null:
		return
	var loadout_value: Variant = active_ability_caster.get("loadout")
	if loadout_value == null:
		return
	var equipped_value: Variant = loadout_value.get("equipped_abilities")
	if not equipped_value is Array:
		return
	for ability_value: Variant in equipped_value as Array:
		if ability_value == null or not ability_value is Resource:
			continue
		var ability: Resource = ability_value as Resource
		var ability_id: int = ability.get_instance_id()
		if ability_cost_cache.has(ability_id):
			continue
		ability_cost_cache[ability_id] = {
			"ability": ability,
			"mana_cost": int(ability.get("mana_cost")),
		}


func cache_and_apply_ability_costs() -> void:
	_cache_original_ability_costs()
	_reapply_ability_costs()


func _reapply_ability_costs() -> void:
	_cache_original_ability_costs()
	for cache_value: Variant in ability_cost_cache.values():
		if not cache_value is Dictionary:
			continue
		var row: Dictionary = cache_value as Dictionary
		var ability: Resource = row.get("ability") as Resource
		if ability == null or not is_instance_valid(ability):
			continue
		var original_cost: int = int(row.get("mana_cost", 0))
		var element: String = str(ability.get("element")).to_lower().strip_edges()
		var multiplier: float = get_element_cost_multiplier(element)
		ability.set("mana_cost", ceili(float(original_cost) * multiplier))


func get_element_cost_multiplier(element: String) -> float:
	var normalized: String = element.to_lower().strip_edges()
	var multiplier: float = 1.0
	for value: Variant in active_effects.values():
		if not value is Resource:
			continue
		var definition: Resource = value as Resource
		var effect_multiplier: float = 1.0
		if definition.has_method("get_element_cost_multiplier"):
			effect_multiplier = clampf(
				float(definition.call("get_element_cost_multiplier", normalized)),
				0.0,
				1.0
			)
		else:
			var free_elements_value: Variant = definition.get("free_elements")
			if free_elements_value is Array and (free_elements_value as Array).has(normalized):
				effect_multiplier = 0.0
		multiplier *= effect_multiplier
	return clampf(multiplier, 0.0, 1.0)


func restore_ability_costs() -> void:
	for cache_value: Variant in ability_cost_cache.values():
		if not cache_value is Dictionary:
			continue
		var row: Dictionary = cache_value as Dictionary
		var ability: Resource = row.get("ability") as Resource
		if ability == null or not is_instance_valid(ability):
			continue
		ability.set("mana_cost", int(row.get("mana_cost", 0)))
	ability_cost_cache.clear()


func find_player_ability_caster() -> Node:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	return player.get_node_or_null("AbilityCaster")


func get_effect_id() -> String:
	return _definition_id(active_effect)


func get_effect_display_name() -> String:
	return _definition_name(active_effect) if active_effect != null else "Concentration"


func _definition_id(definition: Resource) -> String:
	return str(definition.get("effect_id")).strip_edges().to_lower() if definition != null else ""


func _definition_name(definition: Resource) -> String:
	return str(definition.get("display_name")) if definition != null else "Concentration"


func _definition_fraction(definition: Resource) -> float:
	if definition == null:
		return 0.0
	return clampf(float(definition.get("mana_reservation_fraction")), 0.0, 0.95)


func _refresh_legacy_active_effect() -> void:
	active_effect = null
	for index: int in range(activation_order.size() - 1, -1, -1):
		var effect_id: String = activation_order[index]
		var value: Variant = active_effects.get(effect_id)
		if value is Resource:
			active_effect = value as Resource
			return


func ensure_hud() -> void:
	if hud_layer != null:
		return
	hud_layer = CanvasLayer.new()
	hud_layer.name = "ConcentrationHUD"
	hud_layer.layer = 12
	add_child(hud_layer)
	hud_panel = PanelContainer.new()
	hud_panel.name = "ConcentrationPanel"
	hud_panel.visible = false
	hud_panel.anchor_left = 1.0
	hud_panel.anchor_top = 0.0
	hud_panel.anchor_right = 1.0
	hud_panel.anchor_bottom = 0.0
	hud_panel.offset_left = -350.0
	hud_panel.offset_top = 24.0
	hud_panel.offset_right = -24.0
	hud_panel.offset_bottom = 158.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.055, 0.09, 0.9)
	panel_style.border_color = Color(0.22, 0.62, 0.96, 0.82)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	hud_panel.add_theme_stylebox_override("panel", panel_style)
	hud_layer.add_child(hud_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	hud_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	margin.add_child(stack)
	hud_title = Label.new()
	hud_title.add_theme_font_size_override("font_size", 15)
	hud_title.add_theme_color_override("font_color", Color(0.66, 0.9, 1.0, 1.0))
	stack.add_child(hud_title)
	hud_bar = ProgressBar.new()
	hud_bar.show_percentage = false
	hud_bar.custom_minimum_size = Vector2(0.0, 14.0)
	stack.add_child(hud_bar)
	hud_detail = Label.new()
	hud_detail.add_theme_font_size_override("font_size", 12)
	hud_detail.add_theme_color_override("font_color", Color(0.82, 0.88, 0.96, 0.96))
	stack.add_child(hud_detail)


func refresh_hud() -> void:
	if not show_hud:
		return
	ensure_hud()
	if hud_panel == null:
		return
	hud_panel.visible = not active_effects.is_empty()
	if active_effects.is_empty():
		return
	var maximum_mana: int = maxi(GameState.get_stat("max_mana"), 1)
	var current_mana: int = GameState.get_stat("mana")
	var usable_cap: int = get_usable_mana_cap()
	var reserved: int = get_reserved_mana()
	var names: Array[String] = []
	for effect_id: String in get_active_effect_ids():
		var definition: Resource = get_active_effect(effect_id)
		if definition != null:
			names.append(_definition_name(definition))
	hud_title.text = "CONCENTRATION • " + str(get_reservation_percent()) + "%"
	hud_bar.max_value = maximum_mana
	hud_bar.value = current_mana
	hud_detail.text = (
		", ".join(names)
		+ "\nMana " + str(current_mana) + " / " + str(usable_cap)
		+ " usable • " + str(reserved) + " reserved"
	)


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"concentration_active": not active_effects.is_empty(),
		"effect": get_effect_id(),
		"active_effects": get_active_effect_ids(),
		"active_effect_count": get_active_effect_count(),
		"reservation_percent": get_reservation_percent(),
		"reservation_fraction": get_total_reservation_fraction(),
		"usable_mana_cap": get_usable_mana_cap(),
		"reserved_mana": get_reserved_mana(),
		"remaining_budget_percent": roundi(maxf(maximum_total_reservation_fraction - get_total_reservation_fraction(), 0.0) * 100.0),
		"cost_overrides": ability_cost_cache.size(),
		"multi_concentration": true,
	}
