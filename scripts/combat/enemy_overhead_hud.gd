extends Node3D
class_name EnemyOverheadHud

const PENDING_HUD_META: String = "_pending_enemy_overhead_hud"

const BACK_COLOR: Color = Color(0.02, 0.025, 0.035, 0.82)
const HEALTH_GOOD_COLOR: Color = Color(0.2, 1.0, 0.32, 0.96)
const HEALTH_LOW_COLOR: Color = Color(1.0, 0.18, 0.12, 0.96)
const HEALTH_MID_COLOR: Color = Color(1.0, 0.72, 0.18, 0.96)
const STANCE_COLOR: Color = Color(0.42, 0.72, 1.0, 0.9)
const STANCE_BACK_COLOR: Color = Color(0.02, 0.04, 0.08, 0.72)

const STATUS_TAG_NAMES: Array[String] = [
	"burning",
	"poisoned",
	"frozen",
	"chill",
	"stunned",
	"wet",
	"staggered",
	"oily",
]

@export var vertical_padding: float = 0.52
@export var fallback_target_height: float = 1.8
@export var bar_width: float = 1.45
@export var health_bar_height: float = 0.12
@export var stance_bar_height: float = 0.055
@export var icon_spacing: float = 0.24
@export var icon_y_offset: float = -0.28
@export var billboard_smoothness: float = 16.0
@export_group("Debug")
@export var show_personality_debug: bool = true
@export var debug_text_y_offset: float = 0.34
@export var debug_font_size: int = 32
@export var debug_pixel_size: float = 0.007

var target_node: Node3D = null
var hit_receiver: Node = null
var status_receiver: Node = null
var tag_component: Node = null
var brain: Node = null

var health_back: MeshInstance3D = null
var health_fill: MeshInstance3D = null
var stance_back: MeshInstance3D = null
var stance_fill: MeshInstance3D = null
var icon_container: Node3D = null
var status_icon_labels: Array[Label3D] = []
var last_status_signature: String = ""
var debug_label: Label3D = null
var last_debug_text: String = ""


static func ensure_for_target(target: Node) -> EnemyOverheadHud:
	var target_3d: Node3D = get_target_node_3d(target)

	if target_3d == null:
		return null

	if not should_show_for_target(target_3d):
		return null

	var existing: Node = target_3d.get_node_or_null("EnemyOverheadHud")

	if existing is EnemyOverheadHud:
		var existing_hud: EnemyOverheadHud = existing as EnemyOverheadHud
		existing_hud.bind_target(target_3d)
		existing_hud.refresh_now()
		return existing_hud

	if target_3d.has_meta(PENDING_HUD_META):
		var pending_value: Variant = target_3d.get_meta(PENDING_HUD_META)
		if pending_value is EnemyOverheadHud and is_instance_valid(pending_value):
			var pending_hud: EnemyOverheadHud = pending_value as EnemyOverheadHud
			pending_hud.bind_target(target_3d)
			return pending_hud
		target_3d.remove_meta(PENDING_HUD_META)

	var hud: EnemyOverheadHud = EnemyOverheadHud.new()
	hud.name = "EnemyOverheadHud"
	hud.bind_target(target_3d)
	target_3d.set_meta(PENDING_HUD_META, hud)
	target_3d.add_child.call_deferred(hud)
	return hud


static func get_target_node_3d(target: Node) -> Node3D:
	if target == null:
		return null

	if target is Node3D:
		return target as Node3D

	var parent: Node = target.get_parent()

	if parent is Node3D:
		return parent as Node3D

	return null


static func should_show_for_target(target_3d: Node3D) -> bool:
	if target_3d == null:
		return false

	if target_3d.is_in_group("enemy"):
		return true

	if target_3d.get_node_or_null("EnemyBrain") != null:
		return true

	var lower_name: String = target_3d.name.to_lower()
	return lower_name.contains("dummy") or lower_name.contains("goblin") or lower_name.contains("gremlin") or lower_name.contains("zombie")


