extends "res://scripts/player/player_controller.gd"

const GameplayEffectAccessFreeAimScript = preload(
	"res://scripts/effects/gameplay_effect_access.gd"
)

@export_range(0.0, 1.0, 0.01) var unlocked_cast_max_upward_component: float = 0.45

var combat_motion_velocity: Vector3 = Vector3.ZERO
var combat_motion_timer: float = 0.0
var dodge_exit_pending: bool = false

@onready var aerial_locomotion: PlayerAerialLocomotion = get_node_or_null("AerialLocomotion") as PlayerAerialLocomotion
@onready var metal_tether_controller: Node = get_node_or_null("MetalTetherController")
@onready var defense_controller: PlayerDefenseController = get_node_or_null("PlayerDefenseController") as PlayerDefenseController
@onready var climbing_controller: PlayerClimbingController = get_node_or_null("ClimbingController") as PlayerClimbingController
@onready var swimming_controller: PlayerSwimmingController = get_node_or_null("SwimmingController") as PlayerSwimmingController
@onready var riding_controller: PlayerRidingController = get_node_or_null("RidingController") as PlayerRidingController
@onready var step_up_controller: PlayerStepUpController = get_node_or_null("StepUpController") as PlayerStepUpController
@onready var ground_motion_motor: PlayerGroundMotionMotor = get_node_or_null("GroundMotionMotor") as PlayerGroundMotionMotor
@onready var combat_footwork_controller: PlayerCombatFootworkController = (
	get_node_or_null("CombatFootworkController") as PlayerCombatFootworkController
)
@onready var shared_weapon_controller: WeaponController = get_node_or_null("WeaponController") as WeaponController


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

	dodge_exit_pending = false
	if (
		is_on_floor()
		and combat_footwork_controller != null
		and shared_weapon_controller != null
		and shared_weapon_controller.current_attack != null
		and combat_footwork_controller.can_handle_attack(
			shared_weapon_controller.current_attack
		)
	):
		var current_planar_velocity := Vector3(velocity.x, 0.0, velocity.z)
		if combat_footwork_controller.begin_attack(
			shared_weapon_controller.current_attack,
			horizontal_direction,
			shared_weapon_controller.get_attack_speed(),
			current_planar_velocity,
			duration
		):
			combat_motion_timer = 0.0
			combat_motion_velocity = Vector3.ZERO
			return

	combat_motion_timer = duration
	var desired_velocity: Vector3 = horizontal_direction.normalized() * (distance / duration)
	var existing_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if existing_velocity.length() > 0.1:
		var retention: float = ground_motion_motor.get_attack_momentum_retention() if ground_motion_motor != null else 0.32
		combat_motion_velocity = existing_velocity * retention + desired_velocity * (1.0 - retention)
	else:
		combat_motion_velocity = desired_velocity


func cancel_combat_motion(reason: String = "cancelled") -> void:
	combat_motion_timer = 0.0
	combat_motion_velocity = Vector3.ZERO
	if combat_footwork_controller != null:
		combat_footwork_controller.cancel_footwork(reason)


func _physics_process(delta: float) -> void:
	if defense_controller != null and defense_controller.is_hit_reaction_active():
		cancel_combat_motion("hit_reaction")
		dodge_exit_pending = false
		velocity = defense_controller.get_hit_reaction_velocity()
		if ground_motion_motor != null:
			ground_motion_motor.capture_external_velocity(velocity, "hit")
		if not is_on_floor():
			velocity.y -= gravity * delta
		elif velocity.y < 0.0:
			velocity.y = -0.1
		move_and_slide()
		_record_motion()
		return
	if riding_controller != null and riding_controller.should_handle_locomotion():
		cancel_combat_motion("riding")
		dodge_exit_pending = false
		if riding_controller.process_locomotion(delta):
			return
	if swimming_controller != null and swimming_controller.should_handle_locomotion():
		cancel_combat_motion("swimming")
		dodge_exit_pending = false
		if swimming_controller.process_locomotion(delta):
			return
	if climbing_controller != null:
		climbing_controller.update_climb_detection()
		if climbing_controller.should_handle_locomotion():
			cancel_combat_motion("climbing")
			dodge_exit_pending = false
			if climbing_controller.process_locomotion(delta):
				return
	if metal_tether_controller != null and metal_tether_controller.has_method("should_handle_locomotion") and bool(metal_tether_controller.call("should_handle_locomotion")):
		cancel_combat_motion("metal_tether")
		dodge_exit_pending = false
		if bool(metal_tether_controller.call("process_locomotion", delta)):
			return
	if aerial_locomotion != null and aerial_locomotion.flight_active:
		cancel_combat_motion("flight")
		dodge_exit_pending = false
		if aerial_locomotion.process_locomotion(delta):
			return
	if dodge_controller != null and dodge_controller.is_dodge_active():
		cancel_combat_motion("dodge")
		dodge_exit_pending = true
		var dodge_velocity: Vector3 = dodge_controller.get_dodge_velocity()
		if ground_motion_motor != null:
			ground_motion_motor.capture_external_velocity(dodge_velocity, "dodge")
		_try_step_up(dodge_velocity, delta)
		super._physics_process(delta)
		_finish_step_up()
		_record_motion()
		return
	if is_defeated:
		cancel_combat_motion("defeated")
		dodge_exit_pending = false
		if ground_motion_motor != null:
			ground_motion_motor.reset_motion()
		super._physics_process(delta)
		return
	if combat_footwork_controller != null and combat_footwork_controller.is_root_motion_active():
		_process_combat_footwork(delta)
		return
	if combat_motion_timer <= 0.0:
		if aerial_locomotion != null and aerial_locomotion.process_locomotion(delta):
			return
		_process_standard_motion(delta)
		return

	combat_motion_timer -= delta
	velocity.x = combat_motion_velocity.x
	velocity.z = combat_motion_velocity.z
	if ground_motion_motor != null:
		ground_motion_motor.capture_external_velocity(combat_motion_velocity, "attack")
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1
	_try_step_up(combat_motion_velocity, delta)
	move_and_slide()
	_finish_step_up()
	_record_motion()
	if combat_motion_timer <= 0.0:
		combat_motion_timer = 0.0
		combat_motion_velocity = Vector3.ZERO


