extends CharacterBody3D
class_name RideableMount

signal rider_changed(rider: Node3D)
signal gait_changed(gait: String)
signal mount_stamina_changed(current: float, maximum: float)
signal severe_collision(impact_speed: float)
signal summon_state_changed(state: String)

@export var display_name: String = "Foundry Courser"
@export var walk_speed: float = 2.8
@export var trot_speed: float = 5.2
@export var gallop_speed: float = 9.5
@export var reverse_speed: float = 2.2
@export var acceleration: float = 8.0
@export var braking: float = 12.0
@export var turn_speed: float = 1.85
@export var jump_velocity: float = 5.2
@export var gravity: float = 18.0
@export var maximum_stamina: float = 100.0
@export var gallop_stamina_per_second: float = 17.0
@export var stamina_recovery_per_second: float = 13.0
@export var severe_collision_speed: float = 7.5
@export var summon_speed: float = 11.0
@export var summon_arrival_distance: float = 2.2

var rider: Node3D
var current_speed: float = 0.0
var mount_stamina: float = 100.0
var current_gait: String = "IDLE"
var steering_input: float = 0.0
var summon_state: String = "READY"
var summon_target: Vector3 = Vector3.ZERO
var home_position: Vector3 = Vector3.ZERO
var seat: Marker3D
var left_dismount: Marker3D
var right_dismount: Marker3D
var last_impact_speed: float = 0.0


func _ready() -> void:
	home_position = global_position
	mount_stamina = maximum_stamina
	add_to_group("rideable_mount")
	_build_mount_body()


func _physics_process(delta: float) -> void:
	if rider != null:
		return
	if summon_state == "ANSWERING":
		_process_summon(delta)
	else:
		_apply_idle_physics(delta)


func process_ridden_locomotion(delta: float, input_vector: Vector2, gallop_requested: bool, jump_requested: bool) -> void:
	if rider == null:
		return

	steering_input = input_vector.x
	var throttle: float = -input_vector.y
	var can_gallop: bool = gallop_requested and mount_stamina > 0.5 and throttle > 0.25
	var target_speed: float = 0.0
	if throttle > 0.05:
		target_speed = gallop_speed if can_gallop else (trot_speed if throttle > 0.55 else walk_speed)
	elif throttle < -0.05:
		target_speed = reverse_speed * throttle

	if can_gallop:
		mount_stamina = maxf(mount_stamina - gallop_stamina_per_second * delta, 0.0)
	else:
		mount_stamina = minf(mount_stamina + stamina_recovery_per_second * delta, maximum_stamina)
	mount_stamina_changed.emit(mount_stamina, maximum_stamina)

	var response: float = acceleration if absf(target_speed) > absf(current_speed) else braking
	current_speed = move_toward(current_speed, target_speed, response * delta)
	var speed_ratio: float = clampf(absf(current_speed) / maxf(gallop_speed, 0.1), 0.0, 1.0)
	if absf(current_speed) > 0.15:
		rotate_y(-steering_input * turn_speed * lerpf(0.42, 1.0, speed_ratio) * delta)

	velocity.x = -global_basis.z.x * current_speed
	velocity.z = -global_basis.z.z * current_speed
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif jump_requested and absf(current_speed) > walk_speed * 0.7:
		velocity.y = jump_velocity
	elif velocity.y < 0.0:
		velocity.y = -0.1

	var pre_move_speed: float = Vector3(velocity.x, 0.0, velocity.z).length()
	move_and_slide()
	_check_collisions(pre_move_speed)
	_set_gait(_resolve_gait())


func assign_rider(next_rider: Node3D) -> bool:
	if next_rider == null or rider != null:
		return false
	rider = next_rider
	summon_state = "MOUNTED"
	summon_state_changed.emit(summon_state)
	rider_changed.emit(rider)
	return true


func clear_rider() -> void:
	rider = null
	current_speed = 0.0
	steering_input = 0.0
	summon_state = "READY"
	_set_gait("IDLE")
	summon_state_changed.emit(summon_state)
	rider_changed.emit(null)


func summon_to(world_position: Vector3) -> bool:
	if rider != null:
		return false
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	summon_target = world_position
	summon_state = "ANSWERING"
	summon_state_changed.emit(summon_state)
	return true


func dismiss() -> bool:
	if rider != null:
		return false
	current_speed = 0.0
	velocity = Vector3.ZERO
	summon_state = "DISMISSED"
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	summon_state_changed.emit(summon_state)
	return true


func restore_to_home() -> void:
	if rider != null:
		clear_rider()
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	global_position = home_position
	rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	mount_stamina = maximum_stamina
	summon_state = "READY"
	summon_state_changed.emit(summon_state)


func get_seat_transform() -> Transform3D:
	return seat.global_transform if seat != null else global_transform


func get_dismount_position(prefer_right: bool = true) -> Vector3:
	var marker: Marker3D = right_dismount if prefer_right else left_dismount
	return marker.global_position if marker != null else global_position + global_basis.x * 1.4


func get_summon_contract() -> Dictionary:
	return {
		"summonable": true,
		"state": summon_state,
		"display_name": display_name,
		"can_summon": rider == null,
		"target": summon_target,
	}


