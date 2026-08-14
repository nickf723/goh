extends Node3D
class_name Grace05BlockoutModel

# Grace 0.5 is an intentionally simple, modular production-proxy character.
# It uses an import-shaped humanoid skeleton and bone-attached forms so the
# production presentation bridge can test silhouette, materials, sockets, and
# extreme combat poses before a final skinned Blender model exists.

const BONE_SPECS: Array[Dictionary] = [
	{"name": "Root", "parent": "", "origin": Vector3.ZERO},
	{"name": "Hips", "parent": "Root", "origin": Vector3(0.0, 0.88, 0.0)},
	{"name": "Spine", "parent": "Hips", "origin": Vector3(0.0, 0.16, 0.0)},
	{"name": "Spine1", "parent": "Spine", "origin": Vector3(0.0, 0.15, 0.0)},
	{"name": "UpperChest", "parent": "Spine1", "origin": Vector3(0.0, 0.17, 0.0)},
	{"name": "Neck", "parent": "UpperChest", "origin": Vector3(0.0, 0.17, -0.005)},
	{"name": "Head", "parent": "Neck", "origin": Vector3(0.0, 0.18, -0.01)},
	{"name": "LeftShoulder", "parent": "UpperChest", "origin": Vector3(-0.12, 0.11, 0.0)},
	{"name": "LeftUpperArm", "parent": "LeftShoulder", "origin": Vector3(-0.14, -0.02, 0.0)},
	{"name": "LeftLowerArm", "parent": "LeftUpperArm", "origin": Vector3(-0.02, -0.30, 0.0)},
	{"name": "LeftHand", "parent": "LeftLowerArm", "origin": Vector3(-0.015, -0.27, 0.0)},
	{"name": "RightShoulder", "parent": "UpperChest", "origin": Vector3(0.12, 0.11, 0.0)},
	{"name": "RightUpperArm", "parent": "RightShoulder", "origin": Vector3(0.14, -0.02, 0.0)},
	{"name": "RightLowerArm", "parent": "RightUpperArm", "origin": Vector3(0.02, -0.30, 0.0)},
	{"name": "RightHand", "parent": "RightLowerArm", "origin": Vector3(0.015, -0.27, 0.0)},
	{"name": "LeftUpperLeg", "parent": "Hips", "origin": Vector3(-0.145, -0.08, 0.0)},
	{"name": "LeftLowerLeg", "parent": "LeftUpperLeg", "origin": Vector3(0.0, -0.40, 0.0)},
	{"name": "LeftFoot", "parent": "LeftLowerLeg", "origin": Vector3(0.0, -0.37, -0.035)},
	{"name": "LeftToes", "parent": "LeftFoot", "origin": Vector3(0.0, -0.04, -0.20)},
	{"name": "RightUpperLeg", "parent": "Hips", "origin": Vector3(0.145, -0.08, 0.0)},
	{"name": "RightLowerLeg", "parent": "RightUpperLeg", "origin": Vector3(0.0, -0.40, 0.0)},
	{"name": "RightFoot", "parent": "RightLowerLeg", "origin": Vector3(0.0, -0.37, -0.035)},
	{"name": "RightToes", "parent": "RightFoot", "origin": Vector3(0.0, -0.04, -0.20)},
]

var skeleton: Skeleton3D
var bone_indices: Dictionary = {}
var attachments: Dictionary = {}
var materials: Dictionary = {}
var visible_mesh_count: int = 0


func _enter_tree() -> void:
	if get_node_or_null("Skeleton3D") != null:
		return
	_build_materials()
	_build_skeleton()
	_build_character()
	set_meta("grace_0_5_blockout", true)
	set_meta("production_proxy", true)
	add_to_group("grace_0_5_blockout")
	add_to_group("debuggable")