func _ready() -> void:
	top_level = true
	create_bar_nodes()
	refresh_now()


func bind_target(new_target: Node3D) -> void:
	target_node = new_target
	refresh_component_refs()
	refresh_now()


func refresh_component_refs() -> void:
	if target_node == null or not is_instance_valid(target_node):
		hit_receiver = null
		status_receiver = null
		tag_component = null
		brain = null
		return

	hit_receiver = target_node.get_node_or_null("HitReceiver")
	status_receiver = target_node.get_node_or_null("StatusReceiver")
	tag_component = target_node.get_node_or_null("TagComponent")
	brain = target_node.get_node_or_null("EnemyBrain")


func _process(delta: float) -> void:
	if target_node == null or not is_instance_valid(target_node):
		queue_free()
		return

	if hit_receiver == null or not is_instance_valid(hit_receiver):
		refresh_component_refs()

	if status_receiver == null or not is_instance_valid(status_receiver):
		refresh_component_refs()

	if tag_component == null or not is_instance_valid(tag_component):
		refresh_component_refs()

	if is_target_defeated():
		visible = false
		return

	visible = true
	update_world_position()
	face_camera(delta)
	refresh_now()


func create_bar_nodes() -> void:
	if health_back != null:
		return

	health_back = create_quad("HealthBack", bar_width, health_bar_height, BACK_COLOR)
	health_fill = create_quad("HealthFill", bar_width, health_bar_height, HEALTH_GOOD_COLOR)
	stance_back = create_quad("StanceBack", bar_width, stance_bar_height, STANCE_BACK_COLOR)
	stance_fill = create_quad("StanceFill", bar_width, stance_bar_height, STANCE_COLOR)

	health_back.position = Vector3(0.0, 0.0, 0.0)
	health_fill.position = Vector3(0.0, 0.0, 0.012)
	stance_back.position = Vector3(0.0, -0.105, 0.0)
	stance_fill.position = Vector3(0.0, -0.105, 0.014)

	icon_container = Node3D.new()
	icon_container.name = "StatusIcons"
	icon_container.position = Vector3(0.0, icon_y_offset, 0.02)
	add_child(icon_container)

	debug_label = create_debug_label()
	debug_label.position = Vector3(
		0.0,
		debug_text_y_offset,
		0.03
	)
	add_child(debug_label)


func create_debug_label() -> Label3D:
	var label: Label3D = Label3D.new()

	label.name = "PersonalityDebug"
	label.text = ""
	label.font_size = debug_font_size
	label.pixel_size = debug_pixel_size
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.92, 0.96, 1.0, 1.0)
	label.outline_size = 6
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.98)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.no_depth_test = true

	return label


func create_quad(node_name: String, width: float, height: float, color: Color) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var quad_mesh: QuadMesh = QuadMesh.new()
	quad_mesh.size = Vector2(width, height)
	mesh_instance.mesh = quad_mesh
	mesh_instance.material_override = make_material(color)

	add_child(mesh_instance)
	return mesh_instance


func make_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = 0.35
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	return material


func refresh_now() -> void:
	if health_back == null:
		return

	update_bars()
	update_status_icons()
	update_personality_debug()


func update_personality_debug() -> void:
	if debug_label == null:
		return

	if not show_personality_debug:
		debug_label.visible = false
		return

	if brain == null or not is_instance_valid(brain):
		refresh_component_refs()

	if brain == null:
		debug_label.visible = false
		return

	if not brain.has_method("get_debug_data"):
		debug_label.visible = false
		return

	var raw_debug_data: Variant = brain.call("get_debug_data")

	if not raw_debug_data is Dictionary:
		debug_label.visible = false
		return

	var debug_data: Dictionary = raw_debug_data as Dictionary
	var personality: String = str(
		debug_data.get("personality", "")
	)

	# Ordinary enemies remain uncluttered. This label appears only for
	# personality-aware brains that publish a personality debug field.
	if personality == "":
		debug_label.visible = false
		return

	var target_name: String = "none"
	var target_value: Variant = brain.get("player")

	if target_value is Node:
		var target: Node = target_value as Node

		if is_instance_valid(target):
			target_name = target.name

	var state_name: String = str(
		debug_data.get("state", "UNKNOWN")
	)
	var target_distance: String = str(
		debug_data.get("dist", "?")
	)
	var zone_summary: String = str(
		debug_data.get("zone", "clear")
	)
	var action_summary: String = str(
		debug_data.get("last", "none")
	)

	var new_text: String = (
		personality
		+ " | "
		+ state_name
		+ "\n"
		+ "target: "
		+ target_name
		+ " | "
		+ target_distance
		+ "m"
		+ "\n"
		+ zone_summary
		+ "\n"
		+ action_summary
	)

	if new_text != last_debug_text:
		last_debug_text = new_text
		debug_label.text = new_text

	debug_label.visible = true


