extends Node3D
class_name WildsAnimalHabitatEncounter

const AnimalScript = preload(
	"res://scripts/animals/generic_animal_actor.gd"
)
const TraversalMediumScript = preload(
	"res://scripts/mobs/mob_traversal_medium.gd"
)

var habitat_id: String = ""
var animals: Array[GenericAnimalActor] = []
var water_volume: SwimmingWaterVolume
var traversal_medium: MobTraversalMedium
var habitat_bounds_min: Vector3 = Vector3(-8.0, -1.0, 0.0)
var habitat_bounds_max: Vector3 = Vector3(8.0, 4.0, 28.0)
var forage_target_local: Vector3 = Vector3.ZERO
var water_target_local: Vector3 = Vector3.ZERO
var configured: bool = false


func configure(habitat_id_value: String) -> void:
	if configured:
		return
	habitat_id = habitat_id_value.strip_edges().to_lower()
	name = "WildlifeHabitat_" + habitat_id
	match habitat_id:
		"cypress_basin":
			_build_cypress_basin_habitat()
		"wet_woodland":
			_build_wet_woodland_habitat()
		"pine_ridge":
			_build_pine_ridge_habitat()
		_:
			push_warning(
				"WildsAnimalHabitatEncounter received unsupported habitat: "
				+ habitat_id
			)
	configured = true
	add_to_group("wilds_animal_habitat")
	add_to_group("debuggable")


func get_animals() -> Array[GenericAnimalActor]:
	return animals.duplicate()


func get_species_ids() -> Array[String]:
	var result: Array[String] = []
	for animal: GenericAnimalActor in animals:
		if animal != null and is_instance_valid(animal):
			result.append(animal.species_id)
	return result


func get_animal_grace_target(
	_animal: GenericAnimalActor
) -> Node3D:
	return _resolve_grace_target()


func get_animal_threat_target(
	_animal: GenericAnimalActor
) -> Node3D:
	return _resolve_grace_target()


func is_grace_threatening(
	_animal: GenericAnimalActor
) -> bool:
	return false


func is_animal_threat_mode_enabled(
	_animal: GenericAnimalActor
) -> bool:
	return false


func get_animal_noise_position(
	_animal: GenericAnimalActor
) -> Vector3:
	var grace: Node3D = _resolve_grace_target()
	return grace.global_position if grace != null else global_position


func get_animal_noise_strength(
	_animal: GenericAnimalActor
) -> float:
	var grace: Node3D = _resolve_grace_target()
	if not grace is CharacterBody3D:
		return 0.0
	var velocity: Vector3 = (grace as CharacterBody3D).velocity
	return clampf(Vector2(velocity.x, velocity.z).length() / 7.0, 0.0, 1.0)


func get_animal_forage_position(
	animal: GenericAnimalActor
) -> Vector3:
	if forage_target_local != Vector3.ZERO:
		return to_global(forage_target_local)
	return animal.home_position if animal != null else global_position


func get_animal_water_position(
	_animal: GenericAnimalActor
) -> Vector3:
	return to_global(water_target_local)


func clamp_animal_position(value: Vector3) -> Vector3:
	var local_value: Vector3 = to_local(value)
	local_value.x = clampf(
		local_value.x,
		habitat_bounds_min.x,
		habitat_bounds_max.x
	)
	local_value.y = clampf(
		local_value.y,
		habitat_bounds_min.y,
		habitat_bounds_max.y
	)
	local_value.z = clampf(
		local_value.z,
		habitat_bounds_min.z,
		habitat_bounds_max.z
	)
	return to_global(local_value)


func broadcast_animal_alert(
	source: GenericAnimalActor,
	position_value: Vector3,
	severity: float
) -> void:
	if source == null:
		return
	for animal: GenericAnimalActor in animals:
		if (
			animal == null
			or animal == source
			or not is_instance_valid(animal)
			or animal.species_id != source.species_id
		):
			continue
		animal.receive_social_alert(position_value, severity)


func reset_habitat() -> void:
	for animal: GenericAnimalActor in animals:
		if animal == null or not is_instance_valid(animal):
			continue
		animal.reset_actor()
		_register_initial_medium(animal)


