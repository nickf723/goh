extends Node3D
class_name GroundContactPresentationDirector3D

signal contact_presented(event_type: String, surface: String, particle_count: int)

const PresentationServiceScript = preload(
	"res://scripts/presentation/presentation_service.gd"
)

@export var profile: GroundContactPresentationProfile
@export var enabled: bool = true

var presentation_director: GamePresentationDirector = null
var lighting_director: LightingDirector3D = null
var contact_multimesh_instance: MultiMeshInstance3D = null
var contact_multimesh: MultiMesh = null
var particle_states: Array[Dictionary] = []
var next_particle_index: int = 0
var active_quality: int = -1
var presented_count: int = 0
var particles_spawned: int = 0
var surface_counts: Dictionary = {}
var last_surface: String = "none"
var last_event_type: String = "none"


func _ready() -> void:
	add_to_group("ground_contact_presentation_director")
	add_to_group("debuggable")
	_resolve_dependencies()
	_build_pool()
	_connect_presentation()
	active_quality = _current_quality()
	set_meta("ground_contact_presentation_initialized", profile != null)


func _exit_tree() -> void:
	if (
		presentation_director != null
		and is_instance_valid(presentation_director)
		and presentation_director.event_presented.is_connected(_on_event_presented)
	):
		presentation_director.event_presented.disconnect(_on_event_presented)


func _process(delta: float) -> void:
	if profile == null:
		return
	if lighting_director == null or not is_instance_valid(lighting_director):
		_resolve_lighting_director()
	var requested_quality: int = _current_quality()
	if requested_quality != active_quality:
		active_quality = requested_quality
		if profile.get_density_scale(active_quality) <= 0.001:
			clear_particles()
	_update_particles(maxf(delta, 0.0))


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		clear_particles()


func _resolve_dependencies() -> void:
	_resolve_lighting_director()
	if get_tree() != null:
		presentation_director = PresentationServiceScript.get_or_create(
			get_tree()
		)


func _resolve_lighting_director() -> void:
	lighting_director = null
	if get_tree() == null:
		return
	var candidate: Node = get_tree().get_first_node_in_group("lighting_director")
	if candidate is LightingDirector3D:
		lighting_director = candidate as LightingDirector3D


func _connect_presentation() -> void:
	if presentation_director == null or not is_instance_valid(presentation_director):
		return
	if not presentation_director.event_presented.is_connected(_on_event_presented):
		presentation_director.event_presented.connect(_on_event_presented)


func _current_quality() -> int:
	if lighting_director == null:
		return 2
	return clampi(lighting_director.quality, 0, 2)


func _build_pool() -> void:
	if profile == null or contact_multimesh != null:
		return
	var count: int = maxi(profile.maximum_particles, 16)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 5
	mesh.rings = 3
	mesh.material = material

	contact_multimesh = MultiMesh.new()
	contact_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	contact_multimesh.use_colors = true
	contact_multimesh.mesh = mesh
	contact_multimesh.instance_count = count
	contact_multimesh.visible_instance_count = count

	contact_multimesh_instance = MultiMeshInstance3D.new()
	contact_multimesh_instance.name = "GroundContactParticlePool"
	contact_multimesh_instance.multimesh = contact_multimesh
	contact_multimesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(contact_multimesh_instance)

	particle_states.clear()
	for index: int in range(count):
		particle_states.append({"active": false})
		_hide_particle(index)


func _on_event_presented(event_type: String, data: Dictionary) -> void:
	if not enabled or profile == null:
		return
	var normalized: String = event_type.strip_edges().to_lower()
	if normalized not in ["footstep", "landing"]:
		return
	var density: float = profile.get_density_scale(_current_quality())
	if density <= 0.001:
		return
	var position_value: Variant = data.get("position", Vector3.ZERO)
	if not position_value is Vector3:
		return
	var position: Vector3 = position_value as Vector3
	var fallback_material: String = str(data.get("material", "stone")).to_lower()
	var actor_instance_id: int = int(data.get("actor_instance_id", 0))
	var surface: String = resolve_contact_surface(
		position,
		fallback_material,
		actor_instance_id
	)
	var strength: float = clampf(float(data.get("strength", 0.25)), 0.0, 1.0)
	var count: int = _particle_count(normalized, surface, density, strength)
	if count <= 0:
		return
	var event_seed: int = int(data.get("event_id", presented_count + 1))
	_spawn_burst(position, normalized, surface, strength, count, event_seed)
	presented_count += 1
	particles_spawned += count
	last_surface = surface
	last_event_type = normalized
	surface_counts[surface] = int(surface_counts.get(surface, 0)) + 1
	contact_presented.emit(normalized, surface, count)


