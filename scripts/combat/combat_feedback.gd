extends Node
class_name CombatFeedback

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")

const DAMAGE_COLOR: Color = Color(1.0, 0.82, 0.35, 1.0)
const STANCE_COLOR: Color = Color(0.55, 0.82, 1.0, 1.0)
const STATUS_COLOR: Color = Color(0.62, 1.0, 0.48, 1.0)
const REACTION_COLOR: Color = Color(1.0, 0.58, 0.15, 1.0)
const MISS_COLOR: Color = Color(0.78, 0.82, 0.9, 1.0)
const IMMUNE_COLOR: Color = Color(0.62, 0.66, 0.76, 1.0)
const DEFEAT_COLOR: Color = Color(1.0, 0.26, 0.18, 1.0)

const DEFAULT_TEXT_LIFETIME: float = 0.72
const DEFAULT_TEXT_RISE: float = 0.75


static func show_payload_feedback(target: Node, payload: DamagePayload, result: Dictionary) -> void:
	if target == null or payload == null:
		return

	var text: String = get_payload_feedback_text(payload, result)
	var color: Color = get_payload_feedback_color(payload, result)
	var emphasis: bool = is_emphasis_result(result)

	show_world_text(target, text, color, emphasis)
	show_hit_burst(target, color, emphasis)


static func show_status_feedback(target: Node, status_name: String) -> void:
	if target == null or status_name == "":
		return

	var text: String = status_name.replace("_", " ").to_upper()
	show_world_text(target, text, get_status_color(status_name), true)


static func show_reaction_feedback(
	target: Node,
	reaction_name: String,
	reaction_data: Dictionary = {}
) -> void:
	if target == null or reaction_name == "":
		return

	var display_name: String = str(reaction_data.get("reaction_name", reaction_name))
	var text: String = display_name.replace("_", " ").to_upper()
	var color: Color = get_reaction_color(reaction_name, reaction_data)
	var visual_style: String = str(reaction_data.get("visual_style", reaction_name))
	var visual_radius: float = float(reaction_data.get("visual_radius", 1.25))
	var visual_duration: float = float(reaction_data.get("visual_duration", 0.42))
	var target_position: Vector3 = get_target_node_position(target)

	show_world_text(target, text, color, true)
	show_hit_burst(target, color, true)

	if target.get_tree() != null:
		ElementVisuals.spawn_reaction_burst(
			target.get_tree(),
			target_position + Vector3.UP * 0.4,
			visual_style,
			color,
			visual_radius,
			visual_duration
		)


static func show_miss_feedback(source: Node, world_position: Vector3) -> void:
	if source == null or source.get_tree() == null:
		return

	show_world_text_at(source.get_tree(), world_position, "MISS", MISS_COLOR, false)


static func get_payload_feedback_text(payload: DamagePayload, result: Dictionary) -> String:
	var message: String = str(result.get("message", "")).to_lower()

	if message.contains("immune") or message.contains("ignores"):
		return "IMMUNE"

	if message.contains("defeats") or message.contains("defeated"):
		return "DEFEATED"

	if message.contains("stance breaks") or message.contains("stance break"):
		return "STANCE BREAK"

	if message.contains("resist"):
		return "RESIST"

	if message.contains("stance:"):
		return "-" + str(max(payload.stance_damage, 1)) + " ST"

	if message.contains("health:"):
		return "-" + str(max(payload.amount, 1)) + " HP"

	if payload.amount > 0:
		return "-" + str(payload.amount) + " HP"

	if payload.stance_damage > 0:
		return "-" + str(payload.stance_damage) + " ST"

	return "HIT"


static func get_payload_feedback_color(payload: DamagePayload, result: Dictionary) -> Color:
	var message: String = str(result.get("message", "")).to_lower()

	if message.contains("immune") or message.contains("ignores") or message.contains("resist"):
		return IMMUNE_COLOR

	if message.contains("defeats") or message.contains("defeated"):
		return DEFEAT_COLOR

	if message.contains("stance"):
		return STANCE_COLOR

	return get_element_color(payload.element)


static func is_emphasis_result(result: Dictionary) -> bool:
	var message: String = str(result.get("message", "")).to_lower()
	return (
		message.contains("defeats")
		or message.contains("defeated")
		or message.contains("stance breaks")
		or message.contains("stance break")
		or message.contains("immune")
		or message.contains("ignores")
	)


static func show_world_text(target: Node, text: String, color: Color, emphasis: bool = false) -> void:
	if target == null or target.get_tree() == null:
		return

	var position: Vector3 = get_feedback_position(target)
	show_world_text_at(target.get_tree(), position, text, color, emphasis)


