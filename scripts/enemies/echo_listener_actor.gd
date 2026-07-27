extends EnemyActor
class_name EchoListenerActor

signal provoked(creature: EchoListenerActor)
signal defeated(creature: EchoListenerActor)
signal escape_finished(creature: EchoListenerActor, route: String)

@export_group("Echo Combat")
@export var movement_speed: float = 1.9
@export var preferred_distance: float = 3.6
@export var pulse_radius: float = 5.6
@export var pulse_damage: int = 1
@export var pulse_knockback: float = 5.2
@export var pulse_windup_seconds: float = 0.9
@export var pulse_cooldown_seconds: float = 3.4

var revealed: bool = false
var combat_active: bool = false
var resolved: bool = false
var pulse_cooldown: float = 1.6
var pulse_windup: float = 0.0
var strafe_timer: float = 1.2
var strafe_direction: float = 1.0
var elapsed: float = 0.0
var current_route: String = ""

var player: CharacterBody3D
var hit_receiver: Node
var collision_shape: CollisionShape3D
var visual_root: Node3D
var body_visual: MeshInstance3D
var head_visual: MeshInstance3D
var throat_visual: MeshInstance3D
var throat_material: StandardMaterial3D


func _ready() -> void:
	super._ready()
	hit_receiver = get_node_or_null("HitReceiver")
	collision_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	visual_root = get_node_or_null("VisualRoot") as Node3D
	if visual_root == null:
		visual_root = Node3D.new()
		visual_root.name = "VisualRoot"
		add_child(visual_root)
	_build_visual()
	if hit_receiver != null and hit_receiver.has_signal("health_depleted"):
		if not hit_receiver.health_depleted.is_connected(_on_health_depleted):
			hit_receiver.health_depleted.connect(_on_health_depleted)
	remove_from_group("enemy")
	visual_root.visible = false
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	add_to_group("echo_listener")


func _process(delta: float) -> void:
	elapsed += maxf(delta, 0.0)
	_update_visuals()


func _physics_process(delta: float) -> void:
	if not revealed or resolved:
		velocity = velocity.move_toward(Vector3.ZERO, 10.0 * delta)
		return
	if not combat_active:
		velocity = velocity.move_toward(Vector3.ZERO, 9.0 * delta)
		if not is_on_floor():
			velocity.y -= 18.0 * delta
		elif velocity.y < 0.0:
			velocity.y = -0.1
		move_and_slide()
		return

	_resolve_player()
	if player == null:
		return

	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	var distance: float = to_player.length()
	var direction: Vector3 = to_player.normalized() if distance > 0.01 else Vector3.FORWARD
	_face_direction(direction, delta)

	if pulse_windup > 0.0:
		pulse_windup = maxf(pulse_windup - delta, 0.0)
		velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
		if pulse_windup <= 0.0:
			_release_echo_pulse()
	else:
		pulse_cooldown = maxf(pulse_cooldown - delta, 0.0)
		strafe_timer = maxf(strafe_timer - delta, 0.0)
		if strafe_timer <= 0.0:
			strafe_timer = 1.0 + fmod(elapsed, 0.8)
			strafe_direction *= -1.0

		var requested: Vector3 = Vector3.ZERO
		if distance > preferred_distance + 0.8:
			requested = direction
		elif distance < preferred_distance - 0.6:
			requested = -direction
		else:
			requested = Vector3(-direction.z, 0.0, direction.x) * strafe_direction
		velocity.x = move_toward(velocity.x, requested.x * movement_speed, 7.0 * delta)
		velocity.z = move_toward(velocity.z, requested.z * movement_speed, 7.0 * delta)

		if pulse_cooldown <= 0.0 and distance <= pulse_radius + 1.8:
			_begin_echo_windup()

	if not is_on_floor():
		velocity.y -= 18.0 * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1
	move_and_slide()


func set_revealed(value: bool) -> void:
	revealed = value
	visible = value
	if visual_root != null:
		visual_root.visible = value
	if collision_shape != null:
		collision_shape.set_deferred("disabled", not value)
	if value and not resolved:
		add_to_group("enemy")
	else:
		remove_from_group("enemy")


