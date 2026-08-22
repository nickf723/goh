extends Resource
class_name MobLocomotionDefinition

@export var capability_id: String = ""
@export var display_name: String = ""
@export var capability_kind: String = "mode"
@export var dimension: String = "planar"
@export var medium_tags: Array[String] = []
@export var required_any_body_tags: Array[String] = []
@export var required_all_body_tags: Array[String] = []
@export var requires_capabilities: Array[String] = []
@export var transition_capabilities: Array[String] = []
@export var speed_multiplier: float = 1.0
@export var acceleration_multiplier: float = 1.0
@export var turn_multiplier: float = 1.0
@export var uses_gravity: bool = true
@export var vertical_control: float = 0.0


static func from_dictionary(data: Dictionary) -> MobLocomotionDefinition:
	var definition := MobLocomotionDefinition.new()
	definition.capability_id = str(
		data.get("id", data.get("capability_id", ""))
	).to_lower().strip_edges()
	definition.display_name = str(data.get(
		"display_name",
		definition.capability_id.replace("_", " ").capitalize()
	))
	definition.capability_kind = str(data.get("kind", "mode")).to_lower().strip_edges()
	definition.dimension = str(data.get("dimension", "planar")).to_lower().strip_edges()
	definition.medium_tags = _string_array(data.get("medium_tags", []))
	definition.required_any_body_tags = _string_array(
		data.get("required_any_body_tags", [])
	)
	definition.required_all_body_tags = _string_array(
		data.get("required_all_body_tags", [])
	)
	definition.requires_capabilities = _string_array(
		data.get("requires_capabilities", [])
	)
	definition.transition_capabilities = _string_array(
		data.get("transition_capabilities", [])
	)
	definition.speed_multiplier = maxf(float(data.get("speed_multiplier", 1.0)), 0.0)
	definition.acceleration_multiplier = maxf(
		float(data.get("acceleration_multiplier", 1.0)),
		0.0
	)
	definition.turn_multiplier = maxf(float(data.get("turn_multiplier", 1.0)), 0.0)
	definition.uses_gravity = bool(data.get("uses_gravity", true))
	definition.vertical_control = clampf(float(data.get("vertical_control", 0.0)), 0.0, 1.0)
	return definition


func to_dictionary() -> Dictionary:
	return {
		"id": capability_id,
		"display_name": display_name,
		"kind": capability_kind,
		"dimension": dimension,
		"medium_tags": medium_tags.duplicate(),
		"required_any_body_tags": required_any_body_tags.duplicate(),
		"required_all_body_tags": required_all_body_tags.duplicate(),
		"requires_capabilities": requires_capabilities.duplicate(),
		"transition_capabilities": transition_capabilities.duplicate(),
		"speed_multiplier": speed_multiplier,
		"acceleration_multiplier": acceleration_multiplier,
		"turn_multiplier": turn_multiplier,
		"uses_gravity": uses_gravity,
		"vertical_control": vertical_control,
	}


func supports_body(body_tags: Array[String]) -> bool:
	var normalized_tags: Array[String] = _string_array(body_tags)
	for required_tag: String in required_all_body_tags:
		if not normalized_tags.has(required_tag):
			return false
	if required_any_body_tags.is_empty():
		return true
	for accepted_tag: String in required_any_body_tags:
		if normalized_tags.has(accepted_tag):
			return true
	return false


func has_dependencies(available_capabilities: Array[String]) -> bool:
	for required_id: String in requires_capabilities:
		if not available_capabilities.has(required_id):
			return false
	return true


func validate() -> Array[String]:
	var failures: Array[String] = []
	if capability_id == "":
		failures.append("locomotion capability id is empty")
	if display_name == "":
		failures.append(capability_id + " has no display name")
	if not ["mode", "modifier", "transition"].has(capability_kind):
		failures.append(capability_id + " has invalid kind " + capability_kind)
	if not ["planar", "surface", "volumetric"].has(dimension):
		failures.append(capability_id + " has invalid dimension " + dimension)
	if speed_multiplier <= 0.0:
		failures.append(capability_id + " has a non-positive speed multiplier")
	if acceleration_multiplier <= 0.0:
		failures.append(capability_id + " has a non-positive acceleration multiplier")
	if turn_multiplier <= 0.0:
		failures.append(capability_id + " has a non-positive turn multiplier")
	return failures


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var normalized: String = str(raw).to_lower().strip_edges()
			if normalized != "" and not result.has(normalized):
				result.append(normalized)
	return result
