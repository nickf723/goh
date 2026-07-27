extends RefCounted
class_name AuthoredSetComposer

const ModularCatalog = preload("res://scripts/environment/modular_environment_catalog.gd")

const TRAVERSAL_LAND := "land"
const TRAVERSAL_SWIM := "swim"
const TRAVERSAL_CAMERA := "camera"

const RECOMMENDED_CLEARANCE: Dictionary = {
	TRAVERSAL_LAND: Vector2(4.0, 3.8),
	TRAVERSAL_SWIM: Vector2(5.5, 5.0),
	TRAVERSAL_CAMERA: Vector2(6.0, 5.0),
}

var builder: AuthoredEnvironmentBuilder
var build_counts: Dictionary = {
	"corridors": 0,
	"walls": 0,
	"stairs": 0,
	"modules": 0,
	"static_boxes": 0,
	"visual_boxes": 0,
}


func _init(environment_builder: AuthoredEnvironmentBuilder) -> void:
	builder = environment_builder


func compose_plan(parent: Node3D, plan: Dictionary) -> Dictionary:
	var corridors: Array[Node3D] = []
	var walls: Array[Node3D] = []
	var stairs: Array[Node3D] = []
	var modules: Array[Node3D] = []
	var static_boxes: Array[StaticBody3D] = []
	var visual_boxes: Array[MeshInstance3D] = []

	for row: Dictionary in _dictionary_rows(plan.get("corridors", [])):
		var corridor: Node3D = add_corridor(parent, row)
		if corridor != null:
			corridors.append(corridor)

	for row: Dictionary in _dictionary_rows(plan.get("walls", [])):
		var wall: Node3D = add_wall_with_openings(parent, row)
		if wall != null:
			walls.append(wall)

	for row: Dictionary in _dictionary_rows(plan.get("stairs", [])):
		var stair: Node3D = add_walkable_stair_run(parent, row)
		if stair != null:
			stairs.append(stair)

	for row: Dictionary in _dictionary_rows(plan.get("modules", [])):
		var module: Node3D = add_module(parent, row)
		if module != null:
			modules.append(module)

	for row: Dictionary in _dictionary_rows(plan.get("static_boxes", [])):
		var body: StaticBody3D = add_static_box(parent, row)
		if body != null:
			static_boxes.append(body)

	for row: Dictionary in _dictionary_rows(plan.get("visual_boxes", [])):
		var visual: MeshInstance3D = add_visual_box(parent, row)
		if visual != null:
			visual_boxes.append(visual)

	return {
		"layout_id": str(plan.get("layout_id", "unnamed_set")),
		"corridors": corridors,
		"walls": walls,
		"stairs": stairs,
		"modules": modules,
		"static_boxes": static_boxes,
		"visual_boxes": visual_boxes,
		"counts": get_build_counts(),
	}


func add_corridor(parent: Node3D, spec: Dictionary) -> Node3D:
	if builder == null or parent == null:
		return null
	var traversal: String = str(spec.get("traversal", TRAVERSAL_LAND)).to_lower().strip_edges()
	var recommendation: Vector2 = get_recommended_clearance(traversal)
	var enforce_minimum: bool = bool(spec.get("enforce_minimum", true))
	var clear_width: float = maxf(float(spec.get("clear_width", recommendation.x)), 0.5)
	var clear_height: float = maxf(float(spec.get("clear_height", recommendation.y)), 0.5)
	if enforce_minimum:
		clear_width = maxf(clear_width, recommendation.x)
		clear_height = maxf(clear_height, recommendation.y)

	var node_name: String = str(spec.get("id", spec.get("name", "ComposedCorridor")))
	var floor_center: Vector3 = vector3_from(spec.get("floor_center", Vector3.ZERO), Vector3.ZERO)
	var forward: Vector3 = vector3_from(spec.get("forward", Vector3.FORWARD), Vector3.FORWARD)
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var yaw: float = atan2(forward.x, forward.z)
	var length: float = maxf(float(spec.get("length", 4.0)), 0.5)
	var floor_thickness: float = maxf(float(spec.get("floor_thickness", 0.5)), 0.05)
	var wall_thickness: float = maxf(float(spec.get("wall_thickness", 0.5)), 0.05)
	var ceiling_thickness: float = maxf(float(spec.get("ceiling_thickness", 0.5)), 0.05)
	var include_ceiling: bool = bool(spec.get("include_ceiling", true))
	var material_key: Variant = spec.get("material", "stone_dark")
	var climbable_walls: bool = bool(spec.get("climbable_walls", false))

	var root: Node3D = builder.add_root(parent, node_name, floor_center, Vector3(0.0, yaw, 0.0))
	root.add_to_group("authored_set_corridor")
	root.set_meta("composer_kind", "corridor")
	root.set_meta("traversal", traversal)
	root.set_meta("clear_width", clear_width)
	root.set_meta("clear_height", clear_height)
	root.set_meta("length", length)
	root.set_meta("recommended_width", recommendation.x)
	root.set_meta("recommended_height", recommendation.y)
	root.set_meta("enforced_minimum", enforce_minimum)

	builder.add_static_box(
		root,
		"Floor",
		Vector3(clear_width + wall_thickness * 2.0, floor_thickness, length),
		Vector3(0.0, -floor_thickness * 0.5, 0.0),
		material_key,
		Vector3.ZERO,
		false,
		true,
		"set_corridor_floor"
	)
	for side: float in [-1.0, 1.0]:
		builder.add_static_box(
			root,
			"WallLeft" if side < 0.0 else "WallRight",
			Vector3(wall_thickness, clear_height, length),
			Vector3(side * (clear_width * 0.5 + wall_thickness * 0.5), clear_height * 0.5, 0.0),
			material_key,
			Vector3.ZERO,
			climbable_walls,
			true,
			"set_corridor_wall"
		)
	if include_ceiling:
		builder.add_static_box(
			root,
			"Ceiling",
			Vector3(clear_width + wall_thickness * 2.0, ceiling_thickness, length),
			Vector3(0.0, clear_height + ceiling_thickness * 0.5, 0.0),
			material_key,
			Vector3.ZERO,
			false,
			true,
			"set_corridor_ceiling"
		)
	build_counts["corridors"] = int(build_counts["corridors"]) + 1
	return root