func _build_skeleton() -> void:
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	add_child(skeleton)
	for spec: Dictionary in BONE_SPECS:
		var bone_name: String = str(spec.get("name", ""))
		var parent_name: String = str(spec.get("parent", ""))
		var rest_origin: Vector3 = spec.get("origin", Vector3.ZERO) as Vector3
		skeleton.add_bone(bone_name)
		var bone_index: int = skeleton.find_bone(bone_name)
		if parent_name != "" and bone_indices.has(parent_name):
			skeleton.set_bone_parent(bone_index, int(bone_indices[parent_name]))
		skeleton.set_bone_rest(
			bone_index,
			Transform3D(Basis.IDENTITY, rest_origin)
		)
		bone_indices[bone_name] = bone_index


func _build_materials() -> void:
	materials["skin"] = _make_material(
		Color(0.57, 0.39, 0.3, 1.0),
		0.0,
		0.64
	)
	materials["skin_warm"] = _make_material(
		Color(0.66, 0.43, 0.34, 1.0),
		0.0,
		0.68
	)
	materials["robe"] = _make_material(
		Color(0.72, 0.68, 0.59, 1.0),
		0.0,
		0.82
	)
	materials["robe_shadow"] = _make_material(
		Color(0.42, 0.38, 0.36, 1.0),
		0.0,
		0.86
	)
	materials["underlayer"] = _make_material(
		Color(0.09, 0.065, 0.13, 1.0),
		0.0,
		0.72
	)
	materials["sash"] = _make_material(
		Color(0.32, 0.1, 0.55, 1.0),
		0.08,
		0.48,
		Color(0.12, 0.025, 0.25, 1.0),
		0.22
	)
	materials["leather"] = _make_material(
		Color(0.105, 0.065, 0.045, 1.0),
		0.03,
		0.74
	)
	materials["hair"] = _make_material(
		Color(0.045, 0.032, 0.045, 1.0),
		0.0,
		0.58
	)
	materials["brass"] = _make_material(
		Color(0.72, 0.46, 0.13, 1.0),
		0.78,
		0.28,
		Color(0.22, 0.09, 0.015, 1.0),
		0.16
	)
	materials["eye_white"] = _make_material(
		Color(0.82, 0.78, 0.7, 1.0),
		0.0,
		0.32
	)
	materials["eye"] = _make_material(
		Color(0.055, 0.045, 0.095, 1.0),
		0.04,
		0.24,
		Color(0.11, 0.045, 0.28, 1.0),
		0.42
	)
	materials["eye_glint"] = _make_material(
		Color(0.86, 0.92, 1.0, 1.0),
		0.0,
		0.2,
		Color(0.55, 0.72, 1.0, 1.0),
		1.4
	)
	materials["mouth"] = _make_material(
		Color(0.24, 0.07, 0.075, 1.0),
		0.0,
		0.55
	)


func _build_character() -> void:
	_build_head()
	_build_torso()
	_build_arms()
	_build_legs()
	_build_robe_panels()
	_build_accessories()


