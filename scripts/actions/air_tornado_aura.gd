extends AirflowField3D
class_name AirTornadoAura

signal tornado_started(duration: float)
signal tornado_finished()

const AirflowManagerScript = preload(
	"res://scripts/airflow/airflow_manager.gd"
)

@export_group("Tornado Lifetime")
@export_range(0.5, 30.0, 0.25) var duration_seconds: float = 8.0
@export_range(0.0, 4.0, 0.05) var center_height: float = 2.2
@export_range(0.1, 2.0, 0.05) var calm_eye_radius: float = 0.72
@export_range(0.05, 2.0, 0.05) var calm_eye_fade: float = 0.58

@export_group("Fallback Physics")
@export_flags_3d_physics var collision_mask: int = 1
@export_range(0.0, 60.0, 0.5) var rigid_force_scale: float = 10.0
@export_range(0.0, 30.0, 0.5) var character_acceleration: float = 8.5
@export_range(0.0, 1.0, 0.05) var boss_multiplier: float = 0.22

@export_group("Presentation")
@export_range(4, 16, 1) var wisp_count: int = 10
@export var wind_color: Color = Color(1.0, 0.52, 0.82, 0.44)
@export var core_color: Color = Color(0.82, 0.92, 1.0, 0.16)

var source_actor: Node3D = null
var tornado_running: bool = false
var duration_remaining: float = 0.0
var visual_root: Node3D = null
var wind_wisps: Array[MeshInstance3D] = []
var fallback_steps: int = 0


func _init() -> void:
	field_id = "tornado_aura"
	active = false
	field_kind = FieldKind.VORTEX
	volume_shape = VolumeShape.CYLINDER
	local_axis = Vector3.UP
	radius = 4.5
	cylinder_height = 7.5
	strength = 14.0
	vortex_inward_fraction = 0.32
	vortex_vertical_fraction = 0.22
	edge_fade_fraction = 0.24
	falloff_exponent = 1.05
	turbulence_strength = 1.05
	turbulence_spatial_frequency = 0.78
	turbulence_time_frequency = 1.75


func _ready() -> void:
	active = false
	add_to_group("tornado_effects")
	add_to_group("spell_fields")
	_build_visuals()
	super._ready()
	set_process(false)
	set_physics_process(false)


func set_source_actor(actor: Node) -> void:
	if actor is Node3D and is_instance_valid(actor):
		source_actor = actor as Node3D


func execute(player: Node3D, _cast_direction: Vector3) -> void:
	if source_actor == null:
		source_actor = player
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return
	_ensure_airflow_manager()
	elapsed = 0.0
	duration_remaining = maxf(duration_seconds, 0.5)
	fallback_steps = 0
	tornado_running = true
	active = true
	_sync_to_source()
	if visual_root != null:
		visual_root.visible = true
	set_process(true)
	set_physics_process(true)
	tornado_started.emit(duration_remaining)


func _process(delta: float) -> void:
	if not tornado_running:
		return
	var step: float = maxf(delta, 0.0)
	super._process(step)
	if source_actor == null or not is_instance_valid(source_actor):
		finish_tornado()
		return
	_sync_to_source()
	duration_remaining = maxf(duration_remaining - step, 0.0)
	_update_visuals()
	if duration_remaining <= 0.0:
		finish_tornado()


func _physics_process(delta: float) -> void:
	if tornado_running and active:
		_apply_fallback_physics(maxf(delta, 0.0))


# The shared AirflowManager samples this override exactly as it does every other
# environmental airflow field. A calm eye prevents Grace from being accelerated
# by the self-centered spell while still allowing the outer vortex to influence
# enemies, projectiles, vegetation, clouds, mechanisms, and other listeners.
func sample_air_velocity(
	world_position: Vector3,
	sample_time: float = -1.0
) -> Vector3:
	var base_velocity: Vector3 = super.sample_air_velocity(
		world_position,
		sample_time
	)
	if base_velocity.length_squared() <= 0.000001:
		return Vector3.ZERO
	var planar_offset: Vector3 = world_position - global_position
	planar_offset.y = 0.0
	var distance: float = planar_offset.length()
	var fade_end: float = calm_eye_radius + maxf(calm_eye_fade, 0.01)
	var eye_weight: float = smoothstep(calm_eye_radius, fade_end, distance)
	return base_velocity * eye_weight


func finish_tornado() -> void:
	if not tornado_running:
		return
	tornado_running = false
	active = false
	set_process(false)
	set_physics_process(false)
	if visual_root != null:
		visual_root.visible = false
	tornado_finished.emit()
	queue_free()


func _sync_to_source() -> void:
	if source_actor == null or not is_instance_valid(source_actor):
		return
	global_position = source_actor.global_position + Vector3.UP * center_height


func _ensure_airflow_manager() -> Node:
	var manager: Node = get_tree().get_first_node_in_group("airflow_manager")
	var scene_root: Node = get_tree().current_scene
	if manager == null and scene_root != null:
		manager = scene_root.get_node_or_null("AirflowManager")
	if manager == null:
		manager = AirflowManagerScript.new()
		manager.name = "AirflowManager"
		if scene_root != null:
			scene_root.add_child(manager)
		elif get_parent() != null:
			get_parent().add_child(manager)
	airflow_manager = manager
	if manager != null and manager.has_method("register_field"):
		manager.call("register_field", self)
	return manager


