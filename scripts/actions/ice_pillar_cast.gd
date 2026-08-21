extends StaticBody3D
class_name IcePillarCast

signal pillar_raised(position: Vector3, height: float)
signal pillar_melting()
signal pillar_expired()

@export_group("Placement")
@export_range(1.0, 10.0, 0.1) var placement_distance: float = 3.4
@export_range(0.5, 8.0, 0.1) var ground_probe_height: float = 3.0
@export_range(0.5, 10.0, 0.1) var ground_probe_depth: float = 5.0
@export_flags_3d_physics var placement_mask: int = 1

@export_group("Pillar")
@export var pillar_size: Vector3 = Vector3(1.35, 3.6, 1.35)
@export_range(1.0, 60.0, 0.5) var lifetime: float = 16.0
@export_range(0.05, 1.0, 0.01) var raise_seconds: float = 0.28
@export_range(0.05, 2.0, 0.01) var melt_seconds: float = 0.55
@export var collision_layer_bits: int = 1
@export var collision_mask_bits: int = 0

@export_group("Presentation")
@export var ice_color: Color = Color(0.42, 0.86, 1.0, 0.76)
@export var ice_emission: Color = Color(0.18, 0.64, 1.0, 1.0)
@export_range(0.0, 4.0, 0.1) var emission_energy: float = 0.7

var source_actor: Node3D = null
var elapsed: float = 0.0
var deployed: bool = false
var expiring: bool = false
var melting: bool = false
var pillar_mesh: MeshInstance3D = null
var collision_shape: CollisionShape3D = null
var base_scale: Vector3 = Vector3.ONE


func _ready() -> void:
	add_to_group("ice_pillars")
	add_to_group("temporary_architecture")
	add_to_group("traversal_geometry")
	add_to_group("presentation_material_ice")
	add_to_group("debuggable")
	collision_layer = collision_layer_bits
	collision_mask = collision_mask_bits
	_build_pillar()
	set_process(false)


func set_payload(_new_payload: Resource) -> void:
	# Ice Pillar is geometry, not a direct damage spell.
	pass


func set_source_actor(actor: Node) -> void:
	if actor is Node3D and is_instance_valid(actor):
		source_actor = actor as Node3D


func execute(player: Node3D, cast_direction: Vector3) -> void:
	if source_actor == null:
		source_actor = player
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return

	var direction: Vector3 = cast_direction
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = -source_actor.global_basis.z
		direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	direction = direction.normalized()

	var desired: Vector3 = source_actor.global_position + direction * placement_distance
	global_position = _resolve_ground_point(desired)
	elapsed = 0.0
	deployed = true
	expiring = false
	melting = false
	set_process(true)
	_raise_pillar()
	pillar_raised.emit(global_position, pillar_size.y)


func _process(delta: float) -> void:
	if not deployed or expiring:
		return
	elapsed += maxf(delta, 0.0)
	if elapsed >= lifetime:
		_begin_expire(false)


func _build_pillar() -> void:
	collision_shape = CollisionShape3D.new()
	collision_shape.name = "PillarCollision"
	var shape := BoxShape3D.new()
	shape.size = pillar_size
	collision_shape.shape = shape
	collision_shape.position.y = pillar_size.y * 0.5
	add_child(collision_shape)

	pillar_mesh = MeshInstance3D.new()
	pillar_mesh.name = "IcePillarMesh"
	pillar_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var mesh := BoxMesh.new()
	mesh.size = pillar_size
	pillar_mesh.mesh = mesh
	pillar_mesh.position.y = pillar_size.y * 0.5
	pillar_mesh.material_override = _make_ice_material()
	add_child(pillar_mesh)

	for index: int in range(5):
		var shard := MeshInstance3D.new()
		shard.name = "IceCrownShard" + str(index + 1)
		var shard_mesh := PrismMesh.new()
		shard_mesh.size = Vector3(0.22, 0.75 + float(index % 2) * 0.18, 0.34)
		shard.mesh = shard_mesh
		shard.position = Vector3(
			lerpf(-pillar_size.x * 0.34, pillar_size.x * 0.34, float(index) / 4.0),
			pillar_size.y + shard_mesh.size.y * 0.34,
			(float(index % 2) - 0.5) * 0.16
		)
		shard.rotation_degrees = Vector3(0.0, float(index) * 31.0, -8.0 + float(index) * 4.0)
		shard.material_override = _make_ice_material()
		add_child(shard)

	base_scale = scale


func _make_ice_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = ice_color
	material.emission_enabled = true
	material.emission = ice_emission
	material.emission_energy_multiplier = emission_energy
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.14
	material.metallic = 0.02
	return material


func _raise_pillar() -> void:
	var target_scale: Vector3 = base_scale
	scale = Vector3(target_scale.x, 0.025, target_scale.z)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", target_scale, raise_seconds)


func _begin_expire(from_fire: bool) -> void:
	if expiring:
		return
	expiring = true
	melting = from_fire
	if collision_shape != null:
		collision_shape.disabled = true
	if from_fire:
		pillar_melting.emit()
	var target := Vector3(scale.x * 0.8, 0.02, scale.z * 0.8)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", target, melt_seconds if from_fire else 0.32)
	tween.finished.connect(_finish_expire)


func _finish_expire() -> void:
	pillar_expired.emit()
	queue_free()


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if payload == null:
		return {
			"message": "The Ice Pillar receives an empty payload.",
			"objective": "",
		}
	var element: String = payload.element.strip_edges().to_lower()
	if element == "fire":
		_begin_expire(true)
		return {
			"message": payload.source_name + " melts the Ice Pillar.",
			"objective": "",
			"handled": true,
			"reaction": "melt",
		}
	return {
		"message": payload.source_name + " strikes the Ice Pillar.",
		"objective": "",
		"handled": true,
	}


func receive_earthquake_pulse(
	_epicenter: Vector3,
	strength: float,
	_index: int,
	_source: Node3D
) -> void:
	if pillar_mesh == null or expiring or strength <= 0.0:
		return
	var tween := pillar_mesh.create_tween()
	var base_rotation: Vector3 = pillar_mesh.rotation
	tween.tween_property(
		pillar_mesh,
		"rotation:z",
		base_rotation.z + deg_to_rad(2.0 * strength),
		0.045
	)
	tween.tween_property(pillar_mesh, "rotation:z", base_rotation.z, 0.085)


func _resolve_ground_point(world_position: Vector3) -> Vector3:
	var world: World3D = get_world_3d()
	if world == null:
		return world_position
	var query := PhysicsRayQueryParameters3D.create(
		world_position + Vector3.UP * ground_probe_height,
		world_position + Vector3.DOWN * ground_probe_depth
	)
	query.collision_mask = placement_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if source_actor is CollisionObject3D:
		query.exclude = [(source_actor as CollisionObject3D).get_rid()]
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	var position_value: Variant = hit.get("position")
	if position_value is Vector3:
		return (position_value as Vector3) + Vector3.UP * 0.02
	return world_position


func get_presentation_material() -> String:
	return "ice"


func get_debug_data() -> Dictionary:
	return {
		"spell": "ice_pillar",
		"temporary_architecture_contract": true,
		"direct_damage": false,
		"physical_collision": collision_shape != null,
		"deployed": deployed,
		"expiring": expiring,
		"melting": melting,
		"elapsed": snappedf(elapsed, 0.01),
		"height": pillar_size.y,
		"fire_meltable": true,
		"traversal_geometry": true,
	}
