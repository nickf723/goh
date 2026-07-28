extends "res://scripts/player/player_controller.gd"

@export_range(0.0, 1.0, 0.01) var unlocked_cast_max_upward_component: float = 0.45

var combat_motion_velocity: Vector3 = Vector3.ZERO
var combat_motion_timer: float = 0.0

@onready var aerial_locomotion: PlayerAerialLocomotion = get_node_or_null("AerialLocomotion") as PlayerAerialLocomotion
@onready var metal_tether_controller: Node = get_node_or_null("MetalTetherController")
@onready var defense_controller: PlayerDefenseController = get_node_or_null("PlayerDefenseController") as PlayerDefenseController
@onready var climbing_controller: PlayerClimbingController = get_node_or_null("ClimbingController") as PlayerClimbingController
@onready var swimming_controller: PlayerSwimmingController = get_node_or_null("SwimmingController") as PlayerSwimmingController
@onready var riding_controller: PlayerRidingController = get_node_or_null("RidingController") as PlayerRidingController
@onready var step_up_controller: PlayerStepUpController = get_node_or_null("StepUpController") as PlayerStepUpController


func get_lock_on_cast_direction(cast_origin: Vector3 = Vector3.ZERO) -> Vector3:
	if has_lock_on_target():
		return super.get_lock_on_cast_direction(cast_origin)

	var soft_direction: Vector3 = super.get_soft_aim_cast_direction(cast_origin)
	if soft_direction.length() > 0.01:
		return soft_direction.normalized()

	var cast_direction: Vector3 = -global_transform.basis.z
	var camera: Camera3D = get_viewport().get_camera_3d()

	if camera != null:
		cast_direction = -camera.global_transform.basis.z

	# The third-person camera normally looks slightly down at Grace. Passing that
	# full pitch to a chest-height projectile sends unlocked casts into the floor.
	# Keep camera-relative heading and upward aim, but make downward free aim level.
	cast_direction.y = clamp(cast_direction.y, 0.0, unlocked_cast_max_upward_component)

	if cast_direction.length() <= 0.01:
		cast_direction = -global_transform.basis.z
		cast_direction.y = 0.0

	if cast_direction.length() <= 0.01:
		return Vector3.FORWARD

	return cast_direction.normalized()


func begin_combat_motion(direction: Vector3, distance: float, duration: float) -> void:
	if distance <= 0.0 or duration <= 0.0:
		return

	var horizontal_direction: Vector3 = direction
	horizontal_direction.y = 0.0

	if horizontal_direction.length() <= 0.01:
		return

	combat_motion_timer = duration
	var desired_velocity: Vector3 = horizontal_direction.normalized() * (distance / duration)
	var existing_velocity := Vector3(velocity.x, 0.0, velocity.z)
	# Preserve part of Grace's current movement when an attack lunge begins. This
	# avoids a one-frame velocity corner while still converging decisively on the
	# authored attack motion.
	if existing_velocity.length() > 0.1:
		combat_motion_velocity = existing_velocity.lerp(desired_velocity, 0.68)
	else:
		combat_motion_velocity = desired_velocity


func cancel_combat_motion() -> void:
	combat_motion_timer = 0.0
	combat_motion_velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if defense_controller != null and defense_controller.is_hit_reaction_active():
		cancel_combat_motion()
		velocity = defense_controller.get_hit_reaction_velocity()
		if not is_on_floor():
			velocity.y -= gravity * delta
		elif velocity.y < 0.0:
			velocity.y = -0.1
		move_and_slide()
		return

	if riding_controller != null and riding_controller.should_handle_locomotion():
		cancel_combat_motion()
		if riding_controller.process_locomotion(delta):
			return

	if swimming_controller != null and swimming_controller.should_handle_locomotion():
		cancel_combat_motion()
		if swimming_controller.process_locomotion(delta):
			return

	if climbing_controller != null:
		climbing_controller.update_climb_detection()
		if climbing_controller.should_handle_locomotion():
			cancel_combat_motion()
			if climbing_controller.process_locomotion(delta):
				return

	if (
		metal_tether_controller != null
		and metal_tether_controller.has_method("should_handle_locomotion")
		and bool(metal_tether_controller.call("should_handle_locomotion"))
	):
		cancel_combat_motion()
		if bool(metal_tether_controller.call("process_locomotion", delta)):
			return

	if aerial_locomotion != null and aerial_locomotion.flight_active:
		cancel_combat_motion()
		if aerial_locomotion.process_locomotion(delta):
			return

	if dodge_controller != null and dodge_controller.is_dodge_active():
		cancel_combat_motion()
		_try_step_up(dodge_controller.get_dodge_velocity(), delta)
		super._physics_process(delta)
		_finish_step_up()
		return

	if combat_motion_timer <= 0.0:
		if aerial_locomotion != null and aerial_locomotion.process_locomotion(delta):
			return
		_try_step_up(_get_requested_ground_velocity(), delta)
		super._physics_process(delta)
		_finish_step_up()
		return

	if is_defeated:
		cancel_combat_motion()
		super._physics_process(delta)
		return

	combat_motion_timer -= delta
	velocity.x = combat_motion_velocity.x
	velocity.z = combat_motion_velocity.z

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1

	_try_step_up(combat_motion_velocity, delta)
	move_and_slide()
	_finish_step_up()

	if combat_motion_timer <= 0.0:
		cancel_combat_motion()


func _get_requested_ground_velocity() -> Vector3:
	var input_vector: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)
	if input_vector.length() <= 0.01:
		return Vector3(velocity.x, 0.0, velocity.z)

	var direction: Vector3 = (
		global_transform.basis.x * input_vector.x
		+ global_transform.basis.z * input_vector.y
	)
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		return Vector3.ZERO
	return direction.normalized() * move_speed


func _try_step_up(horizontal_velocity: Vector3, delta: float) -> bool:
	if step_up_controller == null:
		return false
	return step_up_controller.try_step_up(horizontal_velocity, delta)


func _finish_step_up() -> void:
	if step_up_controller != null:
		step_up_controller.finish_step()


func get_combat_motion_debug_data() -> Dictionary:
	return {
		"combat_motion": snapped(combat_motion_timer, 0.01),
		"combat_velocity": combat_motion_velocity,
		"step_up": step_up_controller.get_debug_data() if step_up_controller != null else {},
	}
