extends Node
class_name MobVitalsComponent

const SpeciesCatalog = preload("res://scripts/mobs/mob_species_catalog.gd")

signal vitals_changed(snapshot: Dictionary)
signal damage_received(payload: Variant, result: Dictionary)
signal recovery_received(effect: Dictionary, result: Dictionary)
signal incapacitation_changed(incapacitated: bool)

@export var species_id: String = ""
@export var maximum_health_override: float = -1.0
@export var maximum_stamina_override: float = -1.0
@export var start_full: bool = true

var maximum_health: float = 1.0
var health: float = 1.0
var maximum_stamina: float = 10.0
var stamina: float = 10.0
var incapacitated: bool = false
var configured: bool = false
var last_damage_result: Dictionary = {}
var last_recovery_result: Dictionary = {}


func _ready() -> void:
	if not configured:
		configure(species_id)


func configure(
	new_species_id: String,
	overrides: Dictionary = {},
	preserve_ratios: bool = false
) -> Dictionary:
	var old_health_ratio: float = get_health_ratio()
	var old_stamina_ratio: float = get_stamina_ratio()
	species_id = new_species_id.to_lower().strip_edges()
	var base_stats: Dictionary = {}
	var definition: MobSpeciesDefinition = SpeciesCatalog.get_definition(species_id)
	if definition != null:
		base_stats = definition.base_stats.duplicate(true)
	var authored_health: float = float(overrides.get(
		"maximum_health",
		overrides.get(
			"health",
			maximum_health_override
			if maximum_health_override > 0.0
			else base_stats.get("health", 1.0)
		)
	))
	var authored_stamina: float = float(overrides.get(
		"maximum_stamina",
		overrides.get(
			"stamina",
			maximum_stamina_override
			if maximum_stamina_override > 0.0
			else base_stats.get("stamina", 10.0)
		)
	))
	maximum_health = maxf(authored_health, 1.0)
	maximum_stamina = maxf(authored_stamina, 0.0)
	if preserve_ratios and configured:
		health = maximum_health * old_health_ratio
		stamina = maximum_stamina * old_stamina_ratio
	elif start_full or not configured:
		health = maximum_health
		stamina = maximum_stamina
	else:
		health = clampf(health, 0.0, maximum_health)
		stamina = clampf(stamina, 0.0, maximum_stamina)
	configured = true
	_update_incapacitation()
	_emit_changed()
	return to_dictionary()


func reset_to_full() -> Dictionary:
	health = maximum_health
	stamina = maximum_stamina
	last_damage_result.clear()
	last_recovery_result.clear()
	_update_incapacitation()
	_emit_changed()
	return to_dictionary()


func receive_damage_payload(payload: Variant) -> Dictionary:
	var amount: float = maxf(_payload_number(payload, "amount", 0.0), 0.0)
	var result: Dictionary = apply_damage(
		amount,
		_payload_text(payload, "source_name", "Unknown source")
	)
	last_damage_result = result.duplicate(true)
	damage_received.emit(payload, result)
	return result


func apply_damage(amount: float, source_name: String = "") -> Dictionary:
	var health_before: float = health
	var applied: float = minf(maxf(amount, 0.0), health)
	health = maxf(health - applied, 0.0)
	_update_incapacitation()
	var result: Dictionary = {
		"ok": true,
		"message": (
			(source_name + " deals " if source_name != "" else "")
			+ str(int(round(applied)))
			+ " damage."
		),
		"damage_dealt": applied,
		"health_before": health_before,
		"health": health,
		"maximum_health": maximum_health,
		"health_ratio": get_health_ratio(),
		"incapacitated": incapacitated,
	}
	last_damage_result = result.duplicate(true)
	_emit_changed()
	return result


func receive_mob_recovery(
	effect: Dictionary,
	request: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = apply_recovery(
		maxf(float(effect.get("health", 0.0)), 0.0),
		maxf(float(effect.get("stamina", 0.0)), 0.0)
	)
	result["request_id"] = str(request.get("request_id", ""))
	result["move_id"] = str(request.get("move_id", ""))
	last_recovery_result = result.duplicate(true)
	recovery_received.emit(effect, result)
	return result


func apply_recovery(
	health_amount: float,
	stamina_amount: float = 0.0
) -> Dictionary:
	var health_before: float = health
	var stamina_before: float = stamina
	health = minf(health + maxf(health_amount, 0.0), maximum_health)
	stamina = minf(stamina + maxf(stamina_amount, 0.0), maximum_stamina)
	_update_incapacitation()
	var result: Dictionary = {
		"ok": true,
		"health_recovered": health - health_before,
		"stamina_recovered": stamina - stamina_before,
		"health": health,
		"maximum_health": maximum_health,
		"stamina": stamina,
		"maximum_stamina": maximum_stamina,
		"health_ratio": get_health_ratio(),
		"stamina_ratio": get_stamina_ratio(),
		"incapacitated": incapacitated,
	}
	last_recovery_result = result.duplicate(true)
	_emit_changed()
	return result


func spend_stamina(amount: float) -> Dictionary:
	var requested: float = maxf(amount, 0.0)
	var spent: float = minf(requested, stamina)
	stamina -= spent
	_emit_changed()
	return {
		"ok": spent >= requested,
		"requested": requested,
		"spent": spent,
		"stamina": stamina,
		"stamina_ratio": get_stamina_ratio(),
	}


func get_health_ratio() -> float:
	return health / maximum_health if maximum_health > 0.0 else 0.0


func get_stamina_ratio() -> float:
	return stamina / maximum_stamina if maximum_stamina > 0.0 else 0.0


func to_dictionary() -> Dictionary:
	return {
		"species_id": species_id,
		"health": health,
		"maximum_health": maximum_health,
		"health_ratio": get_health_ratio(),
		"stamina": stamina,
		"maximum_stamina": maximum_stamina,
		"stamina_ratio": get_stamina_ratio(),
		"incapacitated": incapacitated,
		"last_damage_result": last_damage_result.duplicate(true),
		"last_recovery_result": last_recovery_result.duplicate(true),
	}


func _update_incapacitation() -> void:
	var next_value: bool = health <= 0.0
	if next_value == incapacitated:
		return
	incapacitated = next_value
	incapacitation_changed.emit(incapacitated)


func _emit_changed() -> void:
	vitals_changed.emit(to_dictionary())


func _payload_number(
	payload: Variant,
	property_name: String,
	fallback: float
) -> float:
	if payload is Dictionary:
		return float((payload as Dictionary).get(property_name, fallback))
	if payload is Object:
		var raw_value: Variant = (payload as Object).get(property_name)
		return fallback if raw_value == null else float(raw_value)
	return fallback


func _payload_text(
	payload: Variant,
	property_name: String,
	fallback: String
) -> String:
	if payload is Dictionary:
		return str((payload as Dictionary).get(property_name, fallback))
	if payload is Object:
		var raw_value: Variant = (payload as Object).get(property_name)
		return fallback if raw_value == null else str(raw_value)
	return fallback
