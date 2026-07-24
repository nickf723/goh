extends Area3D
class_name SpatialPortal3D

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")

signal traveler_teleported(
	traveler: Node3D,
	destination: SpatialPortal3D,
	entry_speed: float,
	exit_speed: float
)

@export var portal_id: String = "portal"
@export var linked_portal_path: NodePath
@export var active: bool = true
@export var keep_characters_upright: bool = true
@export_range(0.05, 2.0, 0.05) var exit_clearance: float = 0.75
@export_range(0.05, 1.0, 0.01) var reentry_cooldown: float = 0.22
@export var portal_size: Vector2 = Vector2(2.8, 3.6)
@export var portal_color: Color = Color(0.2, 0.75, 1.0, 1.0)
@export var build_runtime_visuals: bool = true

var linked_portal: SpatialPortal3D = null
var traveler_cooldowns: Dictionary = {}
var teleport_count: int = 0
var last_entry_speed: float = 0.0
var last_exit_speed: float = 0.0


func _ready() -> void:
	add_to_group("spatial_portals")
	add_to_group("debuggable")
	collision_layer = 0
	collision_mask = 0xFFFFFFFF
	monitoring = true
	monitorable = true
	if get_node_or_null("CollisionShape3D") == null:
		create_trigger_shape()
	if build_runtime_visuals and get_node_or_null("PortalVisual") == null:
		create_portal_visual()
	if not linked_portal_path.is_empty():
		linked_portal = get_node_or_null(linked_portal_path) as SpatialPortal3D
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	var expired_ids: Array[int] = []
	for id_variant: Variant in traveler_cooldowns.keys():
		var traveler_id: int = int(id_variant)
		var time_left: float = float(traveler_cooldowns[traveler_id]) - delta
		if time_left <= 0.0:
			expired_ids.append(traveler_id)
		else:
			traveler_cooldowns[traveler_id] = time_left
	for traveler_id: int in expired_ids:
		traveler_cooldowns.erase(traveler_id)


func set_linked_portal(new_linked_portal: SpatialPortal3D) -> void:
	linked_portal = new_linked_portal


func get_exit_normal() -> Vector3:
	return global_transform.basis.z.normalized()


func teleport_traveler(traveler: Node3D) -> bool:
	if (
		not active
		or traveler == null
		or not is_instance_valid(traveler)
		or linked_portal == null
		or not is_instance_valid(linked_portal)
		or not linked_portal.active
	):
		return false
	var traveler_id: int = traveler.get_instance_id()
	if traveler_cooldowns.has(traveler_id):
		return false

	var source_transform: Transform3D = global_transform
	var destination_transform: Transform3D = linked_portal.global_transform
	var mapping: Transform3D = SpatialPortalTransform3D.mapping_between(
		source_transform,
		destination_transform
	)
	var entry_velocity: Vector3 = get_traveler_velocity(traveler)
	var entry_speed: float = entry_velocity.length()
	var mapped_transform: Transform3D = (
		mapping * traveler.global_transform.orthonormalized()
	)
	mapped_transform.origin += linked_portal.get_exit_normal() * linked_portal.exit_clearance

	if traveler is CharacterBody3D and keep_characters_upright:
		mapped_transform.basis = get_upright_character_basis(
			traveler.global_transform,
			mapping
		)
	traveler.global_transform = mapped_transform
	set_traveler_velocity(traveler, mapping.basis * entry_velocity)

	if traveler is RigidBody3D:
		var rigid_body: RigidBody3D = traveler as RigidBody3D
		rigid_body.angular_velocity = mapping.basis * rigid_body.angular_velocity
		rigid_body.sleeping = false

	var exit_speed: float = get_traveler_velocity(traveler).length()
	traveler_cooldowns[traveler_id] = reentry_cooldown
	linked_portal.traveler_cooldowns[traveler_id] = linked_portal.reentry_cooldown
	teleport_count += 1
	last_entry_speed = entry_speed
	last_exit_speed = exit_speed
	traveler_teleported.emit(traveler, linked_portal, entry_speed, exit_speed)
	return true


func get_traveler_velocity(traveler: Node3D) -> Vector3:
	if traveler is CharacterBody3D:
		return (traveler as CharacterBody3D).velocity
	if traveler is RigidBody3D:
		return (traveler as RigidBody3D).linear_velocity
	if traveler is GenericProjectile:
		return (traveler as GenericProjectile).motion_velocity
	if traveler.has_method("get_portal_velocity"):
		var value: Variant = traveler.call("get_portal_velocity")
		if value is Vector3:
			return value as Vector3
	return Vector3.ZERO


