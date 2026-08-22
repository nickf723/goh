extends Node3D
class_name DeathSyphon

const SpellPresentation = preload("res://scripts/presentation/spell_presentation_bridge.gd")

@export_group("Targeting")
@export_range(2.0, 40.0, 0.5) var range_meters: float = 16.0
@export_flags_3d_physics var collision_mask: int = 1
@export_range(0.0, 3.0, 0.05) var cast_height: float = 1.15

@export_group("Drain")
@export_range(0.0, 3.0, 0.05) var heal_ratio: float = 1.0
@export_range(0, 100, 1) var maximum_heal: int = 12

@export_group("Presentation")
@export_range(0.05, 2.0, 0.05) var tether_duration: float = 0.34
@export_range(0.01, 0.4, 0.01) var tether_width: float = 0.07

var source_actor: Node3D = null
var runtime_payload: DamagePayload = null
var last_target_name: String = "none"
var last_health_before: int = -1
var last_health_after: int = -1
var last_actual_health_loss: int = 0
var last_requested_heal: int = 0
var last_actual_heal: int = 0
var last_result: Dictionary = {}


func _ready() -> void:
	add_to_group("spell_actions")
	add_to_group("debuggable")


func set_payload(new_payload: Resource) -> void:
	if new_payload is DamagePayload:
		runtime_payload = (new_payload as DamagePayload).duplicate(true) as DamagePayload


func set_source_actor(new_source_actor: Node) -> void:
	if new_source_actor is Node3D:
		source_actor = new_source_actor as Node3D


func execute(caster: Node3D, cast_direction: Vector3) -> void:
	if caster != null:
		source_actor = caster
	if source_actor == null or get_world_3d() == null:
		_finish_without_target("no_caster")
		return

	var direction: Vector3 = cast_direction.normalized()
	if direction.length_squared() <= 0.0001:
		direction = -source_actor.global_transform.basis.z.normalized()
	var origin: Vector3 = source_actor.global_position + Vector3.UP * cast_height
	var target_info: Dictionary = _acquire_target(origin, direction)
	var target: Node = target_info.get("target") as Node
	if target == null:
		_present_phase("miss", null, origin + direction * range_meters, "no_target", 0.35)
		queue_free()
		return

	last_target_name = target.name
	var impact_position: Vector3 = target_info.get("position", origin + direction * range_meters) as Vector3
	last_health_before = _read_target_health(target)
	last_result = _deliver_payload(target, _get_payload())
	last_health_after = _read_target_health(target)

	if last_health_before >= 0 and last_health_after >= 0:
		last_actual_health_loss = maxi(last_health_before - last_health_after, 0)
	else:
		last_actual_health_loss = maxi(int(last_result.get("damage_dealt", 0)), 0)

	last_requested_heal = roundi(float(last_actual_health_loss) * maxf(heal_ratio, 0.0))
	if maximum_heal > 0:
		last_requested_heal = mini(last_requested_heal, maximum_heal)
	last_actual_heal = _heal_source(last_requested_heal)

	_spawn_tether(origin, impact_position, last_actual_health_loss > 0)
	_present_phase(
		"resolve",
		target,
		impact_position,
		"drained:" + str(last_actual_health_loss) + ";healed:" + str(last_actual_heal),
		0.9 if last_actual_health_loss > 0 else 0.4
	)
	var timer := get_tree().create_timer(maxf(tether_duration, 0.05))
	timer.timeout.connect(queue_free)


