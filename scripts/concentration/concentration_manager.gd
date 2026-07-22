extends Node
class_name ConcentrationManager

signal effect_activated(effect_id: String, usable_mana_cap: int, reserved_mana: int)
signal effect_deactivated(effect_id: String)
signal concentration_updated(current_mana: int, usable_mana_cap: int, reserved_mana: int)

@export var passive_mana_regeneration_per_second: float = 0.0
@export var show_hud: bool = true

var active_effect: Resource = null
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
	if active_effect != null:
		enforce_mana_cap()
	regenerate_mana(delta)
	refresh_hud()


func _exit_tree() -> void:
	deactivate_effect(false)


func activate_effect(definition: Resource, ability_caster: Node = null) -> bool:
	if definition == null:
		return false

	if active_effect != null:
		deactivate_effect(false)

	active_effect = definition
	active_ability_caster = ability_caster if ability_caster != null else find_player_ability_caster()
	mana_regeneration_accumulator = 0.0
	cache_and_apply_ability_costs()
	enforce_mana_cap()
	refresh_hud()

	var effect_id: String = get_effect_id()
	effect_activated.emit(effect_id, get_usable_mana_cap(), get_reserved_mana())
	show_message(
		get_effect_display_name()
		+ " reserves "
		+ str(get_reservation_percent())
		+ "% mana."
	)
	return true


func deactivate_effect(show_feedback: bool = true) -> void:
	if active_effect == null:
		return

	var previous_effect_id: String = get_effect_id()
	var previous_display_name: String = get_effect_display_name()
	restore_ability_costs()
	active_effect = null
	active_ability_caster = null
	mana_regeneration_accumulator = 0.0
	refresh_hud()
	effect_deactivated.emit(previous_effect_id)

	if show_feedback:
		show_message(previous_display_name + " released. Reserved mana can regenerate again.")


func toggle_effect(definition: Resource, ability_caster: Node = null) -> bool:
	if definition == null:
		return false
	var incoming_id: String = str(definition.get("effect_id"))
	if active_effect != null and incoming_id == get_effect_id():
		deactivate_effect()
		return false
	return activate_effect(definition, ability_caster)


func get_usable_mana_cap() -> int:
	var maximum_mana: int = max(GameState.get_stat("max_mana"), 0)
	if active_effect == null:
		return maximum_mana
	if active_effect.has_method("get_usable_mana_cap"):
		return int(active_effect.call("get_usable_mana_cap", maximum_mana))
	var fraction: float = clampf(float(active_effect.get("mana_reservation_fraction")), 0.0, 0.95)
	return max(maximum_mana - int(ceil(float(maximum_mana) * fraction)), 0)


func get_reserved_mana() -> int:
	return max(GameState.get_stat("max_mana") - get_usable_mana_cap(), 0)


func get_reservation_percent() -> int:
	if active_effect == null:
		return 0
	return int(round(clampf(float(active_effect.get("mana_reservation_fraction")), 0.0, 0.95) * 100.0))


func is_element_free(element: String) -> bool:
	if active_effect == null:
		return false
	if active_effect.has_method("makes_element_free"):
		return bool(active_effect.call("makes_element_free", element))
	var free_elements_value: Variant = active_effect.get("free_elements")
	return free_elements_value is Array and (free_elements_value as Array).has(element.to_lower().strip_edges())


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

	mana_regeneration_accumulator += max(delta, 0.0) * passive_mana_regeneration_per_second
	var whole_units: int = int(floor(mana_regeneration_accumulator))
	if whole_units <= 0:
		return
	mana_regeneration_accumulator -= float(whole_units)
	GameState.set_stat("mana", min(current_mana + whole_units, cap))


func cache_and_apply_ability_costs() -> void:
	ability_cost_cache.clear()
	if active_ability_caster == null:
		return

	var loadout_value: Variant = active_ability_caster.get("loadout")
	if loadout_value == null:
		return
	var equipped_value: Variant = loadout_value.get("equipped_abilities")
	if not (equipped_value is Array):
		return

	for ability_value: Variant in equipped_value as Array:
		if ability_value == null or not (ability_value is Resource):
			continue
		var ability: Resource = ability_value as Resource
		var ability_id: int = ability.get_instance_id()
		if ability_cost_cache.has(ability_id):
			continue

		var original_cost: int = int(ability.get("mana_cost"))
		ability_cost_cache[ability_id] = {
			"ability": ability,
			"mana_cost": original_cost,
		}

		var element: String = str(ability.get("element")).to_lower().strip_edges()
		var multiplier: float = get_element_cost_multiplier(element)
		ability.set("mana_cost", int(ceil(float(original_cost) * multiplier)))


func get_element_cost_multiplier(element: String) -> float:
	if active_effect == null:
		return 1.0
	if active_effect.has_method("get_element_cost_multiplier"):
		return clampf(float(active_effect.call("get_element_cost_multiplier", element)), 0.0, 1.0)
	return 0.0 if is_element_free(element) else 1.0


func restore_ability_costs() -> void:
	for cache_value: Variant in ability_cost_cache.values():
		if not (cache_value is Dictionary):
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
	return str(active_effect.get("effect_id")) if active_effect != null else ""


func get_effect_display_name() -> String:
	return str(active_effect.get("display_name")) if active_effect != null else "Concentration"


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
	hud_panel.offset_left = -330.0
	hud_panel.offset_top = 24.0
	hud_panel.offset_right = -24.0
	hud_panel.offset_bottom = 148.0

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
	var bar_background := StyleBoxFlat.new()
	bar_background.bg_color = Color(0.17, 0.18, 0.23, 0.95)
	bar_background.set_corner_radius_all(7)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.12, 0.48, 0.94, 0.95)
	bar_fill.set_corner_radius_all(7)
	hud_bar.add_theme_stylebox_override("background", bar_background)
	hud_bar.add_theme_stylebox_override("fill", bar_fill)
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

	hud_panel.visible = active_effect != null
	if active_effect == null:
		return

	var maximum_mana: int = max(GameState.get_stat("max_mana"), 1)
	var current_mana: int = GameState.get_stat("mana")
	var usable_cap: int = get_usable_mana_cap()
	var reserved: int = get_reserved_mana()
	var free_elements_value: Variant = active_effect.get("free_elements")
	var free_names: Array[String] = []
	if free_elements_value is Array:
		for element_value: Variant in free_elements_value as Array:
			free_names.append(str(element_value).capitalize())

	hud_title.text = get_effect_display_name().to_upper() + " • " + str(get_reservation_percent()) + "% CONCENTRATION"
	hud_bar.max_value = maximum_mana
	hud_bar.value = current_mana
	hud_detail.text = (
		"Mana " + str(current_mana) + " / " + str(usable_cap)
		+ " usable • " + str(reserved) + " reserved\n"
		+ ((", ".join(free_names) + " spells are FREE") if not free_names.is_empty() else "No free element")
	)


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"concentration_active": active_effect != null,
		"effect": get_effect_id(),
		"reservation_percent": get_reservation_percent(),
		"usable_mana_cap": get_usable_mana_cap(),
		"reserved_mana": get_reserved_mana(),
		"cost_overrides": ability_cost_cache.size(),
	}
