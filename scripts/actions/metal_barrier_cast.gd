extends StaticBody3D
class_name MetalBarrierCast

signal barrier_deployed(position: Vector3)
signal barrier_expired()

@export_group("Placement")
@export_range(1.0, 10.0, 0.1) var placement_distance: float = 3.2
@export_range(0.5, 8.0, 0.1) var ground_probe_height: float = 3.0
@export_range(0.5, 10.0, 0.1) var ground_probe_depth: float = 5.0
@export_flags_3d_physics var placement_mask: int = 1

@export_group("Barrier")
@export var barrier_size: Vector3 = Vector3(3.8, 2.45, 0.34)
@export_range(1.0, 60.0, 0.5) var lifetime: float = 18.0
@export_range(0.05, 1.0, 0.01) var deploy_seconds: float = 0.22
@export_range(0.05, 1.0, 0.01) var retract_seconds: float = 0.24
@export var collision_layer_bits: int = 1
@export var collision_mask_bits: int = 0

@export_group("Presentation")
@export var metal_color: Color = Color(0.82, 0.76, 0.42, 1.0)
@export var edge_color: Color = Color(1.0, 0.86, 0.24, 1.0)

var source_actor: Node3D = null
var elapsed: float = 0.0
var deployed: bool = false
var expiring: bool = false
var barrier_mesh: MeshInstance3D = null
var collision_shape: CollisionShape3D = null
var base_scale: Vector3 = Vector3.ONE


func _ready() -> void:
	add_to_group("metal_barriers")
	add_to_group("polarizable")
	add_to_group("presentation_material_metal")
	add_to_group("debuggable")
	collision_layer = collision_layer_bits
	collision_mask = collision_mask_bits
	_build_barrier()
	set_process(false)


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
	look_at(global_position + direction, Vector3.UP)

	elapsed = 0.0
	deployed = true
	expiring = false
	set_process(true)
	_scale_in()
	barrier_deployed.emit(global_position)


func _process(delta: float) -> void:
	if not deployed or expiring:
		return
	elapsed += maxf(delta, 0.0)
	if elapsed >= lifetime:
		_begin_expire()


func _build_barrier() -> void:
	collision_shape = CollisionShape3D.new()
	collision_shape.name = "BarrierCollision"
	var shape := BoxShape3D.new()
	shape.size = barrier_size
	collision_shape.shape = shape
	collision_shape.position.y = barrier_size.y * 0.5
	add_child(collision_shape)

	barrier_mesh = MeshInstance3D.new()
	barrier_mesh.name = "BarrierPanel"
	barrier_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var panel := BoxMesh.new()
	panel.size = barrier_size
	barrier_mesh.mesh = panel
	barrier_mesh.position.y = barrier_size.y * 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = metal_color
	material.metallic = 0.86
	material.roughness = 0.34
	barrier_mesh.material_override = material
	add_child(barrier_mesh)

	for side: float in [-1.0, 1.0]:
		var brace := MeshInstance3D.new()
		brace.name = "BarrierBrace"
		var brace_mesh := CylinderMesh.new()
		brace_mesh.top_radius = 0.075
		brace_mesh.bottom_radius = 0.11
		brace_mesh.height = barrier_size.y * 0.93
		brace_mesh.radial_segments = 10
		brace.mesh = brace_mesh
		var brace_material := StandardMaterial3D.new()
		brace_material.albedo_color = edge_color
		brace_material.metallic = 0.92
		brace_material.roughness = 0.24
		brace.material_override = brace_material
		brace.position = Vector3(side * barrier_size.x * 0.43, barrier_size.y * 0.47, -barrier_size.z * 0.6)
		add_child(brace)

	base_scale = scale


func _scale_in() -> void:
	var target_scale: Vector3 = base_scale
	scale = Vector3(target_scale.x, 0.04, target_scale.z)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", target_scale, deploy_seconds)


func _begin_expire() -> void:
	if expiring:
		return
	expiring = true
	if collision_shape != null:
		collision_shape.disabled = true
	var target := Vector3(scale.x, 0.03, scale.z)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", target, retract_seconds)
	tween.finished.connect(_finish_expire)


func _finish_expire() -> void:
	barrier_expired.emit()
	queue_free()


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
	return "metal"


func can_accept_polarize(_source: Node3D = null) -> bool:
	return true


# Static barriers act as magnetic anchors. They deliberately ignore force while
# still satisfying Polarize's connection contract, letting movable props snap to
# a player-created structure without turning the wall itself into a projectile.
func receive_polarize_force(_force: Vector3, _partner: Node3D, _source: Node3D) -> void:
	pass


func receive_earthquake_pulse(
	_epicenter: Vector3,
	strength: float,
	_index: int,
	_source: Node3D
) -> void:
	if barrier_mesh == null or strength <= 0.0:
		return
	var tween := barrier_mesh.create_tween()
	var base_rotation: Vector3 = barrier_mesh.rotation
	tween.tween_property(
		barrier_mesh,
		"rotation:z",
		base_rotation.z + deg_to_rad(1.4 * strength),
		0.05
	)
	tween.tween_property(barrier_mesh, "rotation:z", base_rotation.z, 0.09)


func get_debug_data() -> Dictionary:
	return {
		"spell": "barrier",
		"deployed": deployed,
		"expiring": expiring,
		"elapsed": snappedf(elapsed, 0.01),
		"physical_collision": collision_shape != null,
		"polarize_anchor": true,
		"direct_damage": false,
		"defensive_structure": true,
	}
