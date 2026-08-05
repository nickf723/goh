extends "res://scripts/physics/field_responsive_body.gd"
class_name MechanismWeightBlock

@export_group("Weight Block")
@export var block_size: Vector3 = Vector3(1.3, 1.3, 1.3)
@export var block_color: Color = Color(0.48, 0.27, 0.11, 1.0)
@export_range(0.0, 1.0, 0.01) var block_metallic: float = 0.16
@export_range(0.0, 1.0, 0.01) var block_roughness: float = 0.74
@export var show_mass_label: bool = true
@export var show_soul_mark: bool = true
@export_range(8.0, 120.0, 1.0) var label_visibility_distance: float = 42.0

@onready var collision_shape: CollisionShape3D = get_node_or_null(
	"CollisionShape3D"
) as CollisionShape3D
@onready var body_mesh: MeshInstance3D = get_node_or_null("Body") as MeshInstance3D
@onready var soul_mark: MeshInstance3D = get_node_or_null(
	"SoulMark"
) as MeshInstance3D
@onready var mass_label: Label3D = get_node_or_null("MassLabel") as Label3D


func _ready() -> void:
	super._ready()
	add_to_group("mechanism_weights")
	add_to_group("soul_grip_puzzle_weights")
	set_meta("mechanism_mass_kg", get_effective_mass())
	set_meta("mechanism_initial_transform", transform)
	_refresh_weight_block()


func configure_weight_block(
	mass_kg: float,
	size_value: Vector3,
	color: Color,
	label: String = ""
) -> void:
	mass_override_kg = maxf(mass_kg, 0.1)
	block_size = Vector3(
		maxf(size_value.x, 0.1),
		maxf(size_value.y, 0.1),
		maxf(size_value.z, 0.1)
	)
	block_color = color
	body_label = (
		label
		if label.strip_edges() != ""
		else str(snappedf(mass_override_kg, 0.1)) + " kg Soul-Grippable Weight"
	)
	set_meta("mechanism_mass_kg", mass_override_kg)
	if is_inside_tree():
		_refresh_weight_block()


func _refresh_weight_block() -> void:
	var safe_size := Vector3(
		maxf(block_size.x, 0.1),
		maxf(block_size.y, 0.1),
		maxf(block_size.z, 0.1)
	)
	block_size = safe_size
	set_meta("mechanism_mass_kg", get_effective_mass())

	if collision_shape != null:
		var shape := BoxShape3D.new()
		shape.size = safe_size
		collision_shape.shape = shape

	if body_mesh != null:
		var mesh := BoxMesh.new()
		mesh.size = safe_size
		body_mesh.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = block_color
		material.metallic = clampf(block_metallic, 0.0, 1.0)
		material.roughness = clampf(block_roughness, 0.0, 1.0)
		body_mesh.material_override = material

	if soul_mark != null:
		soul_mark.visible = show_soul_mark
		soul_mark.position = Vector3(0.0, safe_size.y * 0.5 + 0.055, 0.0)
		var mark_scale: float = clampf(
			minf(safe_size.x, safe_size.z) / 1.3,
			0.55,
			1.45
		)
		soul_mark.scale = Vector3.ONE * mark_scale

	if mass_label != null:
		mass_label.visible = show_mass_label
		mass_label.position = Vector3(0.0, safe_size.y * 0.5 + 0.48, 0.0)
		mass_label.text = (
			str(snappedf(get_effective_mass(), 0.1))
			+ " KG\nSOUL GRIP"
		)
		mass_label.visibility_range_end = label_visibility_distance
		mass_label.visibility_range_end_margin = 4.0

	if soul_manipulable != null:
		soul_manipulable.anchor_offset = Vector3.ZERO


func get_mechanism_mass_kg() -> float:
	return get_effective_mass()


func interact() -> Dictionary:
	return {
		"message": (
			body_label
			+ " weighs "
			+ str(snappedf(get_effective_mass(), 0.1))
			+ " kg and bears a Soul mark."
		),
		"objective": "Select Soul Grip, hold Cast, and place the weight on a pressure plate.",
	}


func reset_target() -> void:
	super.reset_target()
	_refresh_weight_block()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["mechanism_weight_block"] = true
	data["mass_kg"] = get_effective_mass()
	data["block_size"] = block_size
	data["soul_grippable"] = (
		soul_manipulable != null
		and soul_manipulable.manipulation_enabled
	)
	return data
