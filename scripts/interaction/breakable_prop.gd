extends Area3D
class_name BreakableProp

signal cracked
signal broken
signal reset_completed

@export_group("Component Paths")
@export var hit_receiver_path: NodePath = NodePath("HitReceiver")
@export var visual_anchor_path: NodePath = NodePath("VisualAnchor")
@export var intact_visual_path: NodePath = NodePath("VisualAnchor/IntactVisual")
@export var cracked_visual_path: NodePath = NodePath("VisualAnchor/CrackedVisual")
@export var collision_shape_path: NodePath = NodePath("CollisionShape3D")

@export_group("Durability Presentation")
@export_range(0.05, 0.95, 0.05) var cracked_health_ratio: float = 0.5
@export var hit_wobble_degrees: float = 8.0
@export var hit_wobble_time: float = 0.16
@export var crack_scale_pulse: float = 1.08
@export var auto_reset_seconds: float = 4.0

@export_group("Fragments")
@export var fragment_material: Material
@export_range(3, 16, 1) var fragment_count: int = 7
@export var fragment_base_size: Vector3 = Vector3(0.24, 0.18, 0.16)
@export var fragment_spawn_radius: float = 0.28
@export var fragment_impulse: float = 4.8
@export var fragment_upward_impulse: float = 3.2
@export var fragment_lifetime: float = 3.0
@export_range(0.0, 1.0, 0.05) var impact_direction_bias: float = 0.65

var hit_receiver: Node = null
var visual_anchor: Node3D = null
var intact_visual: Node3D = null
var cracked_visual: Node3D = null
var collision_shape: CollisionShape3D = null

var is_cracked: bool = false
var is_broken: bool = false
var reset_generation: int = 0
var active_fragments: Array[RigidBody3D] = []
var reaction_tween: Tween = null
var starting_anchor_transform: Transform3D


func _ready() -> void:
	add_to_group("breakable")
	resolve_components()
	connect_receiver_signals()
	apply_health_visual()


func resolve_components() -> void:
	hit_receiver = get_node_or_null(hit_receiver_path)
	visual_anchor = get_node_or_null(visual_anchor_path) as Node3D
	intact_visual = get_node_or_null(intact_visual_path) as Node3D
	cracked_visual = get_node_or_null(cracked_visual_path) as Node3D
	collision_shape = get_node_or_null(collision_shape_path) as CollisionShape3D

	if visual_anchor != null:
		starting_anchor_transform = visual_anchor.transform


func connect_receiver_signals() -> void:
	if hit_receiver == null:
		push_warning(name + " has no HitReceiver at " + str(hit_receiver_path))
		return

	if hit_receiver.has_signal("health_changed"):
		hit_receiver.health_changed.connect(_on_health_changed)

	if hit_receiver.has_signal("health_depleted"):
		hit_receiver.health_depleted.connect(_on_health_depleted)


func _on_health_changed(current_health: int, max_health: int) -> void:
	if is_broken or current_health <= 0:
		return

	var crack_threshold: int = max(
		1,
		ceili(float(max_health) * cracked_health_ratio)
	)

	if current_health <= crack_threshold:
		enter_cracked_state()
	else:
		exit_cracked_state()

	play_hit_reaction()


func _on_health_depleted() -> void:
	break_prop()


func apply_health_visual() -> void:
	if hit_receiver == null:
		return

	var max_health: int = int(hit_receiver.get("max_health"))
	var current_health: int = int(hit_receiver.get("current_health"))

	if current_health <= 0:
		break_prop()
		return

	var crack_threshold: int = max(
		1,
		ceili(float(max_health) * cracked_health_ratio)
	)

	if current_health <= crack_threshold:
		enter_cracked_state(false)
	else:
		exit_cracked_state()


func enter_cracked_state(animate: bool = true) -> void:
	if is_cracked or is_broken:
		return

	is_cracked = true
	set_visual_state(false, true)

	if animate:
		play_crack_reaction()

	cracked.emit()


func exit_cracked_state() -> void:
	is_cracked = false

	if not is_broken:
		set_visual_state(true, false)


func break_prop() -> void:
	if is_broken:
		return

	is_broken = true
	is_cracked = false
	reset_generation += 1

	stop_reaction_tween()
	set_visual_state(false, false)
	set_collision_enabled(false)
	spawn_fragments()
	GameFeedback.play("heavy_impact", {"source": name})
	broken.emit()

	if auto_reset_seconds > 0.0:
		var scheduled_generation: int = reset_generation
		get_tree().create_timer(auto_reset_seconds).timeout.connect(
			func() -> void:
				if scheduled_generation == reset_generation:
					reset_prop()
		)


func reset_prop() -> void:
	reset_generation += 1
	is_broken = false
	is_cracked = false

	stop_reaction_tween()
	clear_fragments()

	if visual_anchor != null:
		visual_anchor.transform = starting_anchor_transform

	if hit_receiver != null:
		if hit_receiver.has_method("reset_health"):
			hit_receiver.reset_health()
		else:
			hit_receiver.set("current_health", hit_receiver.get("max_health"))

	set_collision_enabled(true)
	set_visual_state(true, false)
	reset_completed.emit()