func add_wall_with_openings(parent: Node3D, spec: Dictionary) -> Node3D:
	if builder == null or parent == null:
		return null
	var node_name: String = str(spec.get("id", spec.get("name", "ComposedWall")))
	var base_center: Vector3 = vector3_from(spec.get("base_center", Vector3.ZERO), Vector3.ZERO)
	var normal: Vector3 = vector3_from(spec.get("normal", Vector3.BACK), Vector3.BACK)
	normal.y = 0.0
	if normal.length_squared() <= 0.001:
		normal = Vector3.BACK
	normal = normal.normalized()
	var yaw: float = atan2(normal.x, normal.z)
	var wall_length: float = maxf(float(spec.get("length", 8.0)), 0.5)
	var wall_height: float = maxf(float(spec.get("height", 4.0)), 0.5)
	var wall_depth: float = maxf(float(spec.get("depth", 0.5)), 0.05)
	var material_key: Variant = spec.get("material", "stone_primary")
	var openings: Array[Dictionary] = _sorted_openings(spec.get("openings", []))
	var root: Node3D = builder.add_root(parent, node_name, base_center, Vector3(0.0, yaw, 0.0))
	root.add_to_group("authored_set_wall")
	root.set_meta("composer_kind", "wall")
	root.set_meta("wall_length", wall_length)
	root.set_meta("wall_height", wall_height)
	root.set_meta("openings", openings.duplicate(true))

	var cursor: float = -wall_length * 0.5
	var segment_index: int = 0
	for opening: Dictionary in openings:
		var opening_width: float = clampf(float(opening.get("width", 2.0)), 0.1, wall_length)
		var opening_height: float = clampf(float(opening.get("height", wall_height)), 0.1, wall_height)
		var opening_center: float = clampf(float(opening.get("center_offset", 0.0)), -wall_length * 0.5, wall_length * 0.5)
		var opening_start: float = clampf(opening_center - opening_width * 0.5, -wall_length * 0.5, wall_length * 0.5)
		var opening_end: float = clampf(opening_center + opening_width * 0.5, -wall_length * 0.5, wall_length * 0.5)
		if opening_start > cursor + 0.01:
			_add_wall_segment(root, segment_index, cursor, opening_start, wall_height, wall_depth, material_key)
			segment_index += 1
		if opening_height < wall_height - 0.01 and opening_end > opening_start:
			var lintel_height: float = wall_height - opening_height
			builder.add_static_box(
				root,
				"Lintel%02d" % segment_index,
				Vector3(opening_end - opening_start, lintel_height, wall_depth),
				Vector3((opening_start + opening_end) * 0.5, opening_height + lintel_height * 0.5, 0.0),
				material_key,
				Vector3.ZERO,
				false,
				true,
				"set_opening_lintel"
			)
			segment_index += 1
		cursor = maxf(cursor, opening_end)
	if cursor < wall_length * 0.5 - 0.01:
		_add_wall_segment(root, segment_index, cursor, wall_length * 0.5, wall_height, wall_depth, material_key)

	build_counts["walls"] = int(build_counts["walls"]) + 1
	return root


