extends Node3D
class_name GraceWireSkeletonRenderer

@export_group("Proportions")
@export_range(0.2, 0.6, 0.01) var upper_arm_length: float = 0.33
@export_range(0.2, 0.6, 0.01) var lower_arm_length: float = 0.34
@export_range(0.3, 0.7, 0.01) var upper_leg_length: float = 0.38
@export_range(0.3, 0.7, 0.01) var lower_leg_length: float = 0.4
@export_range(0.5, 1.1, 0.01) var leg_reach: float = 0.74
@export_range(0.08, 0.35, 0.01) var foot_length: float = 0.2

@export_group("Wire Presentation")
@export_range(0.006, 0.08, 0.002) var bone_radius: float = 0.022
@export_range(0.015, 0.12, 0.002) var joint_radius: float = 0.045
@export var hide_source_meshes: bool = true

@export_group("Foot Grounding")
@export_range(0.01, 0.12, 0.002) var ground_contact_clearance: float = 0.05
@export_range(0.0, 0.08, 0.002) var ankle_ground_lift: float = 0.02
@export_range(0.05, 0.6, 0.01) var ground_probe_up: float = 0.24
@export_range(0.1, 1.2, 0.01) var ground_probe_down: float = 0.48
@export_range(0.0, 0.4, 0.01) var ground_max_lift: float = 0.2
@export_range(0.0, 0.3, 0.01) var ground_max_drop: float = 0.1
@export_range(1.0, 40.0, 0.5) var grounding_response: float = 24.0
@export_range(0.0, 1.0, 0.01) var minimum_ground_normal_dot: float = 0.45
@export var grounding_collision_mask: int = 0xFFFFFFFF

const JOINT_IDS: Array[String] = [
	"pelvis",
	"spine",
	"chest",
	"neck",
	"head",
	"left_shoulder",
	"left_elbow",
	"left_hand",
	"right_shoulder",
	"right_elbow",
	"right_hand",
	"left_hip",
	"left_knee",
	"left_ankle",
	"left_toe",
	"right_hip",
	"right_knee",
	"right_ankle",
	"right_toe",
]

const BONE_PAIRS: Array = [
	["pelvis", "spine"],
	["spine", "chest"],
	["chest", "neck"],
	["neck", "head"],
	["chest", "left_shoulder"],
	["left_shoulder", "left_elbow"],
	["left_elbow", "left_hand"],
	["chest", "right_shoulder"],
	["right_shoulder", "right_elbow"],
	["right_elbow", "right_hand"],
	["pelvis", "left_hip"],
	["left_hip", "left_knee"],
	["left_knee", "left_ankle"],
	["left_ankle", "left_toe"],
	["pelvis", "right_hip"],
	["right_hip", "right_knee"],
	["right_knee", "right_ankle"],
	["right_ankle", "right_toe"],
]

const GROUNDED_STATES: Array[String] = [
	"idle",
	"locomotion",
	"landing",
	"exhausted",
	"attack",
	"guard",
	"dodge",
	"hit",
	"cast",
	"item",
	"interact",
]

var visual: StylizedActorVisual
var actor: CharacterBody3D
var source_visual_root: Node3D
var source_body_root: Node3D
var source_head_root: Node3D
var source_left_shoulder: Node3D
var source_right_shoulder: Node3D
var source_left_hand: Node3D
var source_right_hand: Node3D
var source_left_leg: Node3D
var source_right_leg: Node3D

var joint_nodes: Dictionary = {}
var bone_nodes: Dictionary = {}
var joint_positions: Dictionary = {}
var grounding_offsets: Dictionary = {
	"left_ankle": 0.0,
	"left_toe": 0.0,
	"right_ankle": 0.0,
	"right_toe": 0.0,
}
var grounding_hits: Dictionary = {
	"left_ankle": false,
	"left_toe": false,
	"right_ankle": false,
	"right_toe": false,
}

var center_material: StandardMaterial3D
var left_material: StandardMaterial3D
var right_material: StandardMaterial3D
var joint_material: StandardMaterial3D
var current_outfit_id: String = ""


func _ready() -> void:
	process_priority = 100
	visual = get_parent() as StylizedActorVisual
	if visual != null:
		actor = visual.get_parent() as CharacterBody3D
	_resolve_sources()
	if hide_source_meshes and source_visual_root != null:
		_hide_meshes(source_visual_root)
	_build_wire_visuals()
	set_outfit_id("")
	add_to_group("grace_wire_skeleton")
	call_deferred("sample_now")


