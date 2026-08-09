extends Node3D
class_name GreenGrottoFaunaVisual

const MaterialLibraryScript = preload(
	"res://scripts/environment/green_grotto_material_library.gd"
)

@export_enum("raptor", "sauropod") var species: String = "raptor"
@export_range(0.2, 4.0, 0.05) var creature_scale: float = 1.0
@export var patrol_radius: float = 0.0
@export_range(0.0, 2.0, 0.05) var patrol_speed: float = 0.22
@export var idle_phase: float = 0.0
@export var animate_creature: bool = true

var elapsed: float = 0.0
var home_position: Vector3 = Vector3.ZERO
var visual_root: Node3D = null
var head_root: Node3D = null
var tail_root: Node3D = null
var material_library: GreenGrottoMaterialLibrary = null


func _ready() -> void:
	home_position = position
	material_library = MaterialLibraryScript.new() as GreenGrottoMaterialLibrary
	add_to_group("green_grotto_fauna")
	add_to_group("environmental_fauna")
	set_meta("species", species)
	set_meta("art_target_fauna", true)
	_build_visual()


func _process(delta: float) -> void:
	if not animate_creature or visual_root == null:
		return
	elapsed += maxf(delta, 0.0)
	var time_value: float = elapsed * (1.6 if species == "raptor" else 0.65) + idle_phase
	visual_root.position.y = sin(time_value) * (0.018 if species == "raptor" else 0.028) * creature_scale
	if head_root != null:
		head_root.rotation.z = sin(time_value * 0.73) * (0.055 if species == "raptor" else 0.025)
		head_root.rotation.y = sin(time_value * 0.41) * (0.11 if species == "raptor" else 0.04)
	if tail_root != null:
		tail_root.rotation.y = sin(time_value * 0.84) * (0.08 if species == "raptor" else 0.035)
	if patrol_radius > 0.01:
		_update_patrol(time_value)


func _update_patrol(time_value: float) -> void:
	var angle: float = time_value * patrol_speed
	var offset := Vector3(
		cos(angle) * patrol_radius,
		0.0,
		sin(angle) * patrol_radius * 0.65
	)
	position = home_position + offset
	var tangent := Vector3(
		-sin(angle),
		0.0,
		cos(angle) * 0.65
	)
	if tangent.length_squared() > 0.001:
		rotation.y = atan2(tangent.x, tangent.z)


func _build_visual() -> void:
	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	visual_root.scale = Vector3.ONE * creature_scale
	add_child(visual_root)
	if species == "sauropod":
		_build_sauropod()
	else:
		_build_raptor()


func _build_raptor() -> void:
	var body_material: Material = material_library.get_material("fauna_dark")
	var feather_material: Material = material_library.get_material("fauna_feather")

	var body := _add_ellipsoid(
		visual_root,
		"Body",
		Vector3(0.0, 0.72, 0.0),
		Vector3(0.48, 0.38, 0.82),
		body_material
	)
	body.rotation.x = deg_to_rad(-7.0)

	head_root = Node3D.new()
	head_root.name = "HeadRoot"
	head_root.position = Vector3(0.0, 1.05, -0.72)
	visual_root.add_child(head_root)
	_add_ellipsoid(
		head_root,
		"Head",
		Vector3.ZERO,
		Vector3(0.28, 0.25, 0.34),
		body_material
	)
	_add_ellipsoid(
		head_root,
		"Snout",
		Vector3(0.0, -0.02, -0.28),
		Vector3(0.20, 0.13, 0.34),
		feather_material
	)
	for side: float in [-1.0, 1.0]:
		var eye := _add_ellipsoid(
			head_root,
			"Eye" + ("L" if side < 0.0 else "R"),
			Vector3(side * 0.19, 0.075, -0.22),
			Vector3(0.035, 0.035, 0.035),
			_make_eye_material()
		)
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	for index: int in range(5):
		var crest := _add_ellipsoid(
			head_root,
			"Crest%02d" % index,
			Vector3(0.0, 0.20 + float(index) * 0.028, 0.12 - float(index) * 0.10),
			Vector3(0.045, 0.16 - float(index) * 0.012, 0.09),
			feather_material
		)
		crest.rotation.x = deg_to_rad(-22.0 - float(index) * 4.0)

	tail_root = Node3D.new()
	tail_root.name = "TailRoot"
	tail_root.position = Vector3(0.0, 0.82, 0.67)
	visual_root.add_child(tail_root)
	_add_tapered_chain(
		tail_root,
		"Tail",
		[
			Vector3(0.0, 0.0, 0.0),
			Vector3(0.0, 0.0, 0.65),
			Vector3(0.02, 0.03, 1.25),
			Vector3(0.08, 0.06, 1.82),
		],
		0.18,
		0.055,
		body_material
	)

	for side: float in [-1.0, 1.0]:
		var hip := Vector3(side * 0.28, 0.70, 0.22)
		var knee := Vector3(side * 0.35, 0.35, 0.10)
		var ankle := Vector3(side * 0.30, 0.08, -0.02)
		_add_cylinder_between(visual_root, "UpperLeg", hip, knee, 0.105, body_material)
		_add_cylinder_between(visual_root, "LowerLeg", knee, ankle, 0.082, feather_material)
		_add_cylinder_between(
			visual_root,
			"Foot",
			ankle,
			ankle + Vector3(0.0, -0.02, -0.32),
			0.055,
			body_material
		)

		var shoulder := Vector3(side * 0.31, 0.90, -0.40)
		var hand := Vector3(side * 0.42, 0.63, -0.62)
		_add_cylinder_between(visual_root, "Arm", shoulder, hand, 0.055, feather_material)

	for index: int in range(7):
		var angle: float = -0.95 + float(index) * 0.31
		var feather := _add_ellipsoid(
			visual_root,
			"BodyFeather%02d" % index,
			Vector3(
				sin(angle) * 0.40,
				0.85 + cos(angle) * 0.08,
				0.05 + float(index % 2) * 0.12
			),
			Vector3(0.055, 0.18, 0.26),
			feather_material
		)
		feather.rotation = Vector3(deg_to_rad(24.0), -angle, angle * 0.3)