func resolve_contact_surface(
	world_position: Vector3,
	fallback_material: String = "stone",
	actor_instance_id: int = 0
) -> String:
	var world: World3D = get_world_3d()
	if world == null:
		return _surface_from_material(fallback_material)
	var query := PhysicsRayQueryParameters3D.create(
		world_position + Vector3.UP * 0.24,
		world_position + Vector3.DOWN * 1.2
	)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if actor_instance_id > 0:
		var actor_value: Object = instance_from_id(actor_instance_id)
		if actor_value is CollisionObject3D:
			query.exclude = [(actor_value as CollisionObject3D).get_rid()]
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return _surface_from_material(fallback_material)
	var collider_value: Variant = hit.get("collider", null)
	if collider_value is Node:
		var surface: String = _surface_from_node(collider_value as Node)
		if surface != "":
			return surface
	return _surface_from_material(fallback_material)


func _surface_from_node(node: Node) -> String:
	var current: Node = node
	while current != null and is_instance_valid(current):
		if current.has_method("get_contact_surface"):
			var method_surface: String = str(
				current.call("get_contact_surface")
			).strip_edges().to_lower()
			if method_surface != "":
				return method_surface
		if current.has_meta("contact_surface"):
			var meta_surface: String = str(
				current.get_meta("contact_surface")
			).strip_edges().to_lower()
			if meta_surface != "":
				return meta_surface
		var lower_name: String = str(current.name).to_lower()
		if "wet" in lower_name or "waterfall" in lower_name or "river" in lower_name:
			return "wet_stone"
		if "moss" in lower_name or "soil" in lower_name or "earth" in lower_name:
			return "moss_soil"
		if "paving" in lower_name or "causeway" in lower_name or "shrine" in lower_name:
			return "paving"
		current = current.get_parent()
	return ""


func _surface_from_material(material_id: String) -> String:
	match material_id.strip_edges().to_lower():
		"wood":
			return "wood"
		"metal":
			return "metal"
		"soft", "flesh":
			return "soft"
		_:
			return "stone"


func _particle_count(
	event_type: String,
	surface: String,
	density: float,
	strength: float
) -> int:
	var family: String = _surface_family(surface)
	var authored: int = 0
	if event_type == "landing":
		match family:
			"soil":
				authored = profile.soil_landing_particles
			"wet":
				authored = profile.wet_landing_particles
			_:
				authored = profile.stone_landing_particles
		var impact_scale: float = lerpf(0.58, 1.0, strength)
		return maxi(int(round(float(authored) * density * impact_scale)), 0)
	match family:
		"soil":
		authored = profile.soil_footstep_particles
		"wet":
		authored = profile.wet_footstep_particles
		_:
		authored = profile.stone_footstep_particles
	return maxi(int(round(float(authored) * density)), 0)


func _surface_family(surface: String) -> String:
	var normalized: String = surface.strip_edges().to_lower()
	if "wet" in normalized or "water" in normalized:
		return "wet"
	if "soil" in normalized or "moss" in normalized or "leaf" in normalized:
		return "soil"
	return "stone"


func _surface_color(surface: String) -> Color:
	var normalized: String = surface.strip_edges().to_lower()
	if "wet" in normalized or "water" in normalized:
		return profile.wet_color
	if "moss" in normalized:
		return profile.moss_color
	if "soil" in normalized or "leaf" in normalized:
		return profile.soil_color
	if "paving" in normalized or "masonry" in normalized:
		return profile.paving_color
	return profile.stone_color


func _spawn_burst(
	world_position: Vector3,
	event_type: String,
	surface: String,
	strength: float,
	count: int,
	seed_base: int
) -> void:
	if contact_multimesh == null or particle_states.is_empty():
		return
	var family: String = _surface_family(surface)
	var base_color: Color = _surface_color(surface)
	var event_velocity_scale: float = (
		profile.landing_velocity_scale
		if event_type == "landing"
		else profile.footstep_velocity_scale
	)
	for particle_index: int in range(count):
		var slot: int = next_particle_index % particle_states.size()
		next_particle_index = (next_particle_index + 1) % particle_states.size()
		var seed: int = seed_base * 31 + particle_index * 17 + slot * 7
		var angle: float = _rand01(seed + 1) * TAU
		var horizontal_speed: float = lerpf(0.18, 0.72, _rand01(seed + 2))
		var upward_speed: float = lerpf(0.12, 0.58, _rand01(seed + 3))
		if family == "wet":
			horizontal_speed *= 0.72
			upward_speed *= 1.35
		elif family == "soil":
			horizontal_speed *= 1.08
			upward_speed *= 1.10
		var velocity := Vector3(
			cos(angle) * horizontal_speed,
			upward_speed,
			sin(angle) * horizontal_speed
		) * event_velocity_scale * lerpf(0.72, 1.25, strength)
		var lifetime: float = lerpf(0.26, profile.maximum_lifetime, _rand01(seed + 4))
		if family == "wet":
			lifetime *= 0.72
		var size: float = lerpf(0.025, 0.070, _rand01(seed + 5))
		if event_type == "landing":
			size *= lerpf(1.0, 1.35, strength)
		var color: Color = base_color
		color.a *= lerpf(0.72, 1.0, _rand01(seed + 6))
		particle_states[slot] = {
			"active": true,
			"position": world_position + Vector3(
				cos(angle) * 0.08,
				0.025,
				sin(angle) * 0.08
			),
			"velocity": velocity,
			"age": 0.0,
			"lifetime": lifetime,
			"size": size,
			"color": color,
			"family": family,
		}
		contact_multimesh.set_instance_color(slot, color)
		_update_particle_transform(slot, particle_states[slot])