func get_debug_data() -> Dictionary:
	return {
		"name": display_name,
		"gait": current_gait,
		"speed": snappedf(absf(current_speed), 0.1),
		"stamina": snappedf(mount_stamina, 0.1),
		"maximum_stamina": maximum_stamina,
		"rider": rider != null,
		"summon_state": summon_state,
		"steering": snappedf(steering_input, 0.01),
		"impact": snappedf(last_impact_speed, 0.1),
	}


func _process_summon(delta: float) -> void:
	var offset: Vector3 = summon_target - global_position
	offset.y = 0.0
	if offset.length() <= summon_arrival_distance:
		current_speed = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		summon_state = "READY"
		_set_gait("IDLE")
		summon_state_changed.emit(summon_state)
		return
	var direction: Vector3 = offset.normalized()
	var target_yaw: float = atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))
	current_speed = move_toward(current_speed, summon_speed, acceleration * delta)
	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1
	move_and_slide()
	_set_gait("SUMMONING")


func _apply_idle_physics(delta: float) -> void:
	current_speed = move_toward(current_speed, 0.0, braking * delta)
	velocity.x = -global_basis.z.x * current_speed
	velocity.z = -global_basis.z.z * current_speed
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1
	move_and_slide()
	_set_gait("IDLE")


func _check_collisions(pre_move_speed: float) -> void:
	last_impact_speed = 0.0
	for index: int in get_slide_collision_count():
		var collision: KinematicCollision3D = get_slide_collision(index)
		var normal: Vector3 = collision.get_normal()
		var impact: float = pre_move_speed * absf((-global_basis.z).dot(normal))
		last_impact_speed = maxf(last_impact_speed, impact)
	if last_impact_speed >= severe_collision_speed:
		current_speed *= 0.18
		severe_collision.emit(last_impact_speed)


func _resolve_gait() -> String:
	var speed: float = absf(current_speed)
	if not is_on_floor():
		return "JUMP"
	if speed < 0.2:
		return "IDLE"
	if current_speed < 0.0:
		return "REVERSE"
	if speed <= walk_speed + 0.35:
		return "WALK"
	if speed <= trot_speed + 0.6:
		return "TROT"
	return "GALLOP"


func _set_gait(next_gait: String) -> void:
	if next_gait == current_gait:
		return
	current_gait = next_gait
	gait_changed.emit(current_gait)


func _build_mount_body() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.62
	shape.height = 2.4
	collision.shape = shape
	collision.rotation_degrees.x = 90.0
	collision.position.y = 1.05
	add_child(collision)

	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(0.17, 0.065, 0.035)
	body_material.roughness = 0.82
	var accent_material := StandardMaterial3D.new()
	accent_material.albedo_color = Color(0.74, 0.4, 0.12)
	accent_material.metallic = 0.45
	accent_material.roughness = 0.36

	_add_mesh("Body", CapsuleMesh.new(), Vector3(0, 1.12, 0), Vector3(0.78, 0.72, 1.32), body_material)
	_add_mesh("Chest", SphereMesh.new(), Vector3(0, 1.3, -0.78), Vector3(0.66, 0.8, 0.7), body_material)
	_add_mesh("Neck", CylinderMesh.new(), Vector3(0, 1.85, -0.98), Vector3(0.4, 0.8, 0.4), body_material, Vector3(-0.35, 0, 0))
	_add_mesh("Head", CapsuleMesh.new(), Vector3(0, 2.3, -1.25), Vector3(0.45, 0.42, 0.72), body_material, Vector3(PI * 0.5, 0, 0))
	for leg_x: float in [-0.43, 0.43]:
		for leg_z: float in [-0.65, 0.72]:
			_add_mesh("Leg", CylinderMesh.new(), Vector3(leg_x, 0.48, leg_z), Vector3(0.18, 0.78, 0.18), body_material)
	_add_mesh("Saddle", BoxMesh.new(), Vector3(0, 1.78, 0.08), Vector3(0.92, 0.18, 0.9), accent_material)
	_add_mesh("Reins", TorusMesh.new(), Vector3(0, 2.0, -0.73), Vector3(0.62, 0.55, 0.62), accent_material, Vector3(PI * 0.5, 0, 0))

	seat = Marker3D.new()
	seat.name = "Seat"
	seat.position = Vector3(0, 2.08, 0.05)
	add_child(seat)
	left_dismount = Marker3D.new()
	left_dismount.name = "LeftDismount"
	left_dismount.position = Vector3(-1.45, 0.2, 0)
	add_child(left_dismount)
	right_dismount = Marker3D.new()
	right_dismount.name = "RightDismount"
	right_dismount.position = Vector3(1.45, 0.2, 0)
	add_child(right_dismount)

	var prompt := Label3D.new()
	prompt.name = "MountPrompt"
	prompt.text = display_name + "\nINTERACT TO RIDE"
	prompt.position = Vector3(0, 3.05, 0)
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.font_size = 26
	prompt.pixel_size = 0.006
	prompt.outline_size = 8
	prompt.modulate = Color(1.0, 0.72, 0.22)
	add_child(prompt)


func _add_mesh(mesh_name: String, mesh: PrimitiveMesh, position: Vector3, scale_value: Vector3, material: Material, rotation_value: Vector3 = Vector3.ZERO) -> void:
	var visual := MeshInstance3D.new()
	visual.name = mesh_name
	visual.mesh = mesh
	visual.position = position
	visual.scale = scale_value
	visual.rotation = rotation_value
	visual.material_override = material
	add_child(visual)