static func show_world_text_at(tree: SceneTree, position: Vector3, text: String, color: Color, emphasis: bool = false) -> void:
	if tree == null or tree.current_scene == null:
		return

	var label: Label3D = Label3D.new()
	label.name = "CombatText"
	label.text = text
	label.font_size = 54 if emphasis else 42
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.outline_size = 6
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	label.scale = Vector3.ONE * (1.12 if emphasis else 1.0)

	tree.current_scene.add_child(label)
	label.global_position = position

	var lifetime: float = DEFAULT_TEXT_LIFETIME + (0.18 if emphasis else 0.0)
	var rise: float = DEFAULT_TEXT_RISE + (0.2 if emphasis else 0.0)
	var final_position: Vector3 = position + Vector3.UP * rise
	var final_scale: Vector3 = Vector3.ONE * (0.84 if emphasis else 0.72)

	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", final_position, lifetime)
	tween.tween_property(label, "scale", final_scale, lifetime)
	tween.set_parallel(false)
	tween.tween_callback(Callable(label, "queue_free"))


static func show_hit_burst(target: Node, color: Color, emphasis: bool = false) -> void:
	if target == null or target.get_tree() == null or target.get_tree().current_scene == null:
		return

	var burst: MeshInstance3D = MeshInstance3D.new()
	burst.name = "CombatHitBurst"
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.16 if not emphasis else 0.24
	mesh.height = mesh.radius * 2.0
	burst.mesh = mesh

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, 0.34 if not emphasis else 0.52)
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = 0.9 if not emphasis else 1.8
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	burst.material_override = material

	target.get_tree().current_scene.add_child(burst)
	burst.global_position = get_feedback_position(target) - Vector3.UP * 0.25
	burst.scale = Vector3.ONE * 0.18

	var final_scale: Vector3 = Vector3.ONE * (1.15 if not emphasis else 1.85)
	var tween: Tween = burst.create_tween()
	tween.tween_property(burst, "scale", final_scale, 0.18 if not emphasis else 0.24)
	tween.tween_callback(Callable(burst, "queue_free"))


static func get_feedback_position(target: Node) -> Vector3:
	var node_3d: Node3D = get_target_node_3d(target)

	if node_3d == null:
		return Vector3.ZERO

	var height: float = estimate_target_height(target)
	var offset_x: float = randf_range(-0.18, 0.18)
	var offset_z: float = randf_range(-0.18, 0.18)
	return node_3d.global_position + Vector3(offset_x, max(height * 0.82, 1.0), offset_z)


static func get_target_node_position(target: Node) -> Vector3:
	var node_3d: Node3D = get_target_node_3d(target)

	if node_3d == null:
		return Vector3.ZERO

	return node_3d.global_position


static func get_target_node_3d(target: Node) -> Node3D:
	if target is Node3D:
		return target as Node3D

	var parent: Node = target.get_parent()

	if parent is Node3D:
		return parent as Node3D

	return null


static func estimate_target_height(target: Node) -> float:
	var height: float = estimate_height_from_collision_shapes(target)

	if height > 0.0:
		return height

	return 1.8


static func estimate_height_from_collision_shapes(root: Node) -> float:
	if root == null:
		return 0.0

	var height: float = 0.0

	if root is CollisionShape3D:
		var collision_shape: CollisionShape3D = root as CollisionShape3D
		height = max(height, get_shape_height(collision_shape.shape))

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


static func get_status_color(status_name: String) -> Color:
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
		"oily":
			return Color(0.58, 0.2, 0.68, 1.0)
		"steamed":
			return ElementVisuals.get_element_color("steam")
		"revealed":
			return ElementVisuals.get_element_color("sound")
		"staggered":
			return STANCE_COLOR
		_:
			return STATUS_COLOR


static func get_reaction_color(reaction_name: String, reaction_data: Dictionary) -> Color:
	var configured_color: Variant = reaction_data.get("visual_color")

	if configured_color is Color:
		return configured_color as Color

	match reaction_name:
		"ignite_oil", "ignite":
			return ElementVisuals.get_element_color("fire")
		"wet_conduction", "conduct":
			return ElementVisuals.get_element_color("lightning")
		"wet_freeze", "freeze", "shatter":
			return ElementVisuals.get_element_color("ice")
		"steam_burst", "steam":
			return ElementVisuals.get_element_color("steam")
		"reveal", "sound_reveal":
			return ElementVisuals.get_element_color("sound")
		_:
			return REACTION_COLOR


static func get_element_color(element: String) -> Color:
	match element:
		"fire":
			return Color(1.0, 0.3, 0.08, 1.0)
		"water":
			return Color(0.2, 0.55, 1.0, 1.0)
		"ice":
			return Color(0.5, 0.92, 1.0, 1.0)
		"lightning":
			return Color(0.72, 0.72, 1.0, 1.0)
		"poison":
			return Color(0.48, 1.0, 0.22, 1.0)
		"sound":
			return Color(1.0, 0.43, 0.74, 1.0)
		"space":
			return Color(0.68, 0.32, 1.0, 1.0)
		"air":
			return Color(1.0, 0.52, 0.78, 1.0)
		_:
			return DAMAGE_COLOR