func update_world_position() -> void:
	var target_height: float = estimate_target_height(target_node)
	global_position = target_node.global_position + Vector3.UP * (target_height + vertical_padding)


func face_camera(_delta: float) -> void:
	# Bar quads and icon labels use built-in billboarding. Keeping this node unrotated
	# avoids mirrored letters while the HUD still faces the camera.
	return


func update_bars() -> void:
	if hit_receiver == null or not is_instance_valid(hit_receiver):
		set_bar_visible(false)
		return

	var max_health: int = int(hit_receiver.get("max_health"))
	var current_health: int = int(hit_receiver.get("current_health"))
	var max_stance: int = int(hit_receiver.get("max_stance"))
	var current_stance: int = int(hit_receiver.get("current_stance"))

	var has_health: bool = max_health > 0
	var has_stance: bool = max_stance > 0

	health_back.visible = has_health
	health_fill.visible = has_health and current_health > 0
	stance_back.visible = has_stance
	stance_fill.visible = has_stance and current_stance > 0

	if has_health:
		var health_ratio: float = clamp(float(current_health) / float(max_health), 0.0, 1.0)
		set_bar_ratio(health_fill, health_ratio, health_bar_height)
		set_material_color(health_fill, get_health_color(health_ratio))

	if has_stance:
		var stance_ratio: float = clamp(float(current_stance) / float(max_stance), 0.0, 1.0)
		set_bar_ratio(stance_fill, stance_ratio, stance_bar_height)


func set_bar_visible(is_visible: bool) -> void:
	health_back.visible = is_visible
	health_fill.visible = is_visible
	stance_back.visible = is_visible
	stance_fill.visible = is_visible


func set_bar_ratio(bar: MeshInstance3D, ratio: float, height: float) -> void:
	if bar == null or bar.mesh == null:
		return

	var width: float = max(bar_width * ratio, 0.001)
	var quad_mesh: QuadMesh = bar.mesh as QuadMesh

	if quad_mesh == null:
		return

	quad_mesh.size = Vector2(width, height)
	bar.position.x = -bar_width * 0.5 + width * 0.5


func set_material_color(mesh_instance: MeshInstance3D, color: Color) -> void:
	if mesh_instance == null:
		return

	var material: StandardMaterial3D = mesh_instance.material_override as StandardMaterial3D

	if material == null:
		return

	material.albedo_color = color
	material.emission = Color(color.r, color.g, color.b, 1.0)


func get_health_color(ratio: float) -> Color:
	if ratio <= 0.3:
		return HEALTH_LOW_COLOR

	if ratio <= 0.6:
		return HEALTH_MID_COLOR

	return HEALTH_GOOD_COLOR


func update_status_icons() -> void:
	var statuses: Array[String] = get_active_status_names()
	var signature: String = ",".join(statuses)

	if signature == last_status_signature:
		return

	last_status_signature = signature
	clear_status_icons()

	if statuses.size() <= 0:
		return

	var start_x: float = -float(statuses.size() - 1) * icon_spacing * 0.5

	for i: int in range(statuses.size()):
		var status_name: String = statuses[i]
		var label: Label3D = create_status_icon(status_name)
		label.position = Vector3(start_x + float(i) * icon_spacing, 0.0, 0.0)
		icon_container.add_child(label)
		status_icon_labels.append(label)