func _acquire_target(origin: Vector3, direction: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.new()
	query.from = origin
	query.to = origin + direction * maxf(range_meters, 0.1)
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true
	if source_actor is CollisionObject3D:
		query.exclude = [(source_actor as CollisionObject3D).get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var collider_value: Variant = hit.get("collider")
	if not collider_value is Node:
		return {}
	var target: Node = _find_payload_target(collider_value as Node)
	if target == null:
		return {}
	return {
		"target": target,
		"position": hit.get("position", origin + direction * range_meters),
	}


func _find_payload_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if current == source_actor:
			return null
		if current.get_node_or_null("PayloadReceiver") != null:
			return current
		if current.get_node_or_null("HitReceiver") != null:
			return current
		if current.has_method("receive_damage_payload"):
			return current
		current = current.get_parent()
	return null


func _read_target_health(target: Node) -> int:
	if target == null:
		return -1
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver == null and target.name == "HitReceiver":
		hit_receiver = target
	if hit_receiver == null:
		return -1
	var health_value: Variant = hit_receiver.get("current_health")
	if health_value is int:
		return health_value as int
	if health_value is float:
		return roundi(health_value as float)
	return -1


func _deliver_payload(target: Node, damage_payload: DamagePayload) -> Dictionary:
	if target == null or damage_payload == null:
		return {}
	var receiver: Node = target.get_node_or_null("PayloadReceiver")
	if receiver != null and receiver.has_method("receive_payload"):
		return _normalize_result(receiver.call("receive_payload", damage_payload))
	if target.has_method("receive_damage_payload"):
		return _normalize_result(target.call("receive_damage_payload", damage_payload))
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver != null and hit_receiver.has_method("receive_payload"):
		return _normalize_result(hit_receiver.call("receive_payload", damage_payload))
	return {}


func _normalize_result(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _get_payload() -> DamagePayload:
	if runtime_payload != null:
		return runtime_payload
	var fallback := DamagePayload.new()
	fallback.amount = 4
	fallback.stance_damage = 0
	fallback.element = "death"
	fallback.source_name = "Syphon"
	fallback.hit_type = "life_drain"
	fallback.tags = ["death", "magic", "life_drain", "syphon"]
	return fallback


func _heal_source(amount: int) -> int:
	if amount <= 0:
		return 0
	var before: int = GameState.get_stat("health")
	GameState.heal(amount)
	return maxi(GameState.get_stat("health") - before, 0)


func _spawn_tether(start_position: Vector3, end_position: Vector3, successful: bool) -> void:
	var length: float = start_position.distance_to(end_position)
	if length <= 0.01:
		return
	var beam := MeshInstance3D.new()
	beam.name = "SyphonTether"
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := BoxMesh.new()
	mesh.size = Vector3(tether_width, tether_width, length)
	beam.mesh = mesh
	var material := StandardMaterial3D.new()
	var color := Color(0.86, 0.04, 0.15, 0.84) if successful else Color(0.42, 0.07, 0.13, 0.48)
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = 2.5 if successful else 0.8
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.material_override = material
	add_child(beam)
	beam.global_position = (start_position + end_position) * 0.5
	beam.look_at(end_position, Vector3.UP)
	var tween := beam.create_tween()
	tween.tween_property(beam, "scale", Vector3(0.25, 0.25, 1.0), maxf(tether_duration, 0.05))


func _present_phase(
	phase: String,
	target: Node,
	position: Vector3,
	detail: String,
	intensity: float
) -> void:
	SpellPresentation.present(self, phase, {
		"actor": source_actor,
		"target": target,
		"position": position,
		"spell_id": "syphon",
		"spell_name": "Syphon",
		"element": "death",
		"delivery_type": "targeted_life_drain",
		"targeting_style": "aimed",
		"detail": detail,
		"intensity": intensity,
	})


func _finish_without_target(detail: String) -> void:
	_present_phase("miss", null, global_position, detail, 0.2)
	queue_free()


func get_debug_data() -> Dictionary:
	return {
		"spell": "syphon",
		"life_drain_contract": true,
		"heals_from_actual_loss": true,
		"target": last_target_name,
		"health_before": last_health_before,
		"health_after": last_health_after,
		"actual_health_loss": last_actual_health_loss,
		"requested_heal": last_requested_heal,
		"actual_heal": last_actual_heal,
		"direct_damage": true,
	}
