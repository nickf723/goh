extends Node
class_name MobLocomotionExecutor

const LocomotionCatalog = preload(
	"res://scripts/mobs/mob_locomotion_catalog.gd"
)
const SpeciesCatalog = preload(
	"res://scripts/mobs/mob_species_catalog.gd"
)

signal mode_changed(previous_mode: String, active_mode: String, reason: String)
signal mode_rejected(requested_mode: String, reason: String)
signal medium_availability_changed(
	active_mode: String,
	available: bool,
	medium_tags: Array[String]
)

@export var surface_body_offset: float = 0.72
@export var buoyancy_response: float = 4.5
@export var current_influence: float = 1.0

var species_id: String = ""
var profile: Dictionary = {}
var active_mode: String = ""
var initial_mode: String = ""
var active_medium_tags: Array[String] = []
var medium_available: bool = false
var active_water_volumes: Array[Node] = []
var last_solution: Dictionary = {}
var transition_count: int = 0
var rejection_count: int = 0


func configure_species(
	requested_species_id: String,
	requested_mode: String = ""
) -> Dictionary:
	species_id = requested_species_id.to_lower().strip_edges()
	var species: MobSpeciesDefinition = SpeciesCatalog.get_definition(species_id)
	if species == null:
		return _configuration_failure(
			"unknown species " + species_id
		)
	return configure(
		species.body_tags,
		species.locomotion_tags,
		requested_mode
	)


func configure(
	body_tags: Array[String],
	locomotion_tags: Array[String],
	requested_mode: String = ""
) -> Dictionary:
	profile = LocomotionCatalog.resolve_profile(body_tags, locomotion_tags)
	active_water_volumes.clear()
	active_mode = ""
	initial_mode = ""
	active_medium_tags.clear()
	medium_available = false
	last_solution.clear()
	transition_count = 0
	rejection_count = 0

	var failures: Array[String] = _string_array(profile.get("failures", []))
	if not failures.is_empty():
		return {
			"ok": false,
			"failures": failures,
			"profile": profile.duplicate(true),
		}

	var modes: Array[String] = _string_array(profile.get("modes", []))
	var selected_mode: String = LocomotionCatalog.normalize_id(requested_mode)
	if selected_mode == "":
		selected_mode = "ground" if modes.has("ground") else str(modes[0])
	if not modes.has(selected_mode):
		return _configuration_failure(
			"unsupported initial locomotion mode " + selected_mode
		)

	var definition: MobLocomotionDefinition = LocomotionCatalog.get_definition(
		selected_mode
	)
	active_mode = selected_mode
	initial_mode = selected_mode
	active_medium_tags = (
		definition.medium_tags.duplicate()
		if definition != null
		else []
	)
	medium_available = definition != null
	return {
		"ok": true,
		"active_mode": active_mode,
		"profile": profile.duplicate(true),
	}


func request_mode(
	requested_mode: String,
	context: Dictionary = {}
) -> Dictionary:
	var normalized_mode: String = LocomotionCatalog.normalize_id(
		requested_mode
	)
	var modes: Array[String] = _string_array(profile.get("modes", []))
	if not modes.has(normalized_mode):
		return _reject_mode(
			normalized_mode,
			"mode is not supported by the configured locomotion profile"
		)

	var definition: MobLocomotionDefinition = LocomotionCatalog.get_definition(
		normalized_mode
	)
	if definition == null or definition.capability_kind != "mode":
		return _reject_mode(normalized_mode, "mode definition is unavailable")

	var medium_tags: Array[String] = _string_array(
		context.get("medium_tags", [])
	)
	var require_medium: bool = bool(context.get("require_medium", false))
	if require_medium and medium_tags.is_empty():
		return _reject_mode(
			normalized_mode,
			"mode requires an explicit environment medium"
		)
	if (
		not medium_tags.is_empty()
		and not _arrays_intersect(medium_tags, definition.medium_tags)
	):
		return _reject_mode(
			normalized_mode,
			"environment media "
			+ str(medium_tags)
			+ " do not support "
			+ normalized_mode
		)

	var force_transition: bool = bool(context.get("force", false))
	if active_mode != "" and active_mode != normalized_mode and not force_transition:
		var current_definition: MobLocomotionDefinition = (
			LocomotionCatalog.get_definition(active_mode)
		)
		if (
			current_definition == null
			or not current_definition.transition_capabilities.has(normalized_mode)
		):
			return _reject_mode(
				normalized_mode,
				"transition from " + active_mode + " is not supported"
			)

	var previous_mode: String = active_mode
	active_mode = normalized_mode
	active_medium_tags = (
		medium_tags
		if not medium_tags.is_empty()
		else definition.medium_tags.duplicate()
	)
	medium_available = true
	if previous_mode != active_mode:
		transition_count += 1
		mode_changed.emit(
			previous_mode,
			active_mode,
			str(context.get("reason", "requested"))
		)
	medium_availability_changed.emit(
		active_mode,
		medium_available,
		active_medium_tags.duplicate()
	)
	return {
		"ok": true,
		"previous_mode": previous_mode,
		"active_mode": active_mode,
		"medium_tags": active_medium_tags.duplicate(),
	}