func _process(delta: float) -> void:
	sample_now(delta)


func sample_now(delta: float = 0.0) -> void:
	if source_visual_root == null:
		_resolve_sources()
	if not _has_required_sources():
		return
	_update_joint_positions(delta)
	_update_wire_visuals()


func set_outfit_id(outfit_id: String) -> void:
	current_outfit_id = outfit_id
	var palette: Dictionary = _get_palette(outfit_id)
	_set_material_color(center_material, palette.get("center", Color(0.88, 0.9, 1.0)))
	_set_material_color(left_material, palette.get("left", Color(0.28, 0.82, 1.0)))
	_set_material_color(right_material, palette.get("right", Color(1.0, 0.42, 0.78)))
	_set_material_color(joint_material, palette.get("joint", Color(1.0, 0.76, 0.24)))


func get_joint_count() -> int:
	return joint_nodes.size()


func get_segment_count() -> int:
	return bone_nodes.size()


func get_joint_position(joint_id: String) -> Vector3:
	return joint_positions.get(joint_id, Vector3.ZERO)


func get_joint_world_position(joint_id: String) -> Vector3:
	return to_global(get_joint_position(joint_id))


func has_finite_pose() -> bool:
	if joint_positions.size() != JOINT_IDS.size():
		return false
	for joint_id: String in JOINT_IDS:
		var position: Vector3 = joint_positions.get(joint_id, Vector3.ZERO)
		if not position.is_finite():
			return false
	return true


func get_grounding_debug_data() -> Dictionary:
	return {
		"active": _should_apply_grounding(),
		"left_hit": bool(grounding_hits.get("left_ankle", false)) or bool(grounding_hits.get("left_toe", false)),
		"right_hit": bool(grounding_hits.get("right_ankle", false)) or bool(grounding_hits.get("right_toe", false)),
		"left_ankle_offset": snappedf(float(grounding_offsets.get("left_ankle", 0.0)), 0.001),
		"left_toe_offset": snappedf(float(grounding_offsets.get("left_toe", 0.0)), 0.001),
		"right_ankle_offset": snappedf(float(grounding_offsets.get("right_ankle", 0.0)), 0.001),
		"right_toe_offset": snappedf(float(grounding_offsets.get("right_toe", 0.0)), 0.001),
		"contact_clearance": ground_contact_clearance,
	}


func get_debug_data() -> Dictionary:
	return {
		"rig_mode": "wire_skeleton",
		"joint_count": get_joint_count(),
		"segment_count": get_segment_count(),
		"finite_pose": has_finite_pose(),
		"outfit_id": current_outfit_id,
		"state": visual.presentation_state if visual != null else "unknown",
		"grounding": get_grounding_debug_data(),
	}


func _resolve_sources() -> void:
	var root: Node = get_parent()
	if root == null:
		return
	source_visual_root = root.get_node_or_null("VisualRoot") as Node3D
	source_body_root = root.get_node_or_null("VisualRoot/BodyRoot") as Node3D
	source_head_root = root.get_node_or_null("VisualRoot/HeadRoot") as Node3D
	source_left_shoulder = root.get_node_or_null("VisualRoot/LeftShoulderPivot") as Node3D
	source_right_shoulder = root.get_node_or_null("VisualRoot/RightShoulderPivot") as Node3D
	source_left_hand = root.get_node_or_null("VisualRoot/LeftShoulderPivot/LeftHand") as Node3D
	source_right_hand = root.get_node_or_null("VisualRoot/RightShoulderPivot/RightHand") as Node3D
	source_left_leg = root.get_node_or_null("VisualRoot/LeftLegPivot") as Node3D
	source_right_leg = root.get_node_or_null("VisualRoot/RightLegPivot") as Node3D


func _has_required_sources() -> bool:
	return (
		source_visual_root != null
		and source_body_root != null
		and source_head_root != null
		and source_left_shoulder != null
		and source_right_shoulder != null
		and source_left_hand != null
		and source_right_hand != null
		and source_left_leg != null
		and source_right_leg != null
	)