func set_traveler_velocity(traveler: Node3D, new_velocity: Vector3) -> void:
	if traveler is CharacterBody3D:
		(traveler as CharacterBody3D).velocity = new_velocity
		return
	if traveler is RigidBody3D:
		(traveler as RigidBody3D).linear_velocity = new_velocity
		return
	if traveler is GenericProjectile:
		var projectile: GenericProjectile = traveler as GenericProjectile
		projectile.motion_velocity = new_velocity
		if new_velocity.length() > 0.001:
			projectile.direction = new_velocity.normalized()
			if projectile.rotate_to_direction:
				projectile.look_at(
					projectile.global_position + projectile.direction,
					Vector3.UP
				)
		return
	if traveler.has_method("set_portal_velocity"):
		traveler.call("set_portal_velocity", new_velocity)


func get_upright_character_basis(
	traveler_transform: Transform3D,
	mapping: Transform3D
) -> Basis:
	var previous_forward: Vector3 = -traveler_transform.basis.z.normalized()
	var mapped_forward: Vector3 = mapping.basis * previous_forward
	mapped_forward.y = 0.0
	if mapped_forward.length() <= 0.001:
		mapped_forward = linked_portal.get_exit_normal()
		mapped_forward.y = 0.0
	if mapped_forward.length() <= 0.001:
		return Basis.IDENTITY
	return Basis.looking_at(mapped_forward.normalized(), Vector3.UP)


func find_portal_traveler(start_node: Node) -> Node3D:
	var current: Node = start_node
	while current != null:
		if (
			current is CharacterBody3D
			or current is RigidBody3D
			or current is GenericProjectile
			or current.is_in_group("portal_travelers")
		):
			return current as Node3D
		current = current.get_parent()
	return null


func _on_body_entered(body: Node3D) -> void:
	var traveler: Node3D = find_portal_traveler(body)
	if traveler != null:
		teleport_traveler(traveler)


func _on_area_entered(area: Area3D) -> void:
	var traveler: Node3D = find_portal_traveler(area)
	if traveler != null:
		teleport_traveler(traveler)


func create_trigger_shape() -> void:
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(portal_size.x, portal_size.y, 0.65)
	collision.shape = shape
	add_child(collision)


func create_portal_visual() -> void:
	var visual_root: Node3D = Node3D.new()
	visual_root.name = "PortalVisual"
	add_child(visual_root)

	var interior: MeshInstance3D = MeshInstance3D.new()
	interior.name = "Interior"
	var interior_mesh: BoxMesh = BoxMesh.new()
	interior_mesh.size = Vector3(
		maxf(portal_size.x - 0.32, 0.3),
		maxf(portal_size.y - 0.32, 0.3),
		0.035
	)
	interior.mesh = interior_mesh
	var interior_color: Color = portal_color
	interior_color.a = 0.32
	interior.material_override = ElementVisuals.make_material(
		interior_color,
		2.2,
		0.32,
		true
	)
	visual_root.add_child(interior)

	create_frame_piece(
		visual_root,
		"TopFrame",
		Vector3(0.0, portal_size.y * 0.5, 0.0),
		Vector3(portal_size.x + 0.22, 0.18, 0.16)
	)
	create_frame_piece(
		visual_root,
		"BottomFrame",
		Vector3(0.0, -portal_size.y * 0.5, 0.0),
		Vector3(portal_size.x + 0.22, 0.18, 0.16)
	)
	create_frame_piece(
		visual_root,
		"LeftFrame",
		Vector3(-portal_size.x * 0.5, 0.0, 0.0),
		Vector3(0.18, portal_size.y + 0.22, 0.16)
	)
	create_frame_piece(
		visual_root,
		"RightFrame",
		Vector3(portal_size.x * 0.5, 0.0, 0.0),
		Vector3(0.18, portal_size.y + 0.22, 0.16)
	)

	var arrow: MeshInstance3D = MeshInstance3D.new()
	arrow.name = "ExitArrow"
	var arrow_mesh: PrismMesh = PrismMesh.new()
	arrow_mesh.size = Vector3(0.48, 0.12, 0.65)
	arrow.mesh = arrow_mesh
	arrow.position = Vector3(0.0, -portal_size.y * 0.62, 0.32)
	arrow.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	arrow.material_override = ElementVisuals.make_material(
		portal_color,
		3.0,
		1.0,
		false
	)
	visual_root.add_child(arrow)


func create_frame_piece(
	parent: Node3D,
	piece_name: String,
	local_position: Vector3,
	size: Vector3
) -> void:
	var piece: MeshInstance3D = MeshInstance3D.new()
	piece.name = piece_name
	piece.position = local_position
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	piece.mesh = mesh
	piece.material_override = ElementVisuals.make_material(
		portal_color,
		3.0,
		1.0,
		false
	)
	parent.add_child(piece)


func get_debug_data() -> Dictionary:
	return {
		"portal_id": portal_id,
		"active": active,
		"linked": linked_portal != null and is_instance_valid(linked_portal),
		"teleports": teleport_count,
		"entry_speed": last_entry_speed,
		"exit_speed": last_exit_speed,
		"exit_normal": get_exit_normal(),
	}
