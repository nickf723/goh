extends Node
class_name GasExposureReceiver

const GameplayEffectAccessScript = preload("res://scripts/effects/gameplay_effect_access.gd")

signal exposure_changed(gas_id: String, density: float, dose: float)
signal exposure_began(gas_id: String)
signal exposure_ended(gas_id: String)
signal gas_effect_applied(gas_id: String, dose: float)

@export var sample_offset: Vector3 = Vector3(0.0, 0.85, 0.0)
@export_range(0.02, 1.0, 0.01) var sample_interval: float = 0.12
@export_range(0.0, 1.0, 0.01) var effect_dose_threshold: float = 0.35
@export_range(0.0, 4.0, 0.01) var exposure_response_multiplier: float = 1.0
@export var apply_player_damage: bool = true
@export var create_player_obscuration_overlay: bool = true
@export_range(0.0, 0.8, 0.01) var maximum_obscuration_alpha: float = 0.36
@export var show_messages: bool = true
@export var resettable: bool = true

var gas_manager: Node = null
var sample_timer: float = 0.0
var densities: Dictionary = {}
var doses: Dictionary = {}
var damage_timers: Dictionary = {}
var active_exposures: Dictionary = {}
var obscuration_layer: CanvasLayer = null
var obscuration_rect: ColorRect = null


func _ready() -> void:
	add_to_group("gas_exposure_receivers")
	add_to_group("debuggable")
	if resettable:
		add_to_group("lab_resettable")
	resolve_manager()
	call_deferred("build_obscuration_overlay")


func _process(delta: float) -> void:
	sample_timer -= max(delta, 0.0)
	if sample_timer > 0.0:
		return
	var step_delta: float = max(sample_interval, 0.02)
	sample_timer = step_delta
	update_exposure(step_delta)


func resolve_manager() -> Node:
	if gas_manager != null and is_instance_valid(gas_manager):
		return gas_manager
	gas_manager = get_tree().get_first_node_in_group("gas_manager")
	return gas_manager


func get_sample_position() -> Vector3:
	var actor: Node3D = get_parent() as Node3D
	if actor == null:
		return Vector3.ZERO
	return actor.global_position + actor.global_transform.basis * sample_offset


func update_exposure(delta: float) -> void:
	var manager: Node = resolve_manager()
	if manager == null or not manager.has_method("sample_breakdown"):
		return
	var sampled_value: Variant = manager.call("sample_breakdown", get_sample_position())
	var breakdown: Dictionary = sampled_value as Dictionary if sampled_value is Dictionary else {}
	var gas_ids: Array[String] = []
	for raw_id: Variant in doses.keys():
		gas_ids.append(str(raw_id))
	for raw_id: Variant in breakdown.keys():
		var gas_id: String = str(raw_id)
		if not gas_ids.has(gas_id):
			gas_ids.append(gas_id)

	for gas_id: String in gas_ids:
		var density: float = max(float(breakdown.get(gas_id, 0.0)), 0.0)
		var definition: GasDefinition = find_definition(gas_id)
		if definition == null:
			continue
		var previous_dose: float = float(doses.get(gas_id, 0.0))
		var dose: float = previous_dose
		if definition.is_exposure_active(density):
			var density_range: float = max(definition.maximum_density - definition.exposure_threshold, 0.001)
			var normalized_excess: float = clampf(
				(density - definition.exposure_threshold) / density_range,
				0.0,
				1.0
			)
			dose += definition.exposure_gain_rate * exposure_response_multiplier * max(normalized_excess, 0.08) * delta
		else:
			dose -= definition.exposure_decay_rate * delta
		dose = clampf(dose, 0.0, 1.0)
		densities[gas_id] = density
		doses[gas_id] = dose
		exposure_changed.emit(gas_id, density, dose)
		update_exposure_boundary(gas_id, previous_dose, dose)
		update_gas_effect(gas_id, definition, dose, delta)

	update_obscuration_overlay()


func update_exposure_boundary(gas_id: String, previous_dose: float, dose: float) -> void:
	var was_active: bool = previous_dose >= effect_dose_threshold
	var is_active: bool = dose >= effect_dose_threshold
	active_exposures[gas_id] = is_active
	if is_active and not was_active:
		exposure_began.emit(gas_id)
		show_message(gas_id.capitalize() + " concentration reaches an effective dose.")
	elif was_active and not is_active:
		exposure_ended.emit(gas_id)
		show_message(gas_id.capitalize() + " exposure clears.")


func update_gas_effect(gas_id: String, definition: GasDefinition, dose: float, delta: float) -> void:
	if dose < effect_dose_threshold:
		damage_timers[gas_id] = definition.damage_interval
		return
	if definition.obscures_vision:
		active_exposures[gas_id] = true
	if not definition.harmful:
		return

	var actor: Node = get_parent()
	if gas_id == "poison" and actor != null and actor.is_in_group("player"):
		sustain_player_poison(definition, dose)
		return

	var timer: float = float(damage_timers.get(gas_id, definition.damage_interval)) - delta
	if timer > 0.0:
		damage_timers[gas_id] = timer
		return
	damage_timers[gas_id] = max(definition.damage_interval, 0.05)
	apply_gas_effect(gas_id, definition, dose)