func _build_wire_visuals() -> void:
	center_material = _make_wire_material(Color(0.88, 0.9, 1.0))
	left_material = _make_wire_material(Color(0.28, 0.82, 1.0))
	right_material = _make_wire_material(Color(1.0, 0.42, 0.78))
	joint_material = _make_wire_material(Color(1.0, 0.76, 0.24))

	var joint_mesh: SphereMesh = SphereMesh.new()
	joint_mesh.radius = joint_radius
	joint_mesh.height = joint_radius * 2.0
	joint_mesh.radial_segments = 8
	joint_mesh.rings = 4

	for joint_id: String in JOINT_IDS:
		var joint: MeshInstance3D = MeshInstance3D.new()
		joint.name = "Joint_" + joint_id
		joint.mesh = joint_mesh
		joint.material_override = _get_joint_material(joint_id)
		add_child(joint)
		joint_nodes[joint_id] = joint

	var bone_mesh: CylinderMesh = CylinderMesh.new()
	bone_mesh.top_radius = bone_radius
	bone_mesh.bottom_radius = bone_radius
	bone_mesh.height = 1.0
	bone_mesh.radial_segments = 6

	for raw_pair: Variant in BONE_PAIRS:
		var pair: Array = raw_pair as Array
		var start_id: String = str(pair[0])
		var end_id: String = str(pair[1])
		var bone: MeshInstance3D = MeshInstance3D.new()
		bone.name = "Bone_" + start_id + "_" + end_id
		bone.mesh = bone_mesh
		bone.material_override = _get_bone_material(start_id, end_id)
		add_child(bone)
		bone_nodes[_bone_key(start_id, end_id)] = bone


func _update_joint_positions(delta: float) -> void:
	var left_hip: Vector3 = _node_point(source_left_leg)
	var right_hip: Vector3 = _node_point(source_right_leg)
	var pelvis: Vector3 = (left_hip + right_hip) * 0.5 + Vector3.UP * 0.07

	var left_shoulder: Vector3 = _node_point(source_left_shoulder)
	var right_shoulder: Vector3 = _node_point(source_right_shoulder)
	var chest: Vector3 = (left_shoulder + right_shoulder) * 0.5 + Vector3.DOWN * 0.04
	var spine: Vector3 = _node_point(source_body_root, Vector3(0.0, -0.04, 0.0))
	var neck: Vector3 = _node_point(source_head_root, Vector3(0.0, -0.18, 0.0))
	var head: Vector3 = _node_point(source_head_root, Vector3(0.0, 0.06, 0.0))

	var left_hand: Vector3 = _node_point(source_left_hand)
	var right_hand: Vector3 = _node_point(source_right_hand)
	var left_elbow: Vector3 = _solve_two_bone_joint(
		left_shoulder,
		left_hand,
		upper_arm_length,
		lower_arm_length,
		_get_arm_bend_direction(-1.0)
	)
	var right_elbow: Vector3 = _solve_two_bone_joint(
		right_shoulder,
		right_hand,
		upper_arm_length,
		lower_arm_length,
		_get_arm_bend_direction(1.0)
	)

	var left_ankle: Vector3 = _node_point(source_left_leg, Vector3(0.0, -leg_reach, 0.0))
	var right_ankle: Vector3 = _node_point(source_right_leg, Vector3(0.0, -leg_reach, 0.0))
	var left_toe: Vector3 = _node_point(
		source_left_leg,
		Vector3(0.0, -leg_reach - 0.015, -foot_length)
	)
	var right_toe: Vector3 = _node_point(
		source_right_leg,
		Vector3(0.0, -leg_reach - 0.015, -foot_length)
	)

	left_ankle = _ground_joint(
		"left_ankle",
		left_ankle,
		ground_contact_clearance + ankle_ground_lift,
		delta
	)
	left_toe = _ground_joint("left_toe", left_toe, ground_contact_clearance, delta)
	right_ankle = _ground_joint(
		"right_ankle",
		right_ankle,
		ground_contact_clearance + ankle_ground_lift,
		delta
	)
	right_toe = _ground_joint("right_toe", right_toe, ground_contact_clearance, delta)

	var left_knee: Vector3 = _solve_two_bone_joint(
		left_hip,
		left_ankle,
		upper_leg_length,
		lower_leg_length,
		_get_knee_bend_direction(-1.0)
	)
	var right_knee: Vector3 = _solve_two_bone_joint(
		right_hip,
		right_ankle,
		upper_leg_length,
		lower_leg_length,
		_get_knee_bend_direction(1.0)
	)

	joint_positions = {
		"pelvis": pelvis,
		"spine": spine,
		"chest": chest,
		"neck": neck,
		"head": head,
		"left_shoulder": left_shoulder,
		"left_elbow": left_elbow,
		"left_hand": left_hand,
		"right_shoulder": right_shoulder,
		"right_elbow": right_elbow,
		"right_hand": right_hand,
		"left_hip": left_hip,
		"left_knee": left_knee,
		"left_ankle": left_ankle,
		"left_toe": left_toe,
		"right_hip": right_hip,
		"right_knee": right_knee,
		"right_ankle": right_ankle,
		"right_toe": right_toe,
	}


