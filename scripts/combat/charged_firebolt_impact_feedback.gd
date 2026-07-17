extends Node
class_name ChargedFireboltImpactFeedback

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")

const FIRE_COLOR: Color = Color(1.0, 0.28, 0.06, 1.0)
const GOLD_COLOR: Color = Color(1.0, 0.78, 0.18, 1.0)
const HOT_CENTER_COLOR: Color = Color(1.0, 0.92, 0.42, 1.0)

const IMPACT_HITSTOP_DURATION: float = 0.075
const IMPACT_HITSTOP_TIME_SCALE: float = 0.10
const CAMERA_NUDGE_DURATION: float = 0.12
const CAMERA_NUDGE_SIDE_AMOUNT: float = 0.075
const CAMERA_NUDGE_VERTICAL_AMOUNT: float = 0.065


static func play_if_charged_firebolt(
	projectile: Node,
	target: Node,
	payload: DamagePayload,
	impact_position: Vector3,
	impact_direction: Vector3
) -> bool:
	if not is_charged_firebolt_payload(payload):
		return false

	if projectile == null or projectile.get_tree() == null:
		return false

	var tree: SceneTree = projectile.get_tree()
	spawn_charged_burst(tree, impact_position, impact_direction)
	spawn_target_flash(tree, target, impact_position)
	spawn_ember_mark(tree, impact_position)
	request_hitstop()
	nudge_camera(projectile, impact_direction)
	return true


static func is_charged_firebolt_payload(payload: DamagePayload) -> bool:
	if payload == null:
		return false

	var source_name: String = payload.source_name.to_lower()
	if source_name.contains("charged firebolt"):
		return true

	if payload.element.to_lower() != "fire":
		return false

	var has_charged_tag: bool = false
	var has_firebolt_tag: bool = false

	for tag_variant: Variant in payload.tags:
		var tag: String = str(tag_variant).to_lower()
		if tag == "charged" or tag == "heavy_impact":
			has_charged_tag = true
		if tag == "firebolt":
			has_firebolt_tag = true

	return has_charged_tag and has_firebolt_tag


static func spawn_charged_burst(tree: SceneTree, position: Vector3, impact_direction: Vector3) -> void:
	if tree == null or tree.current_scene == null:
		return

	ElementVisuals.spawn_impact(tree, position, "fire", 1.32)

	var burst: Node3D = Node3D.new()
	burst.name = "ChargedFireboltImpact"
	burst.global_position = position
	if impact_direction.length() > 0.01:
		burst.look_at(position + impact_direction.normalized(), Vector3.UP)
	tree.current_scene.add_child(burst)

	add_sphere(burst, "WhiteHotCore", 0.22, HOT_CENTER_COLOR, Vector3.ZERO, Vector3.ONE, 5.0, 0.72)
	add_torus(burst, "GoldShockRing", 0.34, 0.45, GOLD_COLOR, Vector3.ZERO, Vector3(90.0, 0.0, 0.0), 4.2, 0.84)
	add_torus(burst, "FireShockRing", 0.24, 0.36, FIRE_COLOR, Vector3.ZERO, Vector3(0.0, 0.0, 90.0), 3.0, 0.62)

	for index: int in range(8):
		var angle: float = TAU * float(index) / 8.0
		var shard_position: Vector3 = Vector3(cos(angle), 0.05 + float(index % 2) * 0.09, sin(angle)) * 0.32
		add_box(
			burst,
			"ChargedShard" + str(index),
			Vector3(0.06, 0.06, 0.34),
			GOLD_COLOR if index % 2 == 0 else FIRE_COLOR,
			shard_position,
			Vector3(0.0, rad_to_deg(angle), 42.0),
			2.9,
			0.74
		)

	add_light(burst, HOT_CENTER_COLOR, 3.8, 5.0)

	burst.scale = Vector3.ONE * 0.18
	var tween: Tween = burst.create_tween()
	tween.set_parallel(true)
	tween.tween_property(burst, "scale", Vector3.ONE * 1.58, 0.22)
	tween.tween_property(burst, "rotation:y", burst.rotation.y + 1.1, 0.22)
	tween.set_parallel(false)
	tween.tween_callback(Callable(burst, "queue_free"))


static func spawn_target_flash(tree: SceneTree, target: Node, fallback_position: Vector3) -> void:
	if tree == null or tree.current_scene == null:
		return

	var flash: MeshInstance3D = MeshInstance3D.new()
	flash.name = "ChargedFireboltTargetFlash"
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.34
	mesh.height = 0.68
	flash.mesh = mesh

	var material: StandardMaterial3D = make_material(GOLD_COLOR, 3.4, 0.44)
	flash.material_override = material
	tree.current_scene.add_child(flash)
	flash.global_position = get_target_flash_position(target, fallback_position)
	flash.scale = Vector3.ONE * 0.28

	var tween: Tween = flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * 1.45, 0.18)
	tween.tween_property(material, "albedo_color", Color(GOLD_COLOR.r, GOLD_COLOR.g, GOLD_COLOR.b, 0.0), 0.18)
	tween.set_parallel(false)
	tween.tween_callback(Callable(flash, "queue_free"))