func get_debug_data() -> Dictionary:
	var modes: Dictionary = {}
	for animal: GenericAnimalActor in animals:
		if animal != null and is_instance_valid(animal):
			modes[animal.species_id] = animal.get_active_locomotion_mode()
	return {
		"wilds_animal_habitat": true,
		"habitat_id": habitat_id,
		"animal_count": animals.size(),
		"species": get_species_ids(),
		"active_modes": modes,
		"has_water": water_volume != null,
		"traversal_mode": (
			traversal_medium.get_locomotion_mode()
			if traversal_medium != null
			else ""
		),
	}


func _build_cypress_basin_habitat() -> void:
	habitat_bounds_min = Vector3(2.35, -0.95, 9.8)
	habitat_bounds_max = Vector3(7.0, 0.8, 18.2)
	water_target_local = Vector3(4.7, -0.45, 14.0)
	forage_target_local = Vector3(3.4, 0.08, 17.0)

	water_volume = SwimmingWaterVolume.new()
	water_volume.name = "CypressWildlifeWater"
	water_volume.position = water_target_local
	water_volume.surface_height_offset = 0.5
	water_volume.current_velocity = Vector3(0.0, 0.0, 0.12)
	water_volume.swirl_strength = 0.09
	water_volume.inward_strength = 0.05
	water_volume.water_label = "Cypress Channel"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.5, 1.0, 8.2)
	collision.shape = shape
	water_volume.add_child(collision)
	add_child(water_volume)

	var goose: GenericAnimalActor = _spawn_animal(
		"Cypress Goose",
		"goose",
		Vector3(4.1, -0.42, 16.8),
		"cautious",
		2.15,
		"swimmer",
		2.1
	)
	var trout: GenericAnimalActor = _spawn_animal(
		"Cypress Trout",
		"trout",
		Vector3(5.35, -0.5, 12.4),
		"cautious",
		1.85,
		"swimmer",
		2.4
	)
	_register_initial_medium(goose)
	_register_initial_medium(trout)


func _build_wet_woodland_habitat() -> void:
	habitat_bounds_min = Vector3(-5.5, 0.1, 14.3)
	habitat_bounds_max = Vector3(-3.25, 3.35, 16.8)
	forage_target_local = Vector3(-4.25, 0.15, 16.2)
	_add_static_cylinder(
		"GeckoSnag",
		0.46,
		3.35,
		Vector3(-4.6, 1.67, 15.5),
		Color(0.24, 0.13, 0.055)
	)
	_add_visual_sphere(
		"SnagMoss",
		Vector3(-4.48, 2.55, 15.48),
		Vector3(0.55, 0.38, 0.58),
		Color(0.17, 0.34, 0.09, 1.0)
	)

	var climb_points := PackedVector3Array([
		Vector3(0.0, 0.42, -0.28),
		Vector3(0.0, 2.82, -0.2),
		Vector3(0.0, 2.2, 0.28),
		Vector3(0.0, 0.85, 0.32),
	])
	traversal_medium = TraversalMediumScript.new() as MobTraversalMedium
	traversal_medium.name = "WoodlandClimbRoute"
	traversal_medium.position = Vector3(-3.94, 0.0, 15.5)
	traversal_medium.adhesion_strength = 1.55
	traversal_medium.waypoint_radius = 0.3
	traversal_medium.configure(
		"climber",
		["vertical_surface", "tree_bark"],
		Vector3.RIGHT,
		climb_points,
		"Wet Woodland Snag"
	)
	_add_traversal_collision(
		traversal_medium,
		Vector3(0.85, 3.15, 1.25),
		Vector3(0.0, 1.58, 0.0)
	)
	add_child(traversal_medium)

	var gecko: GenericAnimalActor = _spawn_animal(
		"Woodland Gecko",
		"gecko",
		to_local(traversal_medium.get_entry_position()),
		"curious",
		2.0,
		"climber",
		1.2
	)
	_register_initial_medium(gecko)