func add_walkable_stair_run(parent: Node3D, spec: Dictionary) -> Node3D:
	if builder == null or parent == null:
		return null
	var node_name: String = str(spec.get("id", spec.get("name", "ComposedStairs")))
	var low_origin: Vector3 = vector3_from(spec.get("low_origin", Vector3.ZERO), Vector3.ZERO)
	var forward: Vector3 = vector3_from(spec.get("forward", Vector3.FORWARD), Vector3.FORWARD)
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var yaw: float = atan2(forward.x, forward.z)
	var step_count: int = maxi(int(spec.get("step_count", 6)), 1)
	var width: float = maxf(float(spec.get("width", 4.0)), 1.0)
	var step_run: float = maxf(float(spec.get("step_run", 0.55)), 0.15)
	var total_rise: float = maxf(float(spec.get("total_rise", 1.5)), 0.08)
	var landing_length: float = maxf(float(spec.get("landing_length", step_run)), 0.0)
	var ramp_thickness: float = maxf(float(spec.get("ramp_thickness", 0.14)), 0.05)
	var material_key: Variant = spec.get("material", "stone_wet")
	var root: Node3D = builder.add_root(parent, node_name, low_origin, Vector3(0.0, yaw, 0.0))
	root.add_to_group("authored_set_stair")
	root.set_meta("composer_kind", "stairs")
	root.set_meta("step_count", step_count)
	root.set_meta("width", width)
	root.set_meta("total_rise", total_rise)
	root.set_meta("total_run", step_run * float(step_count))

	for index: int in range(step_count):
		var progress: float = float(index + 1) / float(step_count)
		var height: float = total_rise * progress
		builder.add_visual_box(
			root,
			"Step%02d" % index,
			Vector3(width, height, step_run + 0.035),
			Vector3(0.0, height * 0.5, step_run * (float(index) + 0.5)),
			material_key,
			Vector3.ZERO,
			1.0,
			0.0,
			"set_stair_visual"
		)

	var total_run: float = step_run * float(step_count)
	var ramp_angle: float = atan2(total_rise, total_run)
	var ramp_length: float = sqrt(total_run * total_run + total_rise * total_rise)
	var ramp_center_y: float = total_rise * 0.5 - cos(ramp_angle) * ramp_thickness * 0.5
	var ramp_center_z: float = total_run * 0.5 + sin(ramp_angle) * ramp_thickness * 0.5
	var ramp: StaticBody3D = builder.add_static_box(
		root,
		"WalkRamp",
		Vector3(width - 0.12, ramp_thickness, ramp_length),
		Vector3(0.0, ramp_center_y, ramp_center_z),
		material_key,
		Vector3(-ramp_angle, 0.0, 0.0),
		false,
		false,
		"set_stair_ramp"
	)
	ramp.set_meta("walkable_ramp", true)

	if landing_length > 0.0:
		var landing: StaticBody3D = builder.add_static_box(
			root,
			"TopLanding",
			Vector3(width - 0.12, ramp_thickness, landing_length),
			Vector3(0.0, total_rise - ramp_thickness * 0.5, total_run + landing_length * 0.5),
			material_key,
			Vector3.ZERO,
			false,
			false,
			"set_stair_landing"
		)
		landing.set_meta("walkable_landing", true)
		builder.add_visual_box(
			root,
			"LandingVisual",
			Vector3(width, ramp_thickness, landing_length),
			Vector3(0.0, total_rise - ramp_thickness * 0.5, total_run + landing_length * 0.5),
			material_key,
			Vector3.ZERO,
			1.0,
			0.0,
			"set_stair_visual"
		)

	build_counts["stairs"] = int(build_counts["stairs"]) + 1
	return root


func add_module(parent: Node3D, spec: Dictionary) -> Node3D:
	if parent == null:
		return null
	var piece_id: String = str(spec.get("piece_id", ""))
	var piece: Node3D = ModularCatalog.instantiate_piece(piece_id)
	if piece == null:
		push_warning("Unknown modular set piece: " + piece_id)
		return null
	piece.name = str(spec.get("id", spec.get("name", piece_id)))
	piece.position = vector3_from(spec.get("position", Vector3.ZERO), Vector3.ZERO)
	piece.rotation = vector3_from(spec.get("rotation", Vector3.ZERO), Vector3.ZERO)
	piece.scale = vector3_from(spec.get("scale", Vector3.ONE), Vector3.ONE)
	var variant_seed: int = int(spec.get("variant_seed", -1))
	if variant_seed >= 0 and _has_property(piece, "variant_seed"):
		piece.set("variant_seed", variant_seed)
	parent.add_child(piece)
	var collision_mode: String = str(spec.get("collision_mode", "own")).to_lower().strip_edges()
	if collision_mode in ["none", "support_shell"]:
		_set_collision_enabled(piece, false)
	piece.set_meta("composer_kind", "module")
	piece.set_meta("collision_mode", collision_mode)
	piece.set_meta("layout_piece_id", piece_id)
	build_counts["modules"] = int(build_counts["modules"]) + 1
	return piece