func notify_attacked(_payload: DamagePayload) -> void:
	if not revealed or resolved:
		return
	if combat_active:
		return
	combat_active = true
	pulse_cooldown = 0.35
	provoked.emit(self)
	_show_message("The Listener recoils. Its throat swells with a returning echo.")


func calm_and_escape(route: String, destination: Vector3) -> void:
	if resolved:
		return
	resolved = true
	combat_active = false
	current_route = route
	remove_from_group("enemy")
	velocity = Vector3.ZERO
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", destination, 2.35)
	tween.parallel().tween_property(self, "scale", Vector3.ONE * 0.58, 2.35)
	tween.finished.connect(_finish_escape)


func _finish_escape() -> void:
	visible = false
	escape_finished.emit(self, current_route)


func _on_health_depleted() -> void:
	if resolved:
		return
	resolved = true
	combat_active = false
	current_route = "fought"
	remove_from_group("enemy")
	velocity = Vector3.ZERO
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	defeated.emit(self)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", position.y - 1.25, 1.15)
	tween.parallel().tween_property(self, "scale", Vector3.ONE * 0.72, 1.15)
	tween.finished.connect(_hide_defeated)


func _hide_defeated() -> void:
	visible = false


func _begin_echo_windup() -> void:
	pulse_windup = pulse_windup_seconds
	pulse_cooldown = pulse_cooldown_seconds
	_show_message("The Listener draws breath. The crypt stones begin to hum.")


func _release_echo_pulse() -> void:
	_spawn_echo_ring()
	_resolve_player()
	if player == null:
		return
	var offset: Vector3 = player.global_position - global_position
	var horizontal := Vector3(offset.x, 0.0, offset.z)
	if horizontal.length() > pulse_radius:
		return
	GameState.take_damage(pulse_damage)
	if horizontal.length_squared() > 0.001:
		player.velocity += horizontal.normalized() * pulse_knockback + Vector3.UP * 1.15
	_show_message("The returning echo strikes Grace.")


func _spawn_echo_ring() -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	var ring := MeshInstance3D.new()
	ring.name = "ListenerEchoPulse"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.48
	mesh.outer_radius = 0.56
	mesh.rings = 28
	mesh.ring_segments = 10
	ring.mesh = mesh
	ring.rotation.x = PI / 2.0
	ring.global_position = global_position + Vector3.UP * 0.45
	var pulse_material := _material(Color(0.55, 0.84, 1.0, 0.68), true, 1.8)
	ring.material_override = pulse_material
	get_tree().current_scene.add_child(ring)
	var tween: Tween = ring.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "scale", Vector3.ONE * pulse_radius, 0.52)
	tween.parallel().tween_property(pulse_material, "albedo_color:a", 0.0, 0.52)
	tween.finished.connect(ring.queue_free)


func _resolve_player() -> void:
	if player != null and is_instance_valid(player):
		return
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D


func _face_direction(direction: Vector3, delta: float) -> void:
	if direction.length_squared() <= 0.001:
		return
	var target_yaw: float = atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 5.0, 0.0, 1.0))