func _ground_joint(
	joint_id: String,
	local_point: Vector3,
	clearance: float,
	delta: float
) -> Vector3:
	var target_offset: float = 0.0
	var hit_found: bool = false

	if _should_apply_grounding():
		var hit: Dictionary = _probe_ground(local_point)
		if not hit.is_empty():
			var hit_position_value: Variant = hit.get("position", null)
			var hit_normal_value: Variant = hit.get("normal", Vector3.UP)
			if hit_position_value is Vector3 and hit_normal_value is Vector3:
				var hit_position: Vector3 = hit_position_value
				var hit_normal: Vector3 = hit_normal_value
				if hit_normal.normalized().dot(Vector3.UP) >= minimum_ground_normal_dot:
					var ground_local_y: float = to_local(hit_position).y
					var desired_y: float = ground_local_y + clearance
					var raw_offset: float = desired_y - local_point.y
					if raw_offset >= -ground_max_drop and raw_offset <= ground_max_lift:
						target_offset = clampf(raw_offset, -ground_max_drop, ground_max_lift)
						hit_found = true

	var current_offset: float = float(grounding_offsets.get(joint_id, 0.0))
	var blend_weight: float = 1.0
	if delta > 0.0:
		blend_weight = 1.0 - exp(-grounding_response * delta)
	var resolved_offset: float = lerpf(
		current_offset,
		target_offset,
		clampf(blend_weight, 0.0, 1.0)
	)
	if absf(resolved_offset) < 0.0005:
		resolved_offset = 0.0

	grounding_offsets[joint_id] = resolved_offset
	grounding_hits[joint_id] = hit_found
	local_point.y += resolved_offset
	return local_point


func _probe_ground(local_point: Vector3) -> Dictionary:
	if not is_inside_tree():
		return {}
	var world: World3D = get_world_3d()
	if world == null:
		return {}

	var world_point: Vector3 = to_global(local_point)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	query.from = world_point + Vector3.UP * ground_probe_up
	query.to = world_point - Vector3.UP * ground_probe_down
	query.collision_mask = grounding_collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var excluded: Array[RID] = []
	if actor != null:
		excluded.append(actor.get_rid())
	query.exclude = excluded
	return world.direct_space_state.intersect_ray(query)


func _should_apply_grounding() -> bool:
	if visual == null:
		return false
	var state: String = visual.presentation_state
	if not GROUNDED_STATES.has(state):
		return false
	if visual.debug_forced_state != "":
		return true
	return actor != null and actor.is_on_floor()


func _update_wire_visuals() -> void:
	for joint_id: String in JOINT_IDS:
		var joint: MeshInstance3D = joint_nodes.get(joint_id) as MeshInstance3D
		if joint != null:
			joint.position = get_joint_position(joint_id)

	for raw_pair: Variant in BONE_PAIRS:
		var pair: Array = raw_pair as Array
		var start_id: String = str(pair[0])
		var end_id: String = str(pair[1])
		var bone: MeshInstance3D = bone_nodes.get(_bone_key(start_id, end_id)) as MeshInstance3D
		if bone != null:
			_place_bone(bone, get_joint_position(start_id), get_joint_position(end_id))


func _place_bone(bone: MeshInstance3D, start: Vector3, finish: Vector3) -> void:
	var direction: Vector3 = finish - start
	var length: float = direction.length()
	if length <= 0.001:
		bone.visible = false
		return
	bone.visible = true
	var basis: Basis = _basis_with_y_axis(direction / length)
	bone.transform = Transform3D(
		basis.scaled(Vector3(1.0, length, 1.0)),
		(start + finish) * 0.5
	)


func _basis_with_y_axis(y_axis: Vector3) -> Basis:
	var helper: Vector3 = Vector3.FORWARD
	if absf(y_axis.dot(helper)) > 0.94:
		helper = Vector3.RIGHT
	var x_axis: Vector3 = helper.cross(y_axis).normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