func enter_water(volume: Node) -> void:
	if (
		volume != null
		and is_instance_valid(volume)
		and not active_water_volumes.has(volume)
	):
		active_water_volumes.append(volume)
	if not supports_mode("swimmer"):
		return
	request_mode("swimmer", {
		"medium_tags": ["water"],
		"require_medium": true,
		"reason": "entered_water",
	})


func exit_water(volume: Node) -> void:
	active_water_volumes.erase(volume)
	_prune_water_volumes()
	if not active_water_volumes.is_empty() or active_mode != "swimmer":
		return
	if supports_mode("ground"):
		request_mode("ground", {
			"medium_tags": ["land"],
			"require_medium": true,
			"reason": "exited_water",
		})
		return
	deactivate_current_medium("exited_water")


func deactivate_current_medium(reason: String = "medium_unavailable") -> void:
	if not medium_available:
		return
	medium_available = false
	active_medium_tags.clear()
	medium_availability_changed.emit(
		active_mode,
		false,
		[]
	)
	last_solution["medium_loss_reason"] = reason


func resolve_velocity(
	desired_direction: Vector3,
	current_velocity: Vector3,
	base_speed: float,
	base_acceleration: float,
	delta: float,
	context: Dictionary = {}
) -> Dictionary:
	var definition: MobLocomotionDefinition = get_active_definition()
	if definition == null:
		last_solution = {
			"ok": false,
			"error": "active locomotion definition is unavailable",
			"velocity": current_velocity,
			"uses_gravity": true,
		}
		return last_solution.duplicate(true)

	var multipliers: Dictionary = _get_active_multipliers()
	var speed_multiplier: float = float(
		multipliers.get("speed", 1.0)
	)
	var acceleration_multiplier: float = float(
		multipliers.get("acceleration", 1.0)
	)
	var direction: Vector3 = project_direction(desired_direction, context)
	var target_velocity: Vector3 = Vector3.ZERO
	if medium_available:
		target_velocity = direction * maxf(base_speed, 0.0) * speed_multiplier
		if active_mode == "swimmer":
			target_velocity += sample_total_current() * current_influence
			if absf(desired_direction.y) <= 0.001:
				var surface_y: float = get_surface_y()
				if surface_y > -INF:
					var maximum_vertical: float = (
						maxf(base_speed, 0.0)
						* definition.vertical_control
					)
					target_velocity.y = clampf(
						(
							surface_y
							- surface_body_offset
							- _actor_position_y()
						)
						* buoyancy_response,
						-maximum_vertical,
						maximum_vertical
					)
		var external_velocity: Variant = context.get(
			"external_velocity",
			Vector3.ZERO
		)
		if external_velocity is Vector3:
			target_velocity += external_velocity as Vector3

	var acceleration: float = (
		maxf(base_acceleration, 0.0)
		* acceleration_multiplier
	)
	var next_velocity: Vector3 = current_velocity
	if definition.dimension == "planar":
		next_velocity.x = move_toward(
			current_velocity.x,
			target_velocity.x,
			acceleration * delta
		)
		next_velocity.z = move_toward(
			current_velocity.z,
			target_velocity.z,
			acceleration * delta
		)
	elif medium_available:
		next_velocity = current_velocity.move_toward(
			target_velocity,
			acceleration * delta
		)
	else:
		next_velocity.x = move_toward(
			current_velocity.x,
			0.0,
			acceleration * delta
		)
		next_velocity.z = move_toward(
			current_velocity.z,
			0.0,
			acceleration * delta
		)

	last_solution = {
		"ok": true,
		"mode": active_mode,
		"dimension": definition.dimension,
		"medium_available": medium_available,
		"medium_tags": active_medium_tags.duplicate(),
		"direction": direction,
		"target_velocity": target_velocity,
		"velocity": next_velocity,
		"uses_gravity": definition.uses_gravity or not medium_available,
		"vertical_control": definition.vertical_control,
		"speed_multiplier": speed_multiplier,
		"acceleration_multiplier": acceleration_multiplier,
		"turn_multiplier": float(multipliers.get("turn", 1.0)),
	}
	return last_solution.duplicate(true)


func project_direction(
	raw_direction: Vector3,
	context: Dictionary = {}
) -> Vector3:
	var definition: MobLocomotionDefinition = get_active_definition()
	if definition == null or raw_direction.length_squared() <= 0.0001:
		return Vector3.ZERO
	var direction: Vector3 = raw_direction
	match definition.dimension:
		"planar":
			direction.y = 0.0
		"surface":
			var raw_normal: Variant = context.get(
				"surface_normal",
				Vector3.ZERO
			)
			if not raw_normal is Vector3:
				return Vector3.ZERO
			var surface_normal: Vector3 = raw_normal as Vector3
			if surface_normal.length_squared() <= 0.0001:
				return Vector3.ZERO
			direction = direction.slide(surface_normal.normalized())
		"volumetric":
			pass
	return (
		direction.normalized()
		if direction.length_squared() > 0.0001
		else Vector3.ZERO
	)


