extends "res://scripts/divine_specials/divine_special_effect.gd"
class_name RuviaWildfireProcession

@export_range(2, 16, 1) var eruption_count: int = 8
@export_range(0.5, 4.0, 0.05) var eruption_spacing: float = 1.55
@export_range(0.04, 0.8, 0.01) var eruption_interval: float = 0.13
@export_range(0.5, 6.0, 0.1) var eruption_radius: float = 2.15
@export_range(0.5, 8.0, 0.1) var field_radius: float = 1.65
@export_range(0.5, 10.0, 0.1) var field_lifetime: float = 3.4

var path_origin: Vector3 = Vector3.ZERO
var eruptions_spawned: int = 0
var fields_spawned: int = 0


func begin_special() -> bool:
	if not super.begin_special():
		return false
	path_origin = project_point_to_floor(owner_actor.global_position)
	global_position = path_origin
	if performer_actor == null or performer_actor != owner_actor:
		var projection_position: Vector3 = (
			path_origin
			- cast_direction * 0.75
			+ Vector3.UP * 0.96
		)
		spawn_patron_projection(
			projection_position,
			atan2(-cast_direction.x, -cast_direction.z),
			1.04
		)
	spawn_pulse_disc(
		path_origin + Vector3.UP * 0.045,
		0.25,
		1.6,
		0.28,
		Color(1.0, 0.36, 0.035, 0.62),
		0.08
	)
	_run_procession()
	return true


func _run_procession() -> void:
	for eruption_index: int in range(maxi(eruption_count, 1)):
		if finished or not is_inside_tree():
			return
		var distance: float = 1.8 + float(eruption_index) * eruption_spacing
		var raw_point: Vector3 = path_origin + cast_direction * distance
		var eruption_point: Vector3 = project_point_to_floor(raw_point)
		_spawn_eruption(eruption_point, eruption_index)
		if eruption_index < eruption_count - 1:
			await get_tree().create_timer(eruption_interval).timeout
	await get_tree().create_timer(0.45).timeout
	if finished or not is_inside_tree():
		return
	_finish_special(
		true,
		"wildfire_procession_completed",
		{
			"eruptions_spawned": eruptions_spawned,
			"fields_spawned": fields_spawned,
			"path_length": snappedf(
				1.8 + float(maxi(eruption_count - 1, 0)) * eruption_spacing,
				0.1
			),
		}
	)


func _spawn_eruption(point: Vector3, eruption_index: int) -> void:
	eruptions_spawned += 1
	var sequence_weight: float = (
		float(eruption_index)
		/ float(maxi(eruption_count - 1, 1))
	)
	var pulse_color: Color = Color(
		1.0,
		lerpf(0.32, 0.68, sequence_weight),
		0.035,
		0.72
	)
	spawn_flash_sphere(
		point + Vector3.UP * 0.38,
		0.18,
		eruption_radius * 0.72,
		0.24,
		pulse_color
	)
	spawn_pulse_disc(
		point + Vector3.UP * 0.05,
		0.2,
		eruption_radius,
		0.32,
		pulse_color,
		0.09
	)

	var payload: DamagePayload = DamagePayload.new()
	payload.amount = 9 + roundi(sequence_weight * 3.0)
	payload.stance_damage = 13 + roundi(sequence_weight * 5.0)
	payload.element = "fire"
	payload.source_name = "Wildfire Procession"
	payload.hit_type = "divine_special"
	payload.status_effect = "burning"
	payload.status_duration = 3.2
	payload.status_strength = 1.7 + sequence_weight * 0.5
	payload.tags = [
		"fire",
		"divine_special",
		"wildfire_procession",
		"traveling_burst",
		"area_control",
	]
	for target: Node in get_targets_in_radius(point, eruption_radius, 20):
		apply_payload_to_target(
			target,
			payload,
			point - cast_direction * 0.45,
			4.8 + sequence_weight * 1.2,
			2.0 + sequence_weight * 0.7
		)

	var field_payload: DamagePayload = DamagePayload.new()
	field_payload.amount = 1
	field_payload.stance_damage = 1
	field_payload.element = "fire"
	field_payload.source_name = "Procession Flame"
	field_payload.hit_type = "hazard"
	field_payload.status_effect = "burning"
	field_payload.status_duration = 1.35
	field_payload.status_strength = 1.15
	field_payload.tags = [
		"fire",
		"hazard",
		"divine_special",
		"wildfire_procession_field",
	]
	if spawn_ally_safe_fire_field(
		point + Vector3.UP * 0.055,
		field_radius,
		field_lifetime,
		field_payload,
		"wildfire_procession"
	) != null:
		fields_spawned += 1
	clear_hostile_projectiles(point, eruption_radius * 0.75)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["path_origin"] = path_origin
	data["eruption_count"] = eruption_count
	data["eruptions_spawned"] = eruptions_spawned
	data["fields_spawned"] = fields_spawned
	data["eruption_spacing"] = eruption_spacing
	return data