func _build_pine_ridge_habitat() -> void:
	habitat_bounds_min = Vector3(-6.3, 1.25, 12.6)
	habitat_bounds_max = Vector3(-2.9, 2.25, 15.7)
	forage_target_local = Vector3(-5.8, 1.7, 15.0)
	_add_visual_sphere(
		"BurrowMound",
		Vector3(-4.6, 1.62, 14.0),
		Vector3(2.45, 0.62, 1.72),
		Color(0.34, 0.22, 0.09, 0.42),
		true
	)
	_add_hole_marker(Vector3(-6.0, 1.91, 13.2))
	_add_hole_marker(Vector3(-3.2, 1.86, 14.8))

	var burrow_points := PackedVector3Array([
		Vector3(-1.4, 0.76, -0.8),
		Vector3(-0.65, 0.32, -0.25),
		Vector3(0.1, 0.64, 0.65),
		Vector3(1.4, 0.71, 0.8),
		Vector3(0.55, 0.36, -0.55),
		Vector3(-0.55, 0.58, 0.2),
	])
	traversal_medium = TraversalMediumScript.new() as MobTraversalMedium
	traversal_medium.name = "PineRidgeBurrowRoute"
	traversal_medium.position = Vector3(-4.6, 1.15, 14.0)
	traversal_medium.adhesion_strength = 0.0
	traversal_medium.waypoint_radius = 0.28
	traversal_medium.configure(
		"burrower",
		["soil", "root_tunnel"],
		Vector3.ZERO,
		burrow_points,
		"Pine Ridge Burrow"
	)
	_add_traversal_collision(
		traversal_medium,
		Vector3(4.5, 1.35, 3.5),
		Vector3(0.0, 0.68, 0.0)
	)
	add_child(traversal_medium)

	var mole: GenericAnimalActor = _spawn_animal(
		"Ridge Mole",
		"mole",
		to_local(traversal_medium.get_entry_position()),
		"cautious",
		1.65,
		"burrower",
		1.45
	)
	_register_initial_medium(mole)


func _spawn_animal(
	name_value: String,
	species: String,
	local_position: Vector3,
	profile: String,
	speed: float,
	initial_mode: String,
	wander_radius_value: float
) -> GenericAnimalActor:
	var animal := AnimalScript.new() as GenericAnimalActor
	animal.name = name_value.replace(" ", "")
	animal.animal_name = name_value
	animal.species_id = species
	animal.personality_profile_id = profile
	animal.move_speed = speed
	animal.wander_radius = wander_radius_value
	animal.initial_locomotion_mode = initial_mode
	animal.show_state_label = false
	animal.position = local_position
	add_child(animal)
	animals.append(animal)
	return animal


func _register_initial_medium(
	animal: GenericAnimalActor
) -> void:
	if animal == null or animal.locomotion == null:
		return
	match animal.get_active_locomotion_mode():
		"swimmer":
			if water_volume != null:
				animal.locomotion.enter_water(water_volume)
		"climber", "burrower":
			if traversal_medium != null:
				traversal_medium.reset_actor_route(animal)
				animal.locomotion.enter_traversal_medium(
					traversal_medium
				)


func _resolve_grace_target() -> Node3D:
	if get_tree() == null:
		return null
	var candidate: Node = get_tree().get_first_node_in_group("player")
	return candidate as Node3D if candidate is Node3D else null


func _add_traversal_collision(
	medium: MobTraversalMedium,
	size: Vector3,
	position_value: Vector3
) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = position_value
	medium.add_child(collision)


func _add_static_cylinder(
	node_name: String,
	radius: float,
	height: float,
	position_value: Vector3,
	color: Color
) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	add_child(body)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.82
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 9
	visual.mesh = mesh
	visual.material_override = _material(color)
	body.add_child(visual)


func _add_visual_sphere(
	node_name: String,
	position_value: Vector3,
	scale_value: Vector3,
	color: Color,
	transparent: bool = false
) -> void:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.scale = scale_value
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 10
	mesh.rings = 7
	visual.mesh = mesh
	visual.material_override = _material(color, transparent)
	add_child(visual)


func _add_hole_marker(position_value: Vector3) -> void:
	var marker := MeshInstance3D.new()
	marker.name = "BurrowOpening"
	marker.position = position_value
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.34
	mesh.bottom_radius = 0.38
	mesh.height = 0.045
	mesh.radial_segments = 12
	marker.mesh = mesh
	marker.material_override = _material(Color(0.055, 0.035, 0.02, 1.0))
	add_child(marker)


func _material(
	color: Color,
	transparent: bool = false
) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.9
	if transparent or color.a < 0.99:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return result
