extends Node3D
class_name PulleyTether3D

signal tether_broken(reason: String, peak_tension: float)

@export var body_a_path: NodePath
@export var pulley_a_path: NodePath
@export var pulley_b_path: NodePath
@export var body_b_path: NodePath
@export var material_profile: FlexibleMaterialProfile
@export_range(1.0, 50.0, 0.05) var total_length: float = 9.0
@export_range(0.0, 2.0, 0.01) var visual_radius_scale: float = 1.0
@export var debug_tension_color: bool = true

var current_tension: float = 0.0
var peak_tension: float = 0.0
var is_broken: bool = false

var _body_a: Node3D
var _pulley_a: Node3D
var _pulley_b: Node3D
var _body_b: Node3D
var _visuals: Array[MeshInstance3D] = []
var _material: StandardMaterial3D


func _ready() -> void:
	add_to_group("pulley_tethers")
	_resolve_nodes()
	_create_visuals()


func _physics_process(_delta: float) -> void:
	if not _nodes_are_valid():
		_resolve_nodes()
	if not _nodes_are_valid():
		return
	_update_tension()
	_apply_forces()
	_update_visuals()


func reset_pulley() -> void:
	is_broken = false
	current_tension = 0.0
	peak_tension = 0.0
	_update_visuals()


func reel(delta_length: float) -> void:
	total_length = maxf(1.0, total_length + delta_length)


func get_rope_length() -> float:
	if not _nodes_are_valid():
		return 0.0
	return (
		_body_a.global_position.distance_to(_pulley_a.global_position)
		+ _pulley_a.global_position.distance_to(_pulley_b.global_position)
		+ _pulley_b.global_position.distance_to(_body_b.global_position)
	)


func get_debug_data() -> Dictionary:
	return {
		"rope_length": get_rope_length(),
		"total_length": total_length,
		"tension": current_tension,
		"peak_tension": peak_tension,
		"broken": is_broken,
	}


func _resolve_nodes() -> void:
	_body_a = get_node_or_null(body_a_path) as Node3D
	_pulley_a = get_node_or_null(pulley_a_path) as Node3D
	_pulley_b = get_node_or_null(pulley_b_path) as Node3D
	_body_b = get_node_or_null(body_b_path) as Node3D


func _nodes_are_valid() -> bool:
	return (
		is_instance_valid(_body_a)
		and is_instance_valid(_pulley_a)
		and is_instance_valid(_pulley_b)
		and is_instance_valid(_body_b)
	)


func _update_tension() -> void:
	if is_broken or material_profile == null:
		current_tension = 0.0
		return
	var extension := maxf(get_rope_length() - total_length, 0.0)
	var outward_speed := maxf(_vertical_outward_speed(_body_a, _pulley_a) + _vertical_outward_speed(_body_b, _pulley_b), 0.0)
	current_tension = extension * material_profile.stiffness + outward_speed * material_profile.tension_damping
	peak_tension = maxf(peak_tension, current_tension)
	if current_tension > material_profile.break_strength:
		is_broken = true
		current_tension = 0.0
		tether_broken.emit("overload", peak_tension)


func _apply_forces() -> void:
	if is_broken or current_tension <= 0.0:
		return
	_apply_force_toward(_body_a, _pulley_a.global_position)
	_apply_force_toward(_body_b, _pulley_b.global_position)


func _apply_force_toward(body: Node3D, target: Vector3) -> void:
	var direction := body.global_position.direction_to(target)
	var force := direction * current_tension
	if body is RigidBody3D:
		(body as RigidBody3D).apply_central_force(force)
	elif body.has_method("apply_tether_force"):
		body.call("apply_tether_force", force)


func _vertical_outward_speed(body: Node3D, pulley: Node3D) -> float:
	var direction := pulley.global_position.direction_to(body.global_position)
	var velocity := Vector3.ZERO
	if body is RigidBody3D:
		velocity = (body as RigidBody3D).linear_velocity
	elif body is CharacterBody3D:
		velocity = (body as CharacterBody3D).velocity
	return velocity.dot(direction)


func _create_visuals() -> void:
	_material = StandardMaterial3D.new()
	for index: int in range(3):
		var strand := MeshInstance3D.new()
		strand.name = "PulleyStrand" + str(index + 1)
		var mesh := CylinderMesh.new()
		var radius := (material_profile.radius if material_profile != null else 0.05) * visual_radius_scale
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = 1.0
		mesh.radial_segments = 8
		strand.mesh = mesh
		strand.material_override = _material
		add_child(strand)
		_visuals.append(strand)


func _update_visuals() -> void:
	if _visuals.size() != 3 or not _nodes_are_valid():
		return
	_place_strand(_visuals[0], _body_a.global_position, _pulley_a.global_position, true)
	_place_strand(_visuals[1], _pulley_a.global_position, _pulley_b.global_position, not is_broken)
	_place_strand(_visuals[2], _pulley_b.global_position, _body_b.global_position, true)
	var color := material_profile.base_color if material_profile != null else Color.WHITE
	if debug_tension_color and material_profile != null:
		color = color.lerp(Color(1.0, 0.05, 0.02, 1.0), clampf(current_tension / material_profile.break_strength, 0.0, 1.0))
	_material.albedo_color = color
	_material.metallic = material_profile.metallic if material_profile != null else 0.0
	_material.roughness = material_profile.roughness if material_profile != null else 0.8


func _place_strand(strand: MeshInstance3D, point_a: Vector3, point_b: Vector3, should_show: bool) -> void:
	strand.visible = should_show
	if not should_show:
		return
	var offset := point_b - point_a
	var length := offset.length()
	if length <= 0.0001:
		strand.visible = false
		return
	strand.global_position = point_a.lerp(point_b, 0.5)
	strand.quaternion = Quaternion(Vector3.UP, offset / length)
	strand.scale = Vector3(1.0, length, 1.0)