func sustain_player_poison(definition: GasDefinition, dose: float) -> void:
	var effect_ids: Array[String] = ["poisoned"]
	var source_tags: Array[String] = ["harmful", "ailment", "poison", "gas"]
	var linger_duration: float = maxf(definition.damage_interval * 2.0 + 0.25, 4.0)
	GameplayEffectAccessScript.set_effect_source(
		"gas_exposure:poison",
		effect_ids,
		linger_duration,
		source_tags
	)
	gas_effect_applied.emit("poison", dose)


func apply_gas_effect(gas_id: String, definition: GasDefinition, dose: float) -> void:
	var actor: Node = get_parent()
	var status_receiver: Node = actor.get_node_or_null("StatusReceiver") if actor != null else null
	if status_receiver != null and definition.status_name != "":
		if status_receiver.has_method("sustain_status"):
			status_receiver.call(
				" sustain_status".strip_edges(),
				definition.status_name,
				max(definition.status_duration, definition.damage_interval + 0.1),
				max(definition.status_strength, 1.0),
				definition.display_name
			)
		elif status_receiver.has_method("apply_status"):
			status_receiver.call(
				"apply_status",
				definition.status_name,
				max(definition.status_duration, definition.damage_interval + 0.1),
				max(definition.status_strength, 1.0),
				definition.display_name
			)
	elif apply_player_damage and actor != null and actor.is_in_group("player") and definition.damage_per_tick > 0:
		GameState.take_damage(definition.damage_per_tick)

	gas_effect_applied.emit(gas_id, dose)
	show_message(definition.display_name + " exposure applies its effect.")


func find_definition(gas_id: String) -> GasDefinition:
	var manager: Node = resolve_manager()
	if manager != null and manager.has_method("find_definition"):
		var definition_value: Variant = manager.call("find_definition", gas_id)
		if definition_value is GasDefinition:
			return definition_value as GasDefinition
	return null


func build_obscuration_overlay() -> void:
	if not create_player_obscuration_overlay:
		return
	var actor: Node = get_parent()
	if actor == null or not actor.is_in_group("player"):
		return
	if obscuration_layer != null:
		return
	obscuration_layer = CanvasLayer.new()
	obscuration_layer.name = "GasObscurationLayer"
	obscuration_layer.layer = 80
	add_child(obscuration_layer)
	obscuration_rect = ColorRect.new()
	obscuration_rect.name = "GasObscuration"
	obscuration_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	obscuration_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	obscuration_rect.color = Color(0.42, 0.48, 0.52, 0.0)
	obscuration_layer.add_child(obscuration_rect)


func update_obscuration_overlay() -> void:
	if obscuration_rect == null:
		return
	var strongest_dose: float = 0.0
	var overlay_color: Color = Color(0.42, 0.48, 0.52, 1.0)
	for raw_id: Variant in doses.keys():
		var gas_id: String = str(raw_id)
		var definition: GasDefinition = find_definition(gas_id)
		if definition == null or not definition.obscures_vision:
			continue
		var dose: float = float(doses.get(gas_id, 0.0))
		if dose <= strongest_dose:
			continue
		strongest_dose = dose
		overlay_color = Color(
			definition.visual_color.r,
			definition.visual_color.g,
			definition.visual_color.b,
			1.0
		)
	overlay_color.a = clampf(strongest_dose * maximum_obscuration_alpha, 0.0, maximum_obscuration_alpha)
	obscuration_rect.color = overlay_color


func get_density(gas_id: String) -> float:
	return float(densities.get(gas_id, 0.0))


func get_dose(gas_id: String) -> float:
	return float(doses.get(gas_id, 0.0))


func has_effective_exposure(gas_id: String) -> bool:
	return bool(active_exposures.get(gas_id, false))


func get_total_dose() -> float:
	var total: float = 0.0
	for raw_value: Variant in doses.values():
		total += float(raw_value)
	return total


func clear_exposure() -> void:
	GameplayEffectAccessScript.remove_effect_source("gas_exposure:poison")
	densities.clear()
	doses.clear()
	damage_timers.clear()
	active_exposures.clear()
	sample_timer = 0.0
	update_obscuration_overlay()


func reset_target() -> void:
	clear_exposure()


func show_message(text: String) -> void:
	if not show_messages or text == "":
		return
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"gas_exposure_receiver": true,
		"sample_position": get_sample_position(),
		"densities": densities.duplicate(true),
		"doses": doses.duplicate(true),
		"active": active_exposures.duplicate(true),
		"total_dose": snapped(get_total_dose(), 0.01),
		"obscuration_alpha": obscuration_rect.color.a if obscuration_rect != null else 0.0,
	}