func _build_sauropod() -> void:
	var body_material: Material = material_library.get_material("fauna_dark")
	var accent_material: Material = material_library.get_material("fauna_feather")
	_add_ellipsoid(
		visual_root,
		"Body",
		Vector3(0.0, 1.7, 0.0),
		Vector3(1.3, 0.85, 2.05),
		body_material
	)
	_add_ellipsoid(
		visual_root,
		"Shoulders",
		Vector3(0.0, 2.0, -1.05),
		Vector3(1.05, 0.78, 1.0),
		body_material
	)

	head_root = Node3D.new()
	head_root.name = "HeadRoot"
	visual_root.add_child(head_root)
	_add_tapered_chain(
		head_root,
		"Neck",
		[
			Vector3(0.0, 2.1, -1.25),
			Vector3(0.02, 2.8, -1.65),
			Vector3(0.05, 3.65, -1.85),
			Vector3(0.08, 4.55, -1.72),
			Vector3(0.10, 5.30, -1.45),
		],
		0.34,
		0.18,
		body_material
	)
	_add_ellipsoid(
		head_root,
		"Head",
		Vector3(0.10, 5.42, -1.58),
		Vector3(0.32, 0.24, 0.46),
		accent_material
	)

	tail_root = Node3D.new()
	tail_root.name = "TailRoot"
	visual_root.add_child(tail_root)
	_add_tapered_chain(
		tail_root,
		"Tail",
		[
			Vector3(0.0, 1.75, 1.75),
			Vector3(0.05, 1.62, 2.65),
			Vector3(0.15, 1.45, 3.55),
			Vector3(0.35, 1.30, 4.45),
			Vector3(0.68, 1.24, 5.30),
		],
		0.38,
		0.10,
		body_material
	)

	for side: float in [-1.0, 1.0]:
		for z_value: float in [-0.95, 0.92]:
			var hip := Vector3(side * 0.72, 1.40, z_value)
			var foot := Vector3(side * 0.78, 0.16, z_value + 0.08)
			_add_cylinder_between(visual_root, "Leg", hip, foot, 0.28, body_material)
			_add_ellipsoid(
				visual_root,
				"Foot",
				foot + Vector3(0.0, -0.04, -0.05),
				Vector3(0.36, 0.15, 0.46),
				accent_material
			)


func _add_tapered_chain(
	parent: Node3D,
	prefix: String,
	points: Array[Vector3],
	start_radius: float,
	end_radius: float,
	material: Material
) -> void:
	if points.size() < 2:
		return
	for index: int in range(points.size() - 1):
		var progress: float = float(index) / float(maxi(points.size() - 2, 1))
		var radius: float = lerpf(start_radius, end_radius, progress)
		_add_cylinder_between(
			parent,
			prefix + "%02d" % index,
			points[index],
			points[index + 1],
			radius,
			material
		)


func _add_ellipsoid(
	parent: Node3D,
	node_name: String,
	position_value: Vector3,
	scale_value: Vector3,
	material: Material
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.position = position_value
	node.scale = scale_value
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 10
	mesh.rings = 6
	node.mesh = mesh
	node.material_override = material
	parent.add_child(node)
	return node


func _add_cylinder_between(
	parent: Node3D,
	node_name: String,
	start: Vector3,
	finish: Vector3,
	radius: float,
	material: Material
) -> MeshInstance3D:
	var delta: Vector3 = finish - start
	var length: float = delta.length()
	var node := MeshInstance3D.new()
	node.name = node_name
	node.position = (start + finish) * 0.5
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.82
	mesh.bottom_radius = radius
	mesh.height = maxf(length, 0.01)
	mesh.radial_segments = 8
	node.mesh = mesh
	node.material_override = material
	if length > 0.001:
		node.quaternion = Quaternion(Vector3.UP, delta / length)
	parent.add_child(node)
	return node


func _make_eye_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.02, 0.012, 0.005, 1.0)
	material.roughness = 0.18
	material.metallic = 0.1
	return material


func get_debug_data() -> Dictionary:
	return {
		"green_grotto_fauna": true,
		"species": species,
		"scale": creature_scale,
		"patrol_radius": patrol_radius,
		"animated": animate_creature,
	}