func clear_status_icons() -> void:
	for label: Label3D in status_icon_labels:
		if label != null and is_instance_valid(label):
			label.queue_free()

	status_icon_labels.clear()


func create_status_icon(status_name: String) -> Label3D:
	var label: Label3D = Label3D.new()
	label.name = "StatusIcon_" + status_name
	label.text = get_status_icon_text(status_name)
	label.font_size = 44
	label.pixel_size = 0.0085
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = get_status_icon_color(status_name)
	label.outline_size = 5
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.96)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func get_active_status_names() -> Array[String]:
	var names: Array[String] = []
	append_status_receiver_names(names)
	append_tag_component_status_names(names)
	names.sort()
	return names


func append_status_receiver_names(names: Array[String]) -> void:
	if status_receiver == null or not is_instance_valid(status_receiver):
		return

	var active_statuses: Variant = status_receiver.get("active_statuses")

	if active_statuses is Dictionary:
		var status_dictionary: Dictionary = active_statuses as Dictionary

		for status_name: Variant in status_dictionary.keys():
			add_status_name(names, str(status_name))


func append_tag_component_status_names(names: Array[String]) -> void:
	if tag_component == null or not is_instance_valid(tag_component):
		return

	for status_name: String in STATUS_TAG_NAMES:
		if tag_component.has_method("has_tag"):
			if tag_component.has_tag(status_name):
				add_status_name(names, status_name)

	var raw_tags: Variant = tag_component.get("tags")

	if raw_tags is Array:
		for tag_value: Variant in raw_tags:
			var tag_name: String = str(tag_value)

			if STATUS_TAG_NAMES.has(tag_name):
				add_status_name(names, tag_name)


func add_status_name(names: Array[String], status_name: String) -> void:
	if status_name == "":
		return

	if not STATUS_TAG_NAMES.has(status_name):
		return

	if names.has(status_name):
		return

	names.append(status_name)


func get_status_icon_text(status_name: String) -> String:
	match status_name:
		"burning":
			return "F"
		"poisoned":
			return "P"
		"frozen":
			return "*"
		"chill":
			return "C"
		"stunned":
			return "Z"
		"wet":
			return "W"
		"staggered":
			return "!"
		"oily":
			return "O"
		_:
			return status_name.left(1).to_upper()


func get_status_icon_color(status_name: String) -> Color:
	match status_name:
		"burning":
			return Color(1.0, 0.32, 0.08, 1.0)
		"poisoned":
			return Color(0.45, 1.0, 0.2, 1.0)
		"frozen", "chill":
			return Color(0.48, 0.92, 1.0, 1.0)
		"stunned":
			return Color(1.0, 0.9, 0.18, 1.0)
		"wet":
			return Color(0.25, 0.58, 1.0, 1.0)
		"staggered":
			return STANCE_COLOR
		"oily":
			return Color(0.5, 0.42, 0.24, 1.0)
		_:
			return Color(0.72, 1.0, 0.72, 1.0)


func is_target_defeated() -> bool:
	if hit_receiver == null or not is_instance_valid(hit_receiver):
		return false

	var max_health: int = int(hit_receiver.get("max_health"))
	var current_health: int = int(hit_receiver.get("current_health"))
	return max_health > 0 and current_health <= 0


func estimate_target_height(root: Node) -> float:
	var height: float = estimate_height_from_collision_shapes(root)

	if height > 0.0:
		return height

	return fallback_target_height


func estimate_height_from_collision_shapes(root: Node) -> float:
	if root == null:
		return 0.0

	var height: float = 0.0

	if root is CollisionShape3D:
		var collision_shape: CollisionShape3D = root as CollisionShape3D
		height = max(height, get_shape_height(collision_shape.shape))

	for child: Node in root.get_children():
		height = max(height, estimate_height_from_collision_shapes(child))

	return height


func get_shape_height(shape: Shape3D) -> float:
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
