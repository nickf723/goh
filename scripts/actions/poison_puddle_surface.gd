extends StatusSurface
class_name PoisonPuddleSurface

signal poison_puddle_deployed(position: Vector3)

@export_group("Puddle Placement")
@export_range(0.5, 10.0, 0.1) var placement_distance: float = 4.0
@export_range(0.5, 8.0, 0.1) var ground_probe_height: float = 3.0
@export_range(0.5, 10.0, 0.1) var ground_probe_depth: float = 5.0
@export_range(0.5, 8.0, 0.1) var puddle_radius: float = 3.4
@export_range(0.02, 0.5, 0.01) var puddle_depth: float = 0.12
@export_flags_3d_physics var placement_mask: int = 1

@export_group("Poison Surface")
@export_range(0.2, 8.0, 0.1) var poison_duration: float = 2.2
@export_range(0.1, 4.0, 0.1) var poison_strength: float = 1.0
@export_range(1.0, 60.0, 0.5) var puddle_lifetime: float = 14.0

@export_group("Presentation")
@export var puddle_color: Color = Color(0.54, 0.92, 0.08, 0.62)
@export var inner_color: Color = Color(0.78, 1.0, 0.18, 0.26)
@export_range(0.0, 2.0, 0.05) var surface_emission: float = 0.48

var source_actor: Node3D = null
var collision_shape: CollisionShape3D = null
var puddle_visual: MeshInstance3D = null
var puddle_material: StandardMaterial3D = null
var deployed: bool = false


func _ready() -> void:
	surface_name = "Poison Puddle"
	status_effect = "poisoned"
	status_duration = poison_duration
	status_strength = poison_strength
	status_source = "Poison Puddle"
	refresh_interval = 0.18
	lifetime = puddle_lifetime
	reactive_enabled = true
	visual_profile = "none"
	hazard_tags = ["poison", "chemical", "liquid", "puddle", "surface"]
	show_feedback = false
	_build_puddle_geometry()
	add_to_group("poison_puddles")
	add_to_group("chemical_surfaces")
	add_to_group("hazard_reactive")
	super._ready()


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
	deployed = true
	poison_puddle_deployed.emit(global_position)
	call_deferred("register_current_overlaps")


func _process(delta: float) -> void:
	super._process(delta)
	if puddle_visual == null or not deployed:
		return
	var phase: float = Time.get_ticks_msec() * 0.001
	var pulse: float = 1.0 + sin(phase * 1.9) * 0.025
	puddle_visual.scale = Vector3(pulse, 1.0, pulse)
	if puddle_material != null:
		puddle_material.emission_energy_multiplier = surface_emission * (
			0.82 + 0.18 * (sin(phase * 3.7) * 0.5 + 0.5)
		)


func _build_puddle_geometry() -> void:
	collision_shape = CollisionShape3D.new()
	collision_shape.name = "PuddleCollision"
	var shape := CylinderShape3D.new()
	shape.radius = puddle_radius
	shape.height = maxf(puddle_depth, 0.04)
	collision_shape.shape = shape
	collision_shape.position.y = shape.height * 0.5
	add_child(collision_shape)

	puddle_visual = MeshInstance3D.new()
	puddle_visual.name = "PoisonPuddleVisual"
	puddle_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := CylinderMesh.new()
	mesh.top_radius = puddle_radius
	mesh.bottom_radius = puddle_radius * 0.98
	mesh.height = maxf(puddle_depth * 0.45, 0.025)
	mesh.radial_segments = 48
	puddle_visual.mesh = mesh
	puddle_visual.position.y = mesh.height * 0.5
	puddle_material = StandardMaterial3D.new()
	puddle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puddle_material.albedo_color = puddle_color
	puddle_material.roughness = 0.16
	puddle_material.metallic = 0.0
	puddle_material.emission_enabled = true
	puddle_material.emission = Color(inner_color.r, inner_color.g, inner_color.b)
	puddle_material.emission_energy_multiplier = surface_emission
	puddle_visual.material_override = puddle_material
	add_child(puddle_visual)

	var core := MeshInstance3D.new()
	core.name = "PoisonPuddleCore"
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = puddle_radius * 0.48
	core_mesh.bottom_radius = puddle_radius * 0.58
	core_mesh.height = 0.018
	core_mesh.radial_segments = 32
	core.mesh = core_mesh
	core.position.y = mesh.height + 0.012
	var core_material := StandardMaterial3D.new()
	core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_material.albedo_color = inner_color
	core_material.emission_enabled = true
	core_material.emission = Color(inner_color.r, inner_color.g, inner_color.b)
	core_material.emission_energy_multiplier = surface_emission * 0.72
	core.material_override = core_material
	add_child(core)


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
		return (position_value as Vector3) + Vector3.UP * 0.015
	return world_position


func receive_poison_puddle_modifier(
	modifier_id: String,
	strength: float = 1.0
) -> void:
	var normalized: String = modifier_id.strip_edges().to_lower()
	match normalized:
		"dilute", "water":
			status_strength = maxf(status_strength * lerpf(1.0, 0.55, clampf(strength, 0.0, 1.0)), 0.1)
		"concentrate", "poison":
			status_strength = minf(status_strength + 0.35 * strength, 3.0)
		"freeze", "ice":
			set_reaction_state("frozen", maxf(frozen_state_duration * strength, 0.6))
		"ignite", "fire":
			set_reaction_state("burning", maxf(burning_state_duration * strength, 0.6))
		_:
			pass


func get_debug_data() -> Dictionary:
	return {
		"spell": "poison_puddle",
		"deployed": deployed,
		"radius": puddle_radius,
		"status": status_effect,
		"status_strength": status_strength,
		"reaction_state": reaction_state,
		"chemical_surface_contract": true,
		"reactive_status_surface": true,
		"direct_damage": false,
	}