static func spawn_ember_mark(tree: SceneTree, impact_position: Vector3) -> void:
	if tree == null or tree.current_scene == null:
		return

	var mark: MeshInstance3D = MeshInstance3D.new()
	mark.name = "ChargedFireboltEmberMark"
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.32
	mesh.bottom_radius = 0.32
	mesh.height = 0.018
	mesh.radial_segments = 24
	mark.mesh = mesh

	var material: StandardMaterial3D = make_material(FIRE_COLOR, 1.5, 0.30)
	mark.material_override = material
	tree.current_scene.add_child(mark)
	mark.global_position = impact_position + Vector3(0.0, -0.22, 0.0)
	mark.scale = Vector3.ONE * 0.28

	var tween: Tween = mark.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mark, "scale", Vector3.ONE * 0.9, 0.55)
	tween.tween_property(material, "albedo_color", Color(FIRE_COLOR.r, FIRE_COLOR.g, FIRE_COLOR.b, 0.0), 0.95)
	tween.set_parallel(false)
	tween.tween_callback(Callable(mark, "queue_free"))


static func request_hitstop() -> void:
	HitStop.request(IMPACT_HITSTOP_DURATION, IMPACT_HITSTOP_TIME_SCALE)


static func nudge_camera(source: Node, impact_direction: Vector3) -> void:
	if source == null or source.get_viewport() == null:
		return

	var camera: Camera3D = source.get_viewport().get_camera_3d()
	if camera == null:
		return

	var nudge_direction: Vector3 = impact_direction.normalized() if impact_direction.length() > 0.01 else Vector3.FORWARD
	var camera_right: Vector3 = camera.global_transform.basis.x.normalized()
	var side_amount: float = clamp(camera_right.dot(nudge_direction), -1.0, 1.0) * CAMERA_NUDGE_SIDE_AMOUNT
	var original_h_offset: float = camera.h_offset
	var original_v_offset: float = camera.v_offset

	camera.h_offset = original_h_offset + side_amount
	camera.v_offset = original_v_offset - CAMERA_NUDGE_VERTICAL_AMOUNT

	var tween: Tween = camera.create_tween()
	tween.set_parallel(true)
	tween.tween_property(camera, "h_offset", original_h_offset, CAMERA_NUDGE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "v_offset", original_v_offset, CAMERA_NUDGE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


static func get_target_flash_position(target: Node, fallback_position: Vector3) -> Vector3:
	var target_3d: Node3D = get_target_node_3d(target)
	if target_3d == null:
		return fallback_position + Vector3.UP * 0.35

	return target_3d.global_position + Vector3.UP * max(estimate_target_height(target) * 0.55, 0.65)


static func get_target_node_3d(target: Node) -> Node3D:
	if target == null:
		return null

	if target is Node3D:
		return target as Node3D

	var parent: Node = target.get_parent()
	if parent is Node3D:
		return parent as Node3D

	return null


static func estimate_target_height(target: Node) -> float:
	var height: float = estimate_height_from_collision_shapes(target)
	if height > 0.01:
		return height

	return 1.8


static func estimate_height_from_collision_shapes(root: Node) -> float:
	if root == null:
		return 0.0

	var height: float = 0.0
	if root is CollisionShape3D:
		height = max(height, get_shape_height((root as CollisionShape3D).shape))

	for child: Node in root.get_children():
		height = max(height, estimate_height_from_collision_shapes(child))

	return height


static func get_shape_height(shape: Shape3D) -> float:
	if shape == null:
		return 0.0

	if shape is CapsuleShape3D:
		return (shape as CapsuleShape3D).height
	if shape is BoxShape3D:
		return (shape as BoxShape3D).size.y
	if shape is SphereShape3D:
		return (shape as SphereShape3D).radius * 2.0
	if shape is CylinderShape3D:
		return (shape as CylinderShape3D).height

	return 0.0


static func make_material(color: Color, emission_energy: float, alpha: float = 1.0) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.emission_enabled = emission_energy > 0.0
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = emission_energy
	material.roughness = 0.24
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


static func add_sphere(
	root: Node3D,
	name: String,
	radius: float,
	color: Color,
	position: Vector3,
	scale: Vector3,
	emission_energy: float,
	alpha: float = 1.0
) -> MeshInstance3D:
	var sphere: MeshInstance3D = MeshInstance3D.new()
	sphere.name = name
	sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	sphere.mesh = mesh
	sphere.material_override = make_material(color, emission_energy, alpha)
	root.add_child(sphere)
	sphere.position = position
	sphere.scale = scale
	return sphere


static func add_torus(
	root: Node3D,
	name: String,
	inner_radius: float,
	outer_radius: float,
	color: Color,
	position: Vector3,
	rotation_degrees_value: Vector3,
	emission_energy: float,
	alpha: float = 1.0
) -> MeshInstance3D:
	var torus: MeshInstance3D = MeshInstance3D.new()
	torus.name = name
	torus.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.ring_segments = 32
	mesh.radial_segments = 8
	torus.mesh = mesh
	torus.material_override = make_material(color, emission_energy, alpha)
	root.add_child(torus)
	torus.position = position
	torus.rotation_degrees = rotation_degrees_value
	return torus


static func add_box(
	root: Node3D,
	name: String,
	size: Vector3,
	color: Color,
	position: Vector3,
	rotation_degrees_value: Vector3,
	emission_energy: float,
	alpha: float = 1.0
) -> MeshInstance3D:
	var box: MeshInstance3D = MeshInstance3D.new()
	box.name = name
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	box.mesh = mesh
	box.material_override = make_material(color, emission_energy, alpha)
	root.add_child(box)
	box.position = position
	box.rotation_degrees = rotation_degrees_value
	return box


static func add_light(root: Node3D, color: Color, energy: float, range_value: float) -> OmniLight3D:
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "ChargedImpactLight"
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	root.add_child(light)
	return light
