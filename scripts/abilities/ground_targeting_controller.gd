extends RefCounted
class_name GroundTargetingController

var owner_node: Node = null
var source_player: Node3D = null
var ability: Resource = null
var config: Dictionary = {}
var target_position: Vector3 = Vector3.ZERO
var marker: Node3D = null
var active: bool = false

func start(new_owner: Node, new_player: Node3D, new_ability: Resource, new_config: Dictionary) -> bool:
	cancel()
	owner_node = new_owner
	source_player = new_player
	ability = new_ability
	config = new_config.duplicate(true)
	if owner_node == null or source_player == null or ability == null:
		return false
	target_position = resolve_ground(clamp_to_range(initial_position()))
	active = true
	ensure_marker()
	update_marker()
	return true

func update(delta: float) -> void:
	if not active:
		return
	if source_player == null or not is_instance_valid(source_player):
		cancel()
		return
	var input_vector: Vector2 = Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if input_vector.length() >= get_float("deadzone", 0.18):
		var move: Vector3 = move_direction(input_vector)
		if move.length() > 0.01:
			target_position += move * get_float("speed", 8.0) * delta
			target_position = resolve_ground(clamp_to_range(target_position))
	update_marker()

func cancel() -> void:
	if marker != null and is_instance_valid(marker):
		marker.queue_free()
	marker = null
	active = false
	owner_node = null
	source_player = null
	ability = null
	config = {}
	target_position = Vector3.ZERO

func is_active() -> bool:
	return active

func get_spell_key() -> String:
	return str(config.get("spell_key", ""))

func get_target_position() -> Vector3:
	return target_position

func get_ability() -> Resource:
	return ability

func get_source_player() -> Node3D:
	return source_player

func get_target_radius() -> float:
	return get_float("radius", 2.0)

func get_cast_lock_duration(fallback: float) -> float:
	return get_float("cast_lock_duration", fallback)

func initial_position() -> Vector3:
	var forward: Vector3 = -source_player.global_transform.basis.z
	forward.y = 0.0
	if forward.length() <= 0.01:
		forward = Vector3.FORWARD
	return source_player.global_position + forward.normalized() * get_float("initial_distance", 6.0)

func clamp_to_range(raw_position: Vector3) -> Vector3:
	var origin: Vector3 = source_player.global_position
	var offset: Vector3 = raw_position - origin
	offset.y = 0.0
	var target_range: float = get_float("range", 12.0)
	if offset.length() > target_range:
		offset = offset.normalized() * target_range
	return origin + offset

func resolve_ground(raw_position: Vector3) -> Vector3:
	var resolved: Vector3 = raw_position
	var owner_3d: Node3D = owner_node as Node3D
	if owner_3d != null:
		var world_3d: World3D = owner_3d.get_world_3d()
		if world_3d != null:
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(raw_position + Vector3.UP * 8.0, raw_position + Vector3.DOWN * 18.0)
			var result: Dictionary = world_3d.direct_space_state.intersect_ray(query)
			if result.has("position"):
				resolved = result["position"]
	resolved.y += get_float("ground_y_offset", 0.05)
	return resolved

func move_direction(input_vector: Vector2) -> Vector3:
	var camera: Camera3D = null
	if owner_node != null and owner_node.get_viewport() != null:
		camera = owner_node.get_viewport().get_camera_3d()
	var right: Vector3 = Vector3.RIGHT
	var forward: Vector3 = Vector3.FORWARD
	if camera != null:
		right = camera.global_transform.basis.x
		forward = -camera.global_transform.basis.z
	elif source_player != null:
		right = source_player.global_transform.basis.x
		forward = -source_player.global_transform.basis.z
	right.y = 0.0
	forward.y = 0.0
	if right.length() <= 0.01:
		right = Vector3.RIGHT
	if forward.length() <= 0.01:
		forward = Vector3.FORWARD
	var move: Vector3 = right.normalized() * input_vector.x + forward.normalized() * -input_vector.y
	return move.normalized() if move.length() > 0.01 else Vector3.ZERO

func ensure_marker() -> void:
	if marker != null and is_instance_valid(marker):
		return
	if owner_node == null or owner_node.get_tree() == null or owner_node.get_tree().current_scene == null:
		return
	marker = Node3D.new()
	marker.name = str(config.get("marker_name", "GroundTargetMarker"))
	var disc: MeshInstance3D = MeshInstance3D.new()
	disc.name = str(config.get("disc_name", "TargetDisc"))
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var disc_mesh: CylinderMesh = CylinderMesh.new()
	disc_mesh.top_radius = 1.0
	disc_mesh.bottom_radius = 1.0
	disc_mesh.height = 0.035
	disc.mesh = disc_mesh
	disc.scale = Vector3(get_target_radius(), 1.0, get_target_radius())
	disc.material_override = marker_material(get_color("disc_color", Color(0.4, 0.4, 0.4, 0.34)), get_float("disc_alpha", 0.34))
	marker.add_child(disc)
	var center: MeshInstance3D = MeshInstance3D.new()
	center.name = str(config.get("center_name", "TargetCenter"))
	center.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var center_mesh: SphereMesh = SphereMesh.new()
	center_mesh.radius = 0.13
	center_mesh.height = 0.26
	center.mesh = center_mesh
	center.material_override = marker_material(get_color("center_color", get_color("disc_color", Color(0.4, 0.4, 0.4, 0.8))), get_float("center_alpha", 0.78))
	marker.add_child(center)
	owner_node.get_tree().current_scene.add_child(marker)

func update_marker() -> void:
	if marker == null:
		return
	marker.global_position = target_position
	var age: float = float(Time.get_ticks_msec()) * 0.001
	var pulse: float = 1.0 + sin(age * get_float("pulse_speed", 5.0)) * get_float("pulse_size", 0.04)
	marker.scale = Vector3.ONE * pulse

func marker_material(color: Color, alpha: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = get_float("emission_energy", 0.6)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func get_float(key: String, fallback: float) -> float:
	var value: Variant = config.get(key, fallback)
	return fallback if value == null else float(value)

func get_color(key: String, fallback: Color) -> Color:
	var value: Variant = config.get(key, fallback)
	if value is Color:
		return value as Color
	return fallback