func play_hit_reaction() -> void:
	if visual_anchor == null or is_broken:
		return

	stop_reaction_tween()
	visual_anchor.transform = starting_anchor_transform

	var tilt_radians: float = deg_to_rad(hit_wobble_degrees)
	var tilt_direction: float = -1.0 if is_cracked else 1.0

	reaction_tween = create_tween()
	reaction_tween.set_trans(Tween.TRANS_BACK)
	reaction_tween.set_ease(Tween.EASE_OUT)
	reaction_tween.tween_property(
		visual_anchor,
		"rotation:z",
		starting_anchor_transform.basis.get_euler().z + tilt_radians * tilt_direction,
		hit_wobble_time * 0.45
	)
	reaction_tween.tween_property(
		visual_anchor,
		"rotation:z",
		starting_anchor_transform.basis.get_euler().z,
		hit_wobble_time * 0.55
	)


func play_crack_reaction() -> void:
	if visual_anchor == null or is_broken:
		return

	stop_reaction_tween()
	visual_anchor.transform = starting_anchor_transform

	reaction_tween = create_tween()
	reaction_tween.set_trans(Tween.TRANS_BACK)
	reaction_tween.set_ease(Tween.EASE_OUT)
	reaction_tween.tween_property(
		visual_anchor,
		"scale",
		starting_anchor_transform.basis.get_scale() * crack_scale_pulse,
		hit_wobble_time * 0.5
	)
	reaction_tween.tween_property(
		visual_anchor,
		"scale",
		starting_anchor_transform.basis.get_scale(),
		hit_wobble_time * 0.5
	)


func stop_reaction_tween() -> void:
	if reaction_tween != null and reaction_tween.is_valid():
		reaction_tween.kill()

	reaction_tween = null


func set_visual_state(show_intact: bool, show_cracked: bool) -> void:
	if intact_visual != null:
		intact_visual.visible = show_intact

	if cracked_visual != null:
		cracked_visual.visible = show_cracked


func set_collision_enabled(enabled: bool) -> void:
	if collision_shape != null:
		collision_shape.set_deferred("disabled", not enabled)

	monitorable = enabled
	monitoring = enabled


func spawn_fragments() -> void:
	clear_fragments()

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return

	var away_from_player: Vector3 = get_impact_direction()

	for index: int in range(fragment_count):
		var angle: float = TAU * float(index) / float(fragment_count)
		var radial: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		var launch_direction: Vector3 = radial.lerp(
			away_from_player,
			impact_direction_bias
		).normalized()

		var size_variation: float = 0.72 + 0.12 * float(index % 4)
		var fragment_size: Vector3 = fragment_base_size * size_variation
		var fragment: RigidBody3D = create_fragment(fragment_size, index)

		scene_root.add_child(fragment)
		fragment.global_position = global_position + Vector3.UP * 0.65 + radial * fragment_spawn_radius
		fragment.global_rotation = global_rotation + Vector3(
			0.17 * float(index),
			angle,
			0.11 * float(index)
		)
		fragment.linear_velocity = (
			launch_direction * fragment_impulse
			+ Vector3.UP * (fragment_upward_impulse + 0.18 * float(index % 3))
		)
		fragment.angular_velocity = Vector3(
			2.2 + float(index % 3),
			3.0 + float(index % 4),
			1.8 + float(index % 5)
		)

		active_fragments.append(fragment)

		if fragment_lifetime > 0.0:
			get_tree().create_timer(fragment_lifetime).timeout.connect(
				func() -> void:
					if is_instance_valid(fragment):
						fragment.queue_free()
			)


func create_fragment(fragment_size: Vector3, index: int) -> RigidBody3D:
	var fragment: RigidBody3D = RigidBody3D.new()
	fragment.name = name + "Fragment" + str(index + 1)
	fragment.mass = 0.18
	fragment.collision_layer = 1
	fragment.collision_mask = 1

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = fragment_size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = fragment_material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	fragment.add_child(mesh_instance)

	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = fragment_size
	collision.shape = shape
	fragment.add_child(collision)

	return fragment


func get_impact_direction() -> Vector3:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D

	if player == null:
		return Vector3.FORWARD

	var direction: Vector3 = global_position - player.global_position
	direction.y = 0.0

	if direction.length() <= 0.01:
		return Vector3.FORWARD

	return direction.normalized()


func clear_fragments() -> void:
	for fragment: RigidBody3D in active_fragments:
		if is_instance_valid(fragment):
			fragment.queue_free()

	active_fragments.clear()


func get_debug_data() -> Dictionary:
	return {
		"state": "broken" if is_broken else ("cracked" if is_cracked else "intact"),
		"fragments": active_fragments.size(),
		"auto_reset": auto_reset_seconds,
	}