func add_static_box(parent: Node3D, spec: Dictionary) -> StaticBody3D:
	if builder == null or parent == null:
		return null
	var body: StaticBody3D = builder.add_static_box(
		parent,
		str(spec.get("id", spec.get("name", "ComposedBox"))),
		vector3_from(spec.get("size", Vector3.ONE), Vector3.ONE),
		vector3_from(spec.get("position", Vector3.ZERO), Vector3.ZERO),
		spec.get("material", "stone_primary"),
		vector3_from(spec.get("rotation", Vector3.ZERO), Vector3.ZERO),
		bool(spec.get("climbable", false)),
		bool(spec.get("visible", true)),
		str(spec.get("role", "set_box"))
	)
	body.set_meta("composer_kind", "static_box")
	build_counts["static_boxes"] = int(build_counts["static_boxes"]) + 1
	return body


func add_visual_box(parent: Node3D, spec: Dictionary) -> MeshInstance3D:
	if builder == null or parent == null:
		return null
	var visual: MeshInstance3D = builder.add_visual_box(
		parent,
		str(spec.get("id", spec.get("name", "ComposedVisual"))),
		vector3_from(spec.get("size", Vector3.ONE), Vector3.ONE),
		vector3_from(spec.get("position", Vector3.ZERO), Vector3.ZERO),
		spec.get("material", "stone_primary"),
		vector3_from(spec.get("rotation", Vector3.ZERO), Vector3.ZERO),
		float(spec.get("alpha", 1.0)),
		float(spec.get("emission", 0.0)),
		str(spec.get("role", "set_visual"))
	)
	visual.set_meta("composer_kind", "visual_box")
	build_counts["visual_boxes"] = int(build_counts["visual_boxes"]) + 1
	return visual


func get_build_counts() -> Dictionary:
	return build_counts.duplicate(true)


static func get_recommended_clearance(traversal: String) -> Vector2:
	var normalized: String = traversal.to_lower().strip_edges()
	if RECOMMENDED_CLEARANCE.has(normalized):
		return RECOMMENDED_CLEARANCE[normalized] as Vector2
	return RECOMMENDED_CLEARANCE[TRAVERSAL_LAND] as Vector2


static func vector3_from(value: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if value is Vector3:
		return value as Vector3
	if value is Array:
		var values: Array = value as Array
		if values.size() >= 3:
			return Vector3(float(values[0]), float(values[1]), float(values[2]))
	if value is Dictionary:
		var values_dict: Dictionary = value as Dictionary
		return Vector3(
			float(values_dict.get("x", fallback.x)),
			float(values_dict.get("y", fallback.y)),
			float(values_dict.get("z", fallback.z))
		)
	return fallback


func _add_wall_segment(
	root: Node3D,
	segment_index: int,
	start_x: float,
	end_x: float,
	wall_height: float,
	wall_depth: float,
	material_key: Variant
) -> void:
	var width: float = end_x - start_x
	if width <= 0.01:
		return
	builder.add_static_box(
		root,
		"Segment%02d" % segment_index,
		Vector3(width, wall_height, wall_depth),
		Vector3((start_x + end_x) * 0.5, wall_height * 0.5, 0.0),
		material_key,
		Vector3.ZERO,
		false,
		true,
		"set_wall_segment"
	)


func _dictionary_rows(value: Variant) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not value is Array:
		return rows
	for row_variant: Variant in value as Array:
		if row_variant is Dictionary:
			rows.append((row_variant as Dictionary).duplicate(true))
	return rows


func _sorted_openings(value: Variant) -> Array[Dictionary]:
	var sorted: Array[Dictionary] = []
	for opening: Dictionary in _dictionary_rows(value):
		var insertion_index: int = sorted.size()
		for index: int in range(sorted.size()):
			if float(opening.get("center_offset", 0.0)) < float(sorted[index].get("center_offset", 0.0)):
				insertion_index = index
				break
		sorted.insert(insertion_index, opening)
	return sorted


func _set_collision_enabled(node: Node, enabled: bool) -> void:
	if node is CollisionObject3D:
		var collision_object: CollisionObject3D = node as CollisionObject3D
		collision_object.collision_layer = 1 if enabled else 0
		collision_object.collision_mask = 1 if enabled else 0
	if node is CollisionShape3D:
		(node as CollisionShape3D).set_deferred("disabled", not enabled)
	for child: Node in node.get_children():
		_set_collision_enabled(child, enabled)


func _has_property(object: Object, property_name: String) -> bool:
	for property_variant: Variant in object.get_property_list():
		if not property_variant is Dictionary:
			continue
		var property_data: Dictionary = property_variant as Dictionary
		if str(property_data.get("name", "")) == property_name:
			return true
	return false
