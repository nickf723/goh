extends "res://scripts/divine_specials/divine_special_effect.gd"
class_name RuviaCalderaDrop

@export_range(0.05, 2.0, 0.01) var descent_seconds: float = 0.42
@export_range(0.05, 2.0, 0.01) var aftermath_seconds: float = 0.52
@export_range(0.5, 12.0, 0.1) var projection_height: float = 4.8
@export_range(0.5, 8.0, 0.1) var inner_radius: float = 2.25
@export_range(1.0, 12.0, 0.1) var outer_radius: float = 5.2

var impact_completed: bool = false
var fire_field_spawned: bool = false


func begin_special() -> bool:
	if not super.begin_special():
		return false
	outer_radius = maxf(
		outer_radius,
		definition.area_radius if definition != null else outer_radius
	)
	target_position = project_point_to_floor(target_position)
	global_position = target_position
	_start_descent_sequence()
	return true


func _start_descent_sequence() -> void:
	var yaw: float = atan2(-cast_direction.x, -cast_direction.z)
	if performer_actor == null or performer_actor != owner_actor:
		var projection: Node3D = spawn_patron_projection(
			target_position + Vector3.UP * projection_height,
			yaw,
			1.12
		)
		if projection != null:
			var tween: Tween = projection.create_tween()
			tween.set_trans(Tween.TRANS_QUINT)
			tween.set_ease(Tween.EASE_IN)
			tween.tween_property(
				projection,
				"global_position",
				target_position + Vector3.UP * 0.96,
				descent_seconds
			)
	else:
		spawn_flash_sphere(
			owner_actor.global_position + Vector3.UP * 1.05,
			0.2,
			1.1,
			descent_seconds,
			Color(1.0, 0.3, 0.03, 0.46)
		)
	_run_sequence()


func _run_sequence() -> void:
	await get_tree().create_timer(descent_seconds).timeout
	if finished or not is_inside_tree():
		return
	_resolve_impact()
	await get_tree().create_timer(aftermath_seconds).timeout
	if finished or not is_inside_tree():
		return
	_finish_special(
		true,
		"caldera_drop_completed",
		{
			"impact_completed": impact_completed,
			"fire_field_spawned": fire_field_spawned,
		}
	)


func _resolve_impact() -> void:
	impact_completed = true
	spawn_flash_sphere(
		target_position + Vector3.UP * 0.45,
		0.35,
		outer_radius * 0.78,
		0.34,
		Color(1.0, 0.24, 0.025, 0.62)
	)
	spawn_pulse_disc(
		target_position + Vector3.UP * 0.05,
		0.35,
		outer_radius,
		0.42,
		Color(1.0, 0.5, 0.06, 0.66),
		0.12
	)
	spawn_pulse_disc(
		target_position + Vector3.UP * 0.08,
		inner_radius * 0.35,
		inner_radius * 1.25,
		0.26,
		Color(1.0, 0.82, 0.22, 0.82),
		0.16
	)

	for target: Node in get_targets_in_radius(target_position, outer_radius, 48):
		var target_world_position: Vector3 = get_target_world_position(target)
		var distance: float = target_world_position.distance_to(target_position)
		var power: float = 1.0
		if distance > inner_radius:
			power = 1.0 - clampf(
				(distance - inner_radius)
				/ maxf(outer_radius - inner_radius, 0.01),
				0.0,
				1.0
			) * 0.55
		var payload: DamagePayload = DamagePayload.new()
		payload.amount = maxi(roundi(24.0 * power), 10)
		payload.stance_damage = maxi(roundi(38.0 * power), 16)
		payload.element = "fire"
		payload.source_name = "Caldera Drop"
		payload.hit_type = "divine_special"
		payload.status_effect = "burning"
		payload.status_duration = 5.2 * power
		payload.status_strength = 2.6 * power
		payload.tags = [
			"fire",
			"divine_special",
			"caldera_drop",
			"burst",
			"guard_break",
			"heavy_impact",
		]
		apply_payload_to_target(
			target,
			payload,
			target_position,
			10.5 * power,
			5.2 * power
		)

	clear_hostile_projectiles(target_position, outer_radius + 1.0)
	var field_payload: DamagePayload = DamagePayload.new()
	field_payload.amount = 2
	field_payload.stance_damage = 2
	field_payload.element = "fire"
	field_payload.source_name = "Caldera Crater"
	field_payload.hit_type = "hazard"
	field_payload.status_effect = "burning"
	field_payload.status_duration = 1.8
	field_payload.status_strength = 1.5
	field_payload.tags = [
		"fire",
		"hazard",
		"divine_special",
		"caldera_crater",
	]
	fire_field_spawned = (
		spawn_ally_safe_fire_field(
			target_position + Vector3.UP * 0.055,
			3.65,
			6.5,
			field_payload,
			"caldera_crater"
		)
		!= null
	)
	HitStop.request(0.12, 0.035)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["impact_completed"] = impact_completed
	data["fire_field_spawned"] = fire_field_spawned
	data["inner_radius"] = inner_radius
	data["outer_radius"] = outer_radius
	return data