func _build_visual() -> void:
	if visual_root.get_child_count() > 0:
		return
	body_visual = _sphere("Body", Vector3(0.0, 0.72, 0.0), 0.82, Vector3(1.28, 0.72, 1.0), Color(0.09, 0.34, 0.38))
	head_visual = _sphere("Head", Vector3(0.0, 1.15, -0.72), 0.68, Vector3(1.05, 0.72, 0.92), Color(0.11, 0.4, 0.43))
	throat_material = _material(Color(0.32, 0.78, 0.88, 0.72), true, 1.25)
	throat_visual = _sphere("ThroatSac", Vector3(0.0, 0.85, -1.08), 0.4, Vector3(0.92, 0.72, 0.52), Color(0.32, 0.78, 0.88, 0.72), throat_material)
	_sphere("BrowLeft", Vector3(-0.26, 1.29, -1.24), 0.18, Vector3(1.45, 0.38, 0.38), Color(0.045, 0.17, 0.18))
	_sphere("BrowRight", Vector3(0.26, 1.29, -1.24), 0.18, Vector3(1.45, 0.38, 0.38), Color(0.045, 0.17, 0.18))
	for side: float in [-1.0, 1.0]:
		var suffix: String = "L" if side < 0.0 else "R"
		_sphere("Gill%s" % suffix, Vector3(side * 0.72, 1.16, -0.58), 0.36, Vector3(0.32, 1.15, 0.72), Color(0.28, 0.62, 0.67, 0.86))
		_cylinder("Foreleg%s" % suffix, Vector3(side * 0.78, 0.35, -0.58), 0.12, 0.78, Vector3(0.24, 0.0, side * 0.62), Color(0.07, 0.27, 0.29))
		_cylinder("Hindleg%s" % suffix, Vector3(side * 0.9, 0.3, 0.55), 0.14, 0.92, Vector3(-0.18, 0.0, side * 0.72), Color(0.07, 0.27, 0.29))
		_sphere("WebbedFoot%s" % suffix, Vector3(side * 1.14, 0.08, -0.62), 0.22, Vector3(1.5, 0.28, 0.8), Color(0.12, 0.38, 0.39))
	_cylinder("Tail", Vector3(0.0, 0.55, 1.05), 0.18, 1.6, Vector3(PI / 2.0, 0.0, 0.0), Color(0.07, 0.29, 0.31))
	for index: int in range(4):
		_sphere("DorsalRidge%02d" % index, Vector3(0.0, 1.18, -0.15 + float(index) * 0.35), 0.13, Vector3(0.42, 1.25, 0.5), Color(0.24, 0.58, 0.6))


func _update_visuals() -> void:
	if visual_root == null or not visual_root.visible:
		return
	var breath_speed: float = 6.5 if combat_active else 2.1
	var breath: float = sin(elapsed * breath_speed)
	if body_visual != null:
		body_visual.scale = Vector3(1.28, 0.72 + breath * 0.025, 1.0)
	if head_visual != null:
		head_visual.rotation.z = sin(elapsed * 1.25) * 0.035
	if throat_visual != null:
		var windup_weight: float = 1.0 - clampf(pulse_windup / maxf(pulse_windup_seconds, 0.01), 0.0, 1.0) if pulse_windup > 0.0 else 0.0
		var pulse: float = 1.0 + breath * 0.07 + windup_weight * 0.55
		throat_visual.scale = Vector3(0.92, 0.72, 0.52) * pulse
		if throat_material != null:
			throat_material.emission_energy_multiplier = 1.25 + windup_weight * 2.8


func _sphere(
	node_name: String,
	position_value: Vector3,
	radius: float,
	scale_value: Vector3,
	color: Color,
	material_override: StandardMaterial3D = null
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.position = position_value
	node.scale = scale_value
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 14
	mesh.rings = 9
	node.mesh = mesh
	node.material_override = material_override if material_override != null else _material(color)
	visual_root.add_child(node)
	return node


func _cylinder(
	node_name: String,
	position_value: Vector3,
	radius: float,
	height: float,
	rotation_value: Vector3,
	color: Color
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.position = position_value
	node.rotation = rotation_value
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.72
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 9
	node.mesh = mesh
	node.material_override = _material(color)
	visual_root.add_child(node)
	return node


func _material(color: Color, emissive: bool = false, energy: float = 0.0) -> StandardMaterial3D:
	var value := StandardMaterial3D.new()
	value.albedo_color = color
	value.roughness = 0.62
	if color.a < 1.0:
		value.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissive:
		value.emission_enabled = true
		value.emission = Color(color.r, color.g, color.b, 1.0)
		value.emission_energy_multiplier = maxf(energy, 0.1)
	return value


func _show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)


func get_debug_data() -> Dictionary:
	return {
		"revealed": revealed,
		"combat": combat_active,
		"resolved": resolved,
		"route": current_route,
		"pulse_cooldown": snappedf(pulse_cooldown, 0.05),
		"pulse_windup": snappedf(pulse_windup, 0.05),
	}