func _build_head() -> void:
	_add_mesh(
		"HeadShape",
		"Head",
		_sphere(0.215, 0.43, 20, 10),
		materials["skin"] as Material,
		Vector3(0.0, 0.09, -0.015),
		Vector3.ZERO,
		Vector3(0.94, 1.06, 0.9)
	)
	_add_mesh(
		"LeftEar",
		"Head",
		_sphere(0.052, 0.104, 12, 6),
		materials["skin"] as Material,
		Vector3(-0.19, 0.085, -0.002),
		Vector3.ZERO,
		Vector3(0.58, 1.0, 0.45)
	)
	_add_mesh(
		"RightEar",
		"Head",
		_sphere(0.052, 0.104, 12, 6),
		materials["skin"] as Material,
		Vector3(0.19, 0.085, -0.002),
		Vector3.ZERO,
		Vector3(0.58, 1.0, 0.45)
	)

	# Chunky hair masses preserve silhouette without strand simulation.
	_add_mesh(
		"HairCrown",
		"Head",
		_sphere(0.225, 0.45, 18, 9),
		materials["hair"] as Material,
		Vector3(0.0, 0.175, 0.055),
		Vector3(-8.0, 0.0, 0.0),
		Vector3(1.04, 0.72, 0.96)
	)
	_add_mesh(
		"HairBack",
		"Head",
		_capsule(0.165, 0.46, 16, 6),
		materials["hair"] as Material,
		Vector3(0.0, -0.045, 0.135),
		Vector3(4.0, 0.0, 0.0),
		Vector3(1.04, 1.0, 0.82)
	)
	_add_mesh(
		"HairLockLeft",
		"Head",
		_capsule(0.062, 0.35, 12, 5),
		materials["hair"] as Material,
		Vector3(-0.155, -0.035, 0.035),
		Vector3(0.0, 0.0, -9.0),
		Vector3(0.9, 1.0, 0.76)
	)
	_add_mesh(
		"HairLockRight",
		"Head",
		_capsule(0.062, 0.35, 12, 5),
		materials["hair"] as Material,
		Vector3(0.155, -0.035, 0.035),
		Vector3(0.0, 0.0, 9.0),
		Vector3(0.9, 1.0, 0.76)
	)
	_add_mesh(
		"FringeLeft",
		"Head",
		_box(Vector3(0.105, 0.18, 0.055)),
		materials["hair"] as Material,
		Vector3(-0.07, 0.165, -0.17),
		Vector3(-9.0, 0.0, -19.0)
	)
	_add_mesh(
		"FringeRight",
		"Head",
		_box(Vector3(0.095, 0.16, 0.05)),
		materials["hair"] as Material,
		Vector3(0.07, 0.17, -0.17),
		Vector3(-7.0, 0.0, 17.0)
	)

	for side: float in [-1.0, 1.0]:
		_add_mesh(
			"EyeWhite" + ("Left" if side < 0.0 else "Right"),
			"Head",
			_sphere(0.048, 0.096, 12, 6),
			materials["eye_white"] as Material,
			Vector3(side * 0.074, 0.112, -0.196),
			Vector3.ZERO,
			Vector3(1.0, 0.78, 0.44)
		)
		_add_mesh(
			"Eye" + ("Left" if side < 0.0 else "Right"),
			"Head",
			_sphere(0.027, 0.054, 10, 5),
			materials["eye"] as Material,
			Vector3(side * 0.072, 0.11, -0.223),
			Vector3.ZERO,
			Vector3(0.92, 1.0, 0.48)
		)
		_add_mesh(
			"EyeGlint" + ("Left" if side < 0.0 else "Right"),
			"Head",
			_sphere(0.009, 0.018, 8, 4),
			materials["eye_glint"] as Material,
			Vector3(side * 0.065, 0.12, -0.239),
			Vector3.ZERO,
			Vector3.ONE
		)
		_add_mesh(
			"Brow" + ("Left" if side < 0.0 else "Right"),
			"Head",
			_box(Vector3(0.09, 0.018, 0.022)),
			materials["hair"] as Material,
			Vector3(side * 0.074, 0.177, -0.208),
			Vector3(0.0, 0.0, side * -6.0)
		)

	_add_mesh(
		"Nose",
		"Head",
		_sphere(0.033, 0.066, 10, 5),
		materials["skin_warm"] as Material,
		Vector3(0.0, 0.075, -0.221),
		Vector3.ZERO,
		Vector3(0.72, 1.0, 0.62)
	)
	_add_mesh(
		"Mouth",
		"Head",
		_box(Vector3(0.085, 0.014, 0.015)),
		materials["mouth"] as Material,
		Vector3(0.0, 0.005, -0.222),
		Vector3(0.0, 0.0, -2.0)
	)


