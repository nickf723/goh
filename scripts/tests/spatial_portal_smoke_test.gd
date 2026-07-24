extends Node

const LabScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_spatial_portal_lab_v1.tscn"
)
const PortalTransform = preload(
	"res://scripts/space/spatial_portal_transform_3d.gd"
)

var failures: Array[String] = []


func _ready() -> void:
	validate_transform_round_trip()
	await validate_character_momentum()
	await validate_projectile_momentum()
	await validate_laboratory_contract()
	if failures.is_empty():
		print("SPATIAL_PORTAL_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("SPATIAL_PORTAL_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func validate_transform_round_trip() -> void:
	var source: Transform3D = Transform3D(
		Basis.from_euler(Vector3(0.0, deg_to_rad(15.0), 0.0)),
		Vector3(-2.0, 1.5, 4.0)
	)
	var destination: Transform3D = Transform3D(
		Basis.from_euler(Vector3(0.0, deg_to_rad(92.0), 0.0)),
		Vector3(8.0, 3.0, -5.0)
	)
	var traveler: Transform3D = Transform3D(
		Basis.from_euler(Vector3(0.0, deg_to_rad(-24.0), 0.0)),
		Vector3(-1.4, 1.8, 3.1)
	)
	var mapped: Transform3D = PortalTransform.map_transform(
		source,
		destination,
		traveler
	)
	var returned: Transform3D = PortalTransform.map_transform(
		destination,
		source,
		mapped
	)
	if returned.origin.distance_to(traveler.origin) > 0.001:
		failures.append("source → destination → source must restore relative position")
	for axis: Vector3 in [
		Vector3.RIGHT,
		Vector3.UP,
		Vector3.BACK,
	]:
		if (returned.basis * axis).distance_to(traveler.basis * axis) > 0.001:
			failures.append("round-trip mapping must restore traveler orientation")
			break

	var velocity: Vector3 = Vector3(3.0, -4.0, -12.0)
	var mapped_velocity: Vector3 = PortalTransform.map_vector(
		source,
		destination,
		velocity
	)
	if absf(mapped_velocity.length() - velocity.length()) > 0.001:
		failures.append("orthonormal portal mapping must conserve vector magnitude")


func validate_character_momentum() -> void:
	var pair: Array[SpatialPortal3D] = await create_test_pair()
	var entry: SpatialPortal3D = pair[0]
	var destination: SpatialPortal3D = pair[1]
	var traveler: CharacterBody3D = CharacterBody3D.new()
	traveler.name = "TestCharacterTraveler"
	traveler.global_position = Vector3(0.0, 1.0, 0.8)
	traveler.velocity = Vector3(0.0, 0.0, -9.0)
	add_child(traveler)
	var original_speed: float = traveler.velocity.length()
	if not entry.teleport_traveler(traveler):
		failures.append("linked portal must accept a CharacterBody3D traveler")
	else:
		if absf(traveler.velocity.length() - original_speed) > 0.001:
			failures.append("character speed must survive portal traversal")
		if traveler.global_position.distance_to(destination.global_position) > 3.0:
			failures.append("character must emerge near its linked destination")
		if entry.teleport_traveler(traveler):
			failures.append("reentry cooldown must suppress duplicate teleports")
	traveler.queue_free()
	entry.queue_free()
	destination.queue_free()
	await get_tree().process_frame


func validate_projectile_momentum() -> void:
	var pair: Array[SpatialPortal3D] = await create_test_pair()
	var entry: SpatialPortal3D = pair[0]
	var projectile: GenericProjectile = GenericProjectile.new()
	projectile.name = "TestPortalProjectile"
	projectile.max_lifetime = 30.0
	projectile.respond_to_airflow = false
	projectile.global_position = Vector3(0.0, 1.0, 0.8)
	projectile.motion_velocity = Vector3(0.0, 0.0, -18.0)
	projectile.direction = projectile.motion_velocity.normalized()
	projectile.is_launched = true
	add_child(projectile)
	var original_speed: float = projectile.motion_velocity.length()
	if not entry.teleport_traveler(projectile):
		failures.append("linked portal must accept a GenericProjectile traveler")
	else:
		if absf(projectile.motion_velocity.length() - original_speed) > 0.001:
			failures.append("projectile speed must survive portal traversal")
		if projectile.direction.distance_to(
			projectile.motion_velocity.normalized()
		) > 0.001:
			failures.append("projectile direction must follow mapped motion")
	projectile.queue_free()
	for portal: SpatialPortal3D in pair:
		portal.queue_free()
	await get_tree().process_frame


func create_test_pair() -> Array[SpatialPortal3D]:
	var entry: SpatialPortal3D = SpatialPortal3D.new()
	entry.name = "TestEntry"
	entry.build_runtime_visuals = false
	entry.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 0.0))
	add_child(entry)
	var destination: SpatialPortal3D = SpatialPortal3D.new()
	destination.name = "TestDestination"
	destination.build_runtime_visuals = false
	destination.global_transform = Transform3D(
		Basis.from_euler(Vector3(0.0, deg_to_rad(90.0), 0.0)),
		Vector3(12.0, 2.0, -4.0)
	)
	add_child(destination)
	entry.set_linked_portal(destination)
	destination.set_linked_portal(entry)
	await get_tree().process_frame
	var result: Array[SpatialPortal3D] = [entry, destination]
	return result


func validate_laboratory_contract() -> void:
	var lab: Node = LabScene.instantiate()
	if lab == null:
		failures.append("Spatial Portal Laboratory failed to instantiate")
		return
	add_child(lab)
	await get_tree().process_frame
	await get_tree().physics_frame
	var portal_count: int = 0
	for node: Node in get_tree().get_nodes_in_group("spatial_portals"):
		if lab.is_ancestor_of(node):
			portal_count += 1
	if portal_count != 6:
		failures.append("laboratory must contain three bidirectional portal pairs")
	if lab.get_node_or_null("MomentumCrate") == null:
		failures.append("laboratory is missing its rigid-body momentum crate")
	if lab.get_node_or_null("LoopOrb") == null:
		failures.append("laboratory is missing its falling momentum-loop orb")
	if lab.get_node_or_null("PortalProjectileTarget") == null:
		failures.append("laboratory is missing its redirected projectile target")
	if lab.get_node_or_null("PortalHUD/Panel/Margin/Readout") == null:
		failures.append("laboratory is missing its compact portal readout")
	var debug_data: Variant = lab.call("get_debug_data")
	if not (debug_data is Dictionary) or int(debug_data.get("portals", 0)) != 6:
		failures.append("laboratory debug contract must report all six portals")
	lab.queue_free()
	await get_tree().process_frame