func _update_particles(delta: float) -> void:
	if contact_multimesh == null or delta <= 0.0:
		return
	var drag_factor: float = exp(-profile.drag * delta)
	for index: int in range(particle_states.size()):
		var state: Dictionary = particle_states[index]
		if not bool(state.get("active", false)):
			continue
		var age: float = float(state.get("age", 0.0)) + delta
		var lifetime: float = maxf(float(state.get("lifetime", 0.3)), 0.01)
		if age >= lifetime:
			particle_states[index] = {"active": false}
			_hide_particle(index)
			continue
		var velocity: Vector3 = state.get("velocity", Vector3.ZERO)
		velocity.y -= profile.gravity * delta
		velocity.x *= drag_factor
		velocity.z *= drag_factor
		var position: Vector3 = state.get("position", Vector3.ZERO)
		position += velocity * delta
		state["age"] = age
		state["velocity"] = velocity
		state["position"] = position
		particle_states[index] = state
		_update_particle_transform(index, state)


func _update_particle_transform(index: int, state: Dictionary) -> void:
	if contact_multimesh == null:
		return
	var age: float = float(state.get("age", 0.0))
	var lifetime: float = maxf(float(state.get("lifetime", 0.3)), 0.01)
	var remaining: float = clampf(1.0 - age / lifetime, 0.0, 1.0)
	var size: float = float(state.get("size", 0.04)) * lerpf(0.35, 1.0, remaining)
	var family: String = str(state.get("family", "stone"))
	var shape_scale := Vector3(size, size * 0.55, size)
	if family == "wet":
		shape_scale = Vector3(size * 0.72, size * 1.45, size * 0.72)
	elif family == "soil":
		shape_scale = Vector3(size * 1.18, size * 0.42, size * 0.92)
	var position: Vector3 = state.get("position", Vector3.ZERO)
	contact_multimesh.set_instance_transform(
		index,
		Transform3D(Basis().scaled(shape_scale), position)
	)
	var color: Color = state.get("color", Color.WHITE)
	color.a *= remaining * remaining
	contact_multimesh.set_instance_color(index, color)


func _hide_particle(index: int) -> void:
	if contact_multimesh == null:
		return
	contact_multimesh.set_instance_transform(
		index,
		Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)
	)
	contact_multimesh.set_instance_color(index, Color(0.0, 0.0, 0.0, 0.0))


func clear_particles() -> void:
	if contact_multimesh == null:
		return
	for index: int in range(particle_states.size()):
		particle_states[index] = {"active": false}
		_hide_particle(index)


func _rand01(seed: int) -> float:
	var value: float = sin(float(seed) * 12.9898 + 78.233) * 43758.5453
	return value - floor(value)


func get_active_particle_count() -> int:
	var count: int = 0
	for state: Dictionary in particle_states:
		if bool(state.get("active", false)):
			count += 1
	return count


func get_debug_data() -> Dictionary:
	return {
		"ground_contact_presentation_director": true,
		"initialized": profile != null and contact_multimesh != null,
		"profile_id": profile.profile_id if profile != null else "",
		"enabled": enabled,
		"quality": active_quality,
		"event_listener": presentation_director != null,
		"presented_events": presented_count,
		"particles_spawned": particles_spawned,
		"active_particles": get_active_particle_count(),
		"pool_size": particle_states.size(),
		"surface_counts": surface_counts.duplicate(true),
		"last_surface": last_surface,
		"last_event_type": last_event_type,
		"pooled_multimesh": true,
		"raycasts_on_semantic_events_only": true,
		"follows_lighting_quality": true,
		"collision_unchanged": true,
		"gameplay_authority": false,
	}