func _solve_two_bone_joint(
	start: Vector3,
	finish: Vector3,
	first_length: float,
	second_length: float,
	preferred_bend: Vector3
) -> Vector3:
	var delta: Vector3 = finish - start
	var actual_distance: float = delta.length()
	if actual_distance <= 0.0001:
		return start + preferred_bend.normalized() * first_length

	var direction: Vector3 = delta / actual_distance
	var minimum_distance: float = absf(first_length - second_length) + 0.0001
	var maximum_distance: float = first_length + second_length - 0.0001
	var solved_distance: float = clampf(actual_distance, minimum_distance, maximum_distance)
	var along_distance: float = (
		first_length * first_length
		- second_length * second_length
		+ solved_distance * solved_distance
	) / (2.0 * solved_distance)
	var bend_height: float = sqrt(maxf(first_length * first_length - along_distance * along_distance, 0.0))
	var bend_direction: Vector3 = preferred_bend - direction * preferred_bend.dot(direction)
	if bend_direction.length_squared() <= 0.0001:
		bend_direction = _fallback_perpendicular(direction)
	else:
		bend_direction = bend_direction.normalized()
	return start + direction * along_distance + bend_direction * bend_height


func _fallback_perpendicular(direction: Vector3) -> Vector3:
	var helper: Vector3 = Vector3.UP
	if absf(direction.dot(helper)) > 0.94:
		helper = Vector3.RIGHT
	return (helper - direction * helper.dot(direction)).normalized()


func _get_arm_bend_direction(side: float) -> Vector3:
	var bend: Vector3 = Vector3.FORWARD + Vector3(side * 0.16, 0.0, 0.0)
	var state: String = visual.presentation_state if visual != null else "idle"
	match state:
		"guard":
			bend += Vector3.UP * 0.45
		"cast", "item", "interact":
			bend += Vector3.UP * 0.24
		"climb", "mantle":
			bend += Vector3.UP * 0.34 + Vector3(side * 0.18, 0.0, 0.0)
		"swim_surface", "swim_underwater", "flight":
			bend += Vector3.UP * 0.18
		"hit", "defeated":
			bend += Vector3.BACK * 0.28
		_:
			pass
	return bend.normalized()


func _get_knee_bend_direction(side: float) -> Vector3:
	var bend: Vector3 = Vector3.FORWARD + Vector3(side * 0.05, 0.0, 0.0)
	var state: String = visual.presentation_state if visual != null else "idle"
	match state:
		"riding":
			bend += Vector3(side * 0.52, 0.0, 0.0)
		"dodge", "landing", "jump":
			bend += Vector3.FORWARD * 0.35
		"defeated":
			bend += Vector3.RIGHT * side * 0.45
		_:
			pass
	return bend.normalized()


func _node_point(node: Node3D, local_offset: Vector3 = Vector3.ZERO) -> Vector3:
	if node == null:
		return Vector3.ZERO
	return to_local(node.to_global(local_offset))


func _bone_key(start_id: String, end_id: String) -> String:
	return start_id + "->" + end_id


func _get_joint_material(joint_id: String) -> Material:
	if joint_id.begins_with("left_"):
		return left_material
	if joint_id.begins_with("right_"):
		return right_material
	return joint_material


func _get_bone_material(start_id: String, end_id: String) -> Material:
	if start_id.begins_with("left_") or end_id.begins_with("left_"):
		return left_material
	if start_id.begins_with("right_") or end_id.begins_with("right_"):
		return right_material
	return center_material


func _make_wire_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.35
	return material


func _set_material_color(material: StandardMaterial3D, color: Color) -> void:
	if material == null:
		return
	material.albedo_color = color
	material.emission = color


func _get_palette(outfit_id: String) -> Dictionary:
	match outfit_id:
		"travelers_coat":
			return {
				"center": Color(0.48, 0.92, 0.82),
				"left": Color(0.2, 0.75, 0.68),
				"right": Color(0.78, 0.58, 0.26),
				"joint": Color(0.95, 0.72, 0.28),
			}
		"apprentice_robe":
			return {
				"center": Color(0.78, 0.62, 1.0),
				"left": Color(0.28, 0.84, 1.0),
				"right": Color(0.74, 0.42, 1.0),
				"joint": Color(1.0, 0.78, 0.25),
			}
		"ironweave_jacket":
			return {
				"center": Color(0.72, 0.8, 0.88),
				"left": Color(0.42, 0.64, 0.82),
				"right": Color(0.9, 0.3, 0.38),
				"joint": Color(0.92, 0.94, 1.0),
			}
		_:
			return {
				"center": Color(0.88, 0.9, 1.0),
				"left": Color(0.28, 0.82, 1.0),
				"right": Color(1.0, 0.42, 0.78),
				"joint": Color(1.0, 0.76, 0.24),
			}


func _hide_meshes(node: Node) -> void:
	for child: Node in node.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
		_hide_meshes(child)