# Actors already using AirflowResponse consume the shared manager normally. This
# fallback only makes generic rigid bodies and simple CharacterBody3D prototypes
# participate before they receive a dedicated AirflowResponse component.
func _apply_fallback_physics(delta: float) -> void:
	if delta <= 0.0:
		return
	var world: World3D = get_world_3d()
	if world == null:
		return
	var shape := CylinderShape3D.new()
	shape.radius = maxf(radius, 0.1)
	shape.height = maxf(cylinder_height, 0.2)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(global_transform.basis, global_position)
	query.collision_mask = collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if source_actor is CollisionObject3D:
		query.exclude = [(source_actor as CollisionObject3D).get_rid()]

	var seen: Dictionary = {}
	for result: Dictionary in world.direct_space_state.intersect_shape(query, 96):
		var collider_value: Variant = result.get("collider")
		if not collider_value is Node:
			continue
		var target: Node = _resolve_force_target(collider_value as Node)
		if target == null or target == source_actor:
			continue
		var id: int = target.get_instance_id()
		if seen.has(id):
			continue
		seen[id] = true
		if target.get_node_or_null("AirflowResponse") != null:
			continue
		var velocity: Vector3 = sample_air_velocity(
			_target_position(target),
			elapsed
		)
		if velocity.length_squared() <= 0.0001:
			continue
		var multiplier: float = boss_multiplier if target.is_in_group("boss") else 1.0
		if target is RigidBody3D:
			(target as RigidBody3D).apply_central_force(
				velocity * rigid_force_scale * multiplier
			)
		elif target is CharacterBody3D:
			var character := target as CharacterBody3D
			character.velocity += velocity.normalized() * character_acceleration * multiplier * delta
		fallback_steps += 1


func _resolve_force_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if current is RigidBody3D or current is CharacterBody3D:
			return current
		if current == get_tree().current_scene:
			break
		current = current.get_parent()
	return null


func _target_position(target: Node) -> Vector3:
	return (target as Node3D).global_position if target is Node3D else global_position


func _build_visuals() -> void:
	visual_root = Node3D.new()
	visual_root.name = "TornadoVisual"
	visual_root.visible = false
	add_child(visual_root)

	var core := MeshInstance3D.new()
	core.name = "TornadoCore"
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = radius * 0.28
	core_mesh.bottom_radius = radius * 0.62
	core_mesh.height = cylinder_height * 0.78
	core_mesh.radial_segments = 32
	core.mesh = core_mesh
	var core_material := StandardMaterial3D.new()
	core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_material.albedo_color = core_color
	core_material.emission_enabled = true
	core_material.emission = Color(core_color.r, core_color.g, core_color.b)
	core_material.emission_energy_multiplier = 0.35
	core.material_override = core_material
	visual_root.add_child(core)

	wind_wisps.clear()
	for index: int in range(maxi(wisp_count, 1)):
		var wisp := MeshInstance3D.new()
		wisp.name = "TornadoWisp%02d" % index
		wisp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mesh := SphereMesh.new()
		mesh.radius = 0.10
		mesh.height = 0.20
		mesh.radial_segments = 8
		mesh.rings = 4
		wisp.mesh = mesh
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = wind_color
		material.emission_enabled = true
		material.emission = Color(wind_color.r, wind_color.g, wind_color.b)
		material.emission_energy_multiplier = 0.62
		wisp.material_override = material
		visual_root.add_child(wisp)
		wind_wisps.append(wisp)


func _update_visuals() -> void:
	if visual_root == null:
		return
	visual_root.rotation.y = elapsed * 0.85
	var count: int = wind_wisps.size()
	for index: int in range(count):
		var wisp: MeshInstance3D = wind_wisps[index]
		if wisp == null:
			continue
		var phase: float = float(index) / maxf(float(count), 1.0)
		var angle: float = elapsed * (2.2 + phase * 0.65) + phase * TAU * 2.3
		var height_fraction: float = fposmod(phase + elapsed * 0.12, 1.0)
		var local_radius: float = lerpf(radius * 0.42, radius * 0.88, 1.0 - height_fraction * 0.62)
		wisp.position = Vector3(
			cos(angle) * local_radius,
			lerpf(-cylinder_height * 0.42, cylinder_height * 0.42, height_fraction),
			sin(angle) * local_radius
		)
		wisp.scale = Vector3(
			1.0 + height_fraction * 1.2,
			0.7,
			1.0 + height_fraction * 1.2
		)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["spell"] = "tornado"
	data["running"] = tornado_running
	data["duration_remaining"] = snappedf(duration_remaining, 0.01)
	data["calm_eye_radius"] = calm_eye_radius
	data["fallback_steps"] = fallback_steps
	data["airflow_vortex"] = true
	data["shared_airflow_contract"] = true
	data["direct_damage"] = false
	return data