func _build_torso() -> void:
	_add_mesh(
		"Neck",
		"Neck",
		_cylinder(0.078, 0.078, 0.16, 14),
		materials["skin"] as Material,
		Vector3(0.0, 0.04, 0.0)
	)
	_add_mesh(
		"UnderTorso",
		"UpperChest",
		_capsule(0.205, 0.45, 16, 6),
		materials["underlayer"] as Material,
		Vector3(0.0, -0.18, 0.0),
		Vector3.ZERO,
		Vector3(0.96, 1.0, 0.76)
	)
	_add_mesh(
		"RobeUpper",
		"UpperChest",
		_cylinder(0.245, 0.29, 0.46, 16),
		materials["robe"] as Material,
		Vector3(0.0, -0.18, 0.005),
		Vector3.ZERO,
		Vector3(1.0, 1.0, 0.78)
	)
	_add_mesh(
		"RobeCollar",
		"UpperChest",
		_cylinder(0.19, 0.225, 0.105, 16),
		materials["robe_shadow"] as Material,
		Vector3(0.0, 0.015, -0.005),
		Vector3.ZERO,
		Vector3(1.0, 1.0, 0.8)
	)
	_add_mesh(
		"LowerTorso",
		"Hips",
		_capsule(0.215, 0.36, 14, 5),
		materials["underlayer"] as Material,
		Vector3(0.0, 0.18, 0.01),
		Vector3.ZERO,
		Vector3(1.0, 1.0, 0.8)
	)
	_add_mesh(
		"WaistSash",
		"Hips",
		_cylinder(0.255, 0.255, 0.09, 16),
		materials["sash"] as Material,
		Vector3(0.0, 0.245, -0.005),
		Vector3.ZERO,
		Vector3(1.0, 1.0, 0.82)
	)


func _build_arms() -> void:
	_build_arm("Left", -1.0)
	_build_arm("Right", 1.0)


func _build_arm(prefix: String, side: float) -> void:
	var upper_bone: String = prefix + "UpperArm"
	var lower_bone: String = prefix + "LowerArm"
	var hand_bone: String = prefix + "Hand"
	_add_mesh(
		prefix + "ShoulderSleeve",
		upper_bone,
		_sphere(0.105, 0.21, 14, 7),
		materials["robe"] as Material,
		Vector3(0.0, -0.035, 0.0),
		Vector3.ZERO,
		Vector3(1.08, 0.9, 0.9)
	)
	_add_mesh(
		prefix + "UpperSleeve",
		upper_bone,
		_capsule(0.072, 0.325, 12, 5),
		materials["robe"] as Material,
		Vector3(0.0, -0.15, 0.0),
		Vector3.ZERO,
		Vector3(1.0, 1.0, 0.92)
	)
	_add_mesh(
		prefix + "Forearm",
		lower_bone,
		_capsule(0.058, 0.285, 12, 5),
		materials["underlayer"] as Material,
		Vector3(0.0, -0.135, 0.0),
		Vector3.ZERO,
		Vector3(1.0, 1.0, 0.92)
	)
	_add_mesh(
		prefix + "WristWrap",
		lower_bone,
		_cylinder(0.067, 0.067, 0.09, 12),
		materials["sash"] as Material,
		Vector3(0.0, -0.235, 0.0)
	)
	_add_mesh(
		prefix + "HandShape",
		hand_bone,
		_capsule(0.053, 0.145, 12, 5),
		materials["skin"] as Material,
		Vector3(0.0, -0.052, -0.008),
		Vector3(4.0, 0.0, side * -2.0),
		Vector3(0.92, 1.0, 0.72)
	)
	_add_mesh(
		prefix + "Thumb",
		hand_bone,
		_capsule(0.022, 0.085, 8, 4),
		materials["skin"] as Material,
		Vector3(side * 0.048, -0.045, -0.015),
		Vector3(0.0, 0.0, side * -42.0),
		Vector3.ONE
	)


func _build_legs() -> void:
	_build_leg("Left", -1.0)
	_build_leg("Right", 1.0)