func _process_combat_footwork(delta: float) -> void:
	var footwork_velocity: Vector3 = combat_footwork_controller.sample_root_velocity(delta)
	velocity.x = footwork_velocity.x
	velocity.z = footwork_velocity.z
	if ground_motion_motor != null:
		ground_motion_motor.capture_external_velocity(footwork_velocity, "attack_footwork")
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1
	var before_position: Vector3 = global_position
	_try_step_up(footwork_velocity, delta)
	move_and_slide()
	_finish_step_up()
	combat_footwork_controller.record_post_move(before_position, global_position, delta)
	_record_motion()


func _process_standard_motion(delta: float) -> void:
	if is_defeated:
		velocity = Vector3.ZERO
		dodge_exit_pending = false
		if ground_motion_motor != null:
			ground_motion_motor.reset_motion()
		move_and_slide()
		return
	var requested: Vector3 = _get_requested_ground_velocity()
	var current := Vector3(velocity.x, 0.0, velocity.z)
	if dodge_exit_pending:
		var retention: float = ground_motion_motor.get_dodge_exit_momentum_retention() if ground_motion_motor != null else 0.68
		current *= retention
		velocity.x = current.x
		velocity.z = current.z
		dodge_exit_pending = false
	var resolved: Vector3 = requested
	if ground_motion_motor != null:
		resolved = ground_motion_motor.resolve_planar_velocity(current, requested, is_on_floor(), delta)
	velocity.x = resolved.x
	velocity.z = resolved.z
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		var item_allows_jump: bool = true
		if quick_item_controller != null and quick_item_controller.has_method("allows_jump"):
			item_allows_jump = bool(quick_item_controller.call("allows_jump"))
		if item_allows_jump and Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	_try_step_up(requested, delta)
	move_and_slide()
	_finish_step_up()
	_record_motion()


func _get_requested_ground_velocity() -> Vector3:
	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var movement_multiplier: float = 1.0
	if quick_item_controller != null and quick_item_controller.has_method("get_movement_multiplier"):
		movement_multiplier = float(quick_item_controller.call("get_movement_multiplier"))
	if stealth_controller != null and stealth_controller.has_method("get_movement_multiplier"):
		movement_multiplier *= float(stealth_controller.call("get_movement_multiplier"))
	var configured_speed: float = move_speed
	if ground_motion_motor != null:
		configured_speed = ground_motion_motor.get_configured_maximum_speed(move_speed)
	var effective_speed: float = GameplayEffectAccessFreeAimScript.modify_float(
		"movement_speed",
		configured_speed
	) * movement_multiplier
	if ground_motion_motor != null:
		return ground_motion_motor.get_desired_velocity(input_vector, effective_speed, has_lock_on_target())
	if input_vector.length() <= 0.01:
		return Vector3.ZERO
	var direction: Vector3 = global_transform.basis.x * input_vector.x + global_transform.basis.z * input_vector.y
	direction.y = 0.0
	return direction.normalized() * effective_speed if direction.length_squared() > 0.0001 else Vector3.ZERO


func _try_step_up(horizontal_velocity: Vector3, delta: float) -> bool:
	return step_up_controller != null and step_up_controller.try_step_up(horizontal_velocity, delta)


func _finish_step_up() -> void:
	if step_up_controller != null:
		step_up_controller.finish_step()


func _record_motion() -> void:
	if ground_motion_motor != null:
		ground_motion_motor.record_post_move(Vector3(velocity.x, 0.0, velocity.z))


func get_combat_motion_debug_data() -> Dictionary:
	return {
		"combat_motion": snapped(combat_motion_timer, 0.01),
		"combat_velocity": combat_motion_velocity,
		"dodge_exit_pending": dodge_exit_pending,
		"step_up": step_up_controller.get_debug_data() if step_up_controller != null else {},
		"ground_motion": ground_motion_motor.get_debug_data() if ground_motion_motor != null else {},
		"combat_footwork": combat_footwork_controller.get_debug_data() if combat_footwork_controller != null else {},
	}