func supports_mode(mode_id: String) -> bool:
	return _string_array(profile.get("modes", [])).has(
		LocomotionCatalog.normalize_id(mode_id)
	)


func get_active_definition() -> MobLocomotionDefinition:
	return LocomotionCatalog.get_definition(active_mode)


func should_use_gravity() -> bool:
	var definition: MobLocomotionDefinition = get_active_definition()
	return (
		definition == null
		or definition.uses_gravity
		or not medium_available
	)


func get_turn_multiplier() -> float:
	return float(_get_active_multipliers().get("turn", 1.0))


func get_context_tags() -> Array[String]:
	var tags: Array[String] = []
	if active_mode != "":
		tags.append("locomotion:" + active_mode)
		tags.append("locomotion_mode:" + active_mode)
	var definition: MobLocomotionDefinition = get_active_definition()
	if definition != null:
		tags.append("locomotion_dimension:" + definition.dimension)
	for medium_tag: String in active_medium_tags:
		tags.append("medium:" + medium_tag)
	if not medium_available:
		tags.append("locomotion_medium_unavailable")
	return tags


func get_surface_y() -> float:
	_prune_water_volumes()
	var result: float = -INF
	for volume: Node in active_water_volumes:
		if volume.has_method("get_surface_y"):
			result = maxf(result, float(volume.call("get_surface_y")))
	return result


func sample_total_current() -> Vector3:
	_prune_water_volumes()
	var result: Vector3 = Vector3.ZERO
	var actor_position: Vector3 = _actor_position()
	for volume: Node in active_water_volumes:
		if volume.has_method("sample_current"):
			var sampled: Variant = volume.call(
				"sample_current",
				actor_position
			)
			if sampled is Vector3:
				result += sampled as Vector3
	return result


func reset_executor() -> void:
	active_water_volumes.clear()
	last_solution.clear()
	transition_count = 0
	rejection_count = 0
	if initial_mode == "":
		active_mode = ""
		active_medium_tags.clear()
		medium_available = false
		return
	var definition: MobLocomotionDefinition = LocomotionCatalog.get_definition(
		initial_mode
	)
	active_mode = initial_mode
	active_medium_tags = (
		definition.medium_tags.duplicate()
		if definition != null
		else []
	)
	medium_available = definition != null


func get_debug_data() -> Dictionary:
	return {
		"species_id": species_id,
		"active_mode": active_mode,
		"initial_mode": initial_mode,
		"medium_available": medium_available,
		"medium_tags": active_medium_tags.duplicate(),
		"supported_modes": _string_array(profile.get("modes", [])),
		"modifiers": _string_array(profile.get("modifiers", [])),
		"transitions": _string_array(profile.get("transitions", [])),
		"water_volume_count": active_water_volumes.size(),
		"transition_count": transition_count,
		"rejection_count": rejection_count,
		"last_solution": last_solution.duplicate(true),
	}


func _get_active_multipliers() -> Dictionary:
	var speed: float = 1.0
	var acceleration: float = 1.0
	var turn: float = 1.0
	var definition: MobLocomotionDefinition = get_active_definition()
	if definition != null:
		speed *= definition.speed_multiplier
		acceleration *= definition.acceleration_multiplier
		turn *= definition.turn_multiplier
	for modifier_id: String in _string_array(profile.get("modifiers", [])):
		var modifier: MobLocomotionDefinition = LocomotionCatalog.get_definition(
			modifier_id
		)
		if modifier == null:
			continue
		if (
			not modifier.requires_capabilities.is_empty()
			and not modifier.requires_capabilities.has(active_mode)
		):
			continue
		speed *= modifier.speed_multiplier
		acceleration *= modifier.acceleration_multiplier
		turn *= modifier.turn_multiplier
	return {
		"speed": speed,
		"acceleration": acceleration,
		"turn": turn,
	}


func _actor_position() -> Vector3:
	var actor: Node3D = get_parent() as Node3D
	return actor.global_position if actor != null else Vector3.ZERO


func _actor_position_y() -> float:
	return _actor_position().y


func _prune_water_volumes() -> void:
	var valid: Array[Node] = []
	for volume: Node in active_water_volumes:
		if volume != null and is_instance_valid(volume):
			valid.append(volume)
	active_water_volumes = valid


func _configuration_failure(reason: String) -> Dictionary:
	active_mode = ""
	initial_mode = ""
	active_medium_tags.clear()
	medium_available = false
	return {
		"ok": false,
		"failures": [reason],
		"profile": profile.duplicate(true),
	}


func _reject_mode(mode_id: String, reason: String) -> Dictionary:
	rejection_count += 1
	mode_rejected.emit(mode_id, reason)
	return {
		"ok": false,
		"requested_mode": mode_id,
		"active_mode": active_mode,
		"error": reason,
	}


func _arrays_intersect(left: Array[String], right: Array[String]) -> bool:
	for value: String in left:
		if right.has(value):
			return true
	return false


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var normalized: String = str(raw).to_lower().strip_edges()
			if normalized != "" and not result.has(normalized):
				result.append(normalized)
	return result