func _build_leg(prefix: String, side: float) -> void:
	var upper_bone: String = prefix + "UpperLeg"
	var lower_bone: String = prefix + "LowerLeg"
	var foot_bone: String = prefix + "Foot"
	var toe_bone: String = prefix + "Toes"
	_add_mesh(
		prefix + "Thigh",
		upper_bone,
		_capsule(0.09, 0.42, 12, 5),
		materials["underlayer"] as Material,
		Vector3(0.0, -0.19, 0.0),
		Vector3.ZERO,
		Vector3(0.96, 1.0, 0.88)
	)
	_add_mesh(
		prefix + "Shin",
		lower_bone,
		_capsule(0.073, 0.39, 12, 5),
		materials["underlayer"] as Material,
		Vector3(0.0, -0.18, 0.0),
		Vector3.ZERO,
		Vector3(0.95, 1.0, 0.88)
	)
	_add_mesh(
		prefix + "BootLeg",
		lower_bone,
		_cylinder(0.087, 0.105, 0.29, 12),
		materials["leather"] as Material,
		Vector3(0.0, -0.235, -0.005),
		Vector3.ZERO,
		Vector3(1.0, 1.0, 0.92)
	)
	_add_mesh(
		prefix + "BootCuff",
		lower_bone,
		_cylinder(0.105, 0.105, 0.075, 12),
		materials["sash"] as Material,
		Vector3(0.0, -0.105, 0.0),
		Vector3.ZERO,
		Vector3(1.0, 1.0, 0.92)
	)
	_add_mesh(
		prefix + "BootFoot",
		foot_bone,
		_box(Vector3(0.18, 0.12, 0.32)),
		materials["leather"] as Material,
		Vector3(0.0, -0.045, -0.12),
		Vector3(4.0, 0.0, side * 1.5)
	)
	_add_mesh(
		prefix + "BootToe",
		toe_bone,
		_box(Vector3(0.17, 0.105, 0.18)),
		materials["leather"] as Material,
		Vector3(0.0, -0.005, -0.075),
		Vector3(3.0, 0.0, 0.0)
	)


func _build_robe_panels() -> void:
	_add_mesh(
		"FrontPanelLeft",
		"LeftUpperLeg",
		_box(Vector3(0.205, 0.46, 0.055)),
		materials["robe"] as Material,
		Vector3(0.055, -0.13, -0.115),
		Vector3(-6.0, 0.0, -4.0)
	)
	_add_mesh(
		"FrontPanelRight",
		"RightUpperLeg",
		_box(Vector3(0.205, 0.46, 0.055)),
		materials["robe"] as Material,
		Vector3(-0.055, -0.13, -0.115),
		Vector3(-6.0, 0.0, 4.0)
	)
	_add_mesh(
		"SidePanelLeft",
		"LeftUpperLeg",
		_box(Vector3(0.055, 0.405, 0.215)),
		materials["robe_shadow"] as Material,
		Vector3(-0.11, -0.11, 0.015),
		Vector3(0.0, -4.0, -3.0)
	)
	_add_mesh(
		"SidePanelRight",
		"RightUpperLeg",
		_box(Vector3(0.055, 0.405, 0.215)),
		materials["robe_shadow"] as Material,
		Vector3(0.11, -0.11, 0.015),
		Vector3(0.0, 4.0, 3.0)
	)
	_add_mesh(
		"BackRobePanel",
		"Hips",
		_box(Vector3(0.39, 0.43, 0.06)),
		materials["robe"] as Material,
		Vector3(0.0, -0.105, 0.15),
		Vector3(5.0, 0.0, 0.0)
	)
	_add_mesh(
		"SashTailLeft",
		"Hips",
		_box(Vector3(0.085, 0.37, 0.04)),
		materials["sash"] as Material,
		Vector3(-0.095, 0.035, -0.175),
		Vector3(-7.0, 2.0, -8.0)
	)
	_add_mesh(
		"SashTailRight",
		"Hips",
		_box(Vector3(0.075, 0.31, 0.04)),
		materials["sash"] as Material,
		Vector3(0.075, 0.06, -0.18),
		Vector3(-5.0, -2.0, 7.0)
	)


