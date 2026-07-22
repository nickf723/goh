extends Node
class_name ElectricalMaterialResponse

const CombatFeedback = preload("res://scripts/combat/combat_feedback.gd")

signal energized(source_name: String, conductivity: float)

@export var material_profile: PhysicalMaterialProfile
@export_range(0.0, 1.0, 0.01) var minimum_conductivity: float = 0.1
@export var reaction_name: String = "Conductive"
@export var feedback_color: Color = Color(0.62, 0.78, 1.0, 1.0)
@export var feedback_radius: float = 1.45
@export var feedback_duration: float = 0.32

var accepted_pulse_count: int = 0
var rejected_pulse_count: int = 0
var last_source_name: String = "none"


func _ready() -> void:
	add_to_group("debuggable")
	add_to_group("lab_resettable")


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if payload == null or not is_electrical_payload(payload):
		return {}

	if material_profile == null or not material_profile.is_conductive(minimum_conductivity):
		rejected_pulse_count += 1
		return {
			"message": get_parent().name + " does not conduct the electrical pulse.",
			"objective": "Compare conductive and insulating materials.",
		}

	accepted_pulse_count += 1
	last_source_name = payload.source_name
	var conductivity: float = material_profile.electrical_conductivity

	CombatFeedback.show_reaction_feedback(
		get_parent(),
		"conductive_material",
		{
			"reaction_name": reaction_name,
			"visual_style": "conduct",
			"visual_color": feedback_color,
			"visual_radius": feedback_radius,
			"visual_duration": feedback_duration,
		}
	)
	energized.emit(payload.source_name, conductivity)

	return {
		"message": payload.source_name + " energizes " + get_parent().name + ".",
		"objective": "Conductive props can later bridge circuits or carry Lightning effects.",
		"conductivity": conductivity,
	}


func is_electrical_payload(payload: DamagePayload) -> bool:
	if payload.element.to_lower().strip_edges() == "lightning":
		return true

	for raw_tag: String in payload.tags:
		if raw_tag.to_lower().strip_edges() in ["lightning", "electrical", "shock", "conduct"]:
			return true

	return false


func reset_target() -> void:
	accepted_pulse_count = 0
	rejected_pulse_count = 0
	last_source_name = "none"


func get_debug_data() -> Dictionary:
	return {
		"electrical_material_response": true,
		"material": material_profile.material_id if material_profile != null else "none",
		"conductivity": material_profile.electrical_conductivity if material_profile != null else 0.0,
		"accepted_pulses": accepted_pulse_count,
		"rejected_pulses": rejected_pulse_count,
		"last_source": last_source_name,
	}