func _build_accessories() -> void:
	_add_mesh(
		"ChestClasp",
		"UpperChest",
		_sphere(0.052, 0.104, 12, 6),
		materials["brass"] as Material,
		Vector3(0.0, -0.02, -0.235),
		Vector3.ZERO,
		Vector3(1.0, 0.76, 0.46)
	)
	_add_mesh(
		"SashBuckle",
		"Hips",
		_box(Vector3(0.12, 0.09, 0.045)),
		materials["brass"] as Material,
		Vector3(0.0, 0.245, -0.215),
		Vector3(0.0, 0.0, 4.0)
	)
	_add_mesh(
		"ShoulderPinLeft",
		"LeftShoulder",
		_sphere(0.038, 0.076, 10, 5),
		materials["brass"] as Material,
		Vector3(-0.015, 0.0, -0.075),
		Vector3.ZERO,
		Vector3(1.0, 0.8, 0.5)
	)
	_add_mesh(
		"ShoulderPinRight",
		"RightShoulder",
		_sphere(0.038, 0.076, 10, 5),
		materials["brass"] as Material,
		Vector3(0.015, 0.0, -0.075),
		Vector3.ZERO,
		Vector3(1.0, 0.8, 0.5)
	)


func _get_attachment(bone_name: String) -> BoneAttachment3D:
	if attachments.has(bone_name):
		return attachments[bone_name] as BoneAttachment3D
	var attachment: BoneAttachment3D = BoneAttachment3D.new()
	attachment.name = bone_name + "Attachment"
	attachment.bone_name = bone_name
	skeleton.add_child(attachment)
	attachments[bone_name] = attachment
	return attachment


func _add_mesh(
	part_name: String,
	bone_name: String,
	mesh: Mesh,
	material: Material,
	local_position: Vector3,
	local_rotation_degrees: Vector3 = Vector3.ZERO,
	local_scale: Vector3 = Vector3.ONE
) -> MeshInstance3D:
	var attachment: BoneAttachment3D = _get_attachment(bone_name)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = local_position
	instance.rotation_degrees = local_rotation_degrees
	instance.scale = local_scale
	attachment.add_child(instance)
	visible_mesh_count += 1
	return instance


func _sphere(
	radius: float,
	height: float,
	radial_segments: int,
	rings: int
) -> SphereMesh:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh.radial_segments = maxi(radial_segments, 8)
	mesh.rings = maxi(rings, 4)
	return mesh


func _capsule(
	radius: float,
	height: float,
	radial_segments: int,
	rings: int
) -> CapsuleMesh:
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh.radial_segments = maxi(radial_segments, 8)
	mesh.rings = maxi(rings, 3)
	return mesh


func _cylinder(
	top_radius: float,
	bottom_radius: float,
	height: float,
	radial_segments: int
) -> CylinderMesh:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = maxf(height, 0.01)
	mesh.radial_segments = maxi(radial_segments, 8)
	return mesh


func _box(size: Vector3) -> BoxMesh:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return mesh


func _make_material(
	color: Color,
	metallic_value: float,
	roughness_value: float,
	emission_color: Color = Color(0.0, 0.0, 0.0, 1.0),
	emission_energy: float = 0.0
) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = clampf(metallic_value, 0.0, 1.0)
	material.roughness = clampf(roughness_value, 0.0, 1.0)
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission_color
		material.emission_energy_multiplier = emission_energy
	return material


func get_debug_data() -> Dictionary:
	return {
		"grace_0_5_blockout": true,
		"production_proxy": true,
		"skeleton_found": skeleton != null,
		"bone_count": skeleton.get_bone_count() if skeleton != null else 0,
		"visible_meshes": visible_mesh_count,
		"material_families": materials.size(),
		"modular_hair": true,
		"split_robe_panels": true,
		"weapon_hand": "RightHand",
		"support_hand": "LeftHand",
	}
