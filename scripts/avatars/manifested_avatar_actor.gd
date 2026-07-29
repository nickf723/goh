extends CharacterBody3D
class_name ManifestedAvatarActor

signal manifestation_ready(actor: ManifestedAvatarActor)
signal manifestation_defeated(actor: ManifestedAvatarActor)
signal dismissal_requested(actor: ManifestedAvatarActor, reason: String)
signal control_action_executed(action_kind: String, action_id: String, success: bool)
signal recalled(actor: ManifestedAvatarActor, reason: String)
signal health_changed(current: int, maximum: int)

@export var avatar_definition: PlayableAvatarDefinition
@export var auto_initialize_from_scene: bool = false

@export_group("Manifested Body")
@export_range(1, 500, 1) var maximum_health: int = 42
@export_range(1.0, 40.0, 0.5) var gravity: float = 18.0
@export_range(1.0, 60.0, 0.5) var hard_recall_distance: float = 22.0
@export_range(0.2, 5.0, 0.05) var stuck_recall_seconds: float = 1.35
@export_range(0.001, 0.2, 0.005) var stuck_distance_epsilon: float = 0.018
@export_range(1.0, 20.0, 0.5) var facing_response: float = 10.0

var owner_actor: Node3D
var manifestation_manager: Node
var active_control_driver: AvatarControlDriver
var lock_on_target: Node3D
var current_health: int = 42
var initialized: bool = false
var defeated: bool = false
var dismissal_in_progress: bool = false
var last_intent: AvatarActionIntent = AvatarActionIntent.new()
var last_control_action_kind: String = "none"
var last_control_action_id: String = "none"
var last_control_action_success: bool = false
var last_recall_reason: String = "none"
var recall_count: int = 0
var stuck_timer: float = 0.0
var last_physics_displacement: Vector3 = Vector3.ZERO
var combat_motion_velocity: Vector3 = Vector3.ZERO
var combat_motion_timer: float = 0.0
var preserved_step_velocity: Vector3 = Vector3.ZERO
var restore_step_velocity_after_move: bool = false

@onready var visual: GraceElementalAuthorityMotionVisual = (
	get_node_or_null("GraceVisualV1") as GraceElementalAuthorityMotionVisual
)
@onready var wire_renderer: AvatarWireSkeletonRenderer = (
	get_node_or_null("GraceVisualV1/WireSkeletonRenderer") as AvatarWireSkeletonRenderer
)
@onready var step_up_controller: PlayerStepUpController = (
	get_node_or_null("StepUpController") as PlayerStepUpController
)
@onready var ground_motion_motor: PlayerGroundMotionMotor = (
	get_node_or_null("GroundMotionMotor") as PlayerGroundMotionMotor
)
@onready var vertical_motion_controller: PlayerVerticalMotionController = (
	get_node_or_null("VerticalMotionController") as PlayerVerticalMotionController
)
@onready var combat_footwork_controller: ManifestedCombatFootworkController = (
	get_node_or_null("CombatFootworkController") as ManifestedCombatFootworkController
)
@onready var authority_controller: ManifestedElementalAuthorityController = (
	get_node_or_null("ElementalAuthorityController") as ManifestedElementalAuthorityController
)
@onready var status_receiver: ManifestedAvatarStatusReceiver = (
	get_node_or_null("StatusReceiver") as ManifestedAvatarStatusReceiver
)
@onready var weapon_controller: ManifestedWeaponController = (
	get_node_or_null("WeaponController") as ManifestedWeaponController
)
@onready var weapon_animator: PlayerWeaponControlAnimatorAuthority = (
	get_node_or_null("PlayerWeaponControlAnimator") as PlayerWeaponControlAnimatorAuthority
)
@onready var action_state: PlayerActionState = (
	get_node_or_null("PlayerActionState") as PlayerActionState
)
@onready var dodge_controller: ManifestedDodgeController = (
	get_node_or_null("PlayerDodgeController") as ManifestedDodgeController
)
@onready var companion_driver: CompanionAvatarControlDriver = (
	get_node_or_null("CompanionControlDriver") as CompanionAvatarControlDriver
)


func _ready() -> void:
	process_priority = 18
	add_to_group("manifested_avatar")
	add_to_group("friendly_actor")
	add_to_group("combat_targetable")
	add_to_group("debuggable")
	if auto_initialize_from_scene and avatar_definition != null:
		call_deferred(
			"initialize_manifestation",
			avatar_definition,
			owner_actor,
			manifestation_manager,
			null
		)


func initialize_manifestation(
	definition: PlayableAvatarDefinition,
	owner: Node3D,
	manager: Node,
	driver_override: AvatarControlDriver = null
) -> Array[String]:
	var failures: Array[String] = []
	if definition == null:
		failures.append("manifested avatar definition is missing")
		return failures
	failures.append_array(definition.validate_definition())
	if owner == null or not is_instance_valid(owner):
		failures.append(definition.avatar_id + ": manifestation owner is missing")
	if not _has_required_components():
		failures.append(definition.avatar_id + ": manifested actor components are incomplete")
	if not failures.is_empty():
		return failures

	avatar_definition = definition
	owner_actor = owner
	manifestation_manager = manager
	current_health = maximum_health
	defeated = false
	dismissal_in_progress = false
	lock_on_target = null
	stuck_timer = 0.0
	combat_motion_timer = 0.0
	combat_motion_velocity = Vector3.ZERO
	_set_avatar_metadata(definition)

	ground_motion_motor.profile = definition.ground_motion_profile
	vertical_motion_controller.profile = definition.vertical_motion_profile
	dodge_controller.profile = definition.dodge_motion_profile
	combat_footwork_controller.profile = definition.combat_footwork_profile
	weapon_controller.equip_weapon(definition.weapon_definition)
	authority_controller.set_authority_profile(definition.elemental_authority_profile)
	if not wire_renderer.set_avatar_presentation(definition):
		failures.append(definition.avatar_id + ": wire presentation rejected the definition")
	if not failures.is_empty():
		return failures

	active_control_driver = driver_override if driver_override != null else companion_driver
	if active_control_driver == null:
		failures.append(definition.avatar_id + ": control driver is missing")
		return failures
	if active_control_driver.get_parent() == null:
		add_child(active_control_driver)
	active_control_driver.bind_actor(self, owner_actor)
	active_control_driver.set_driver_enabled(true)
	_apply_owner_collision_exceptions()

	initialized = true
	health_changed.emit(current_health, maximum_health)
	manifestation_ready.emit(self)
	return failures


func _set_avatar_metadata(definition: PlayableAvatarDefinition) -> void:
	set_meta("active_avatar_id", definition.avatar_id)
	set_meta("active_avatar_display_name", definition.display_name)
	set_meta("active_avatar_element", definition.element)
	set_meta("avatar_anchor_mode", "autonomous_manifestation")
	set_meta("manifestation_owner_instance_id", owner_actor.get_instance_id())
	set_meta(
		"manifestation_manager_instance_id",
		manifestation_manager.get_instance_id() if manifestation_manager != null else -1
	)


func _apply_owner_collision_exceptions() -> void:
	if not (owner_actor is PhysicsBody3D):
		return
	var owner_body: PhysicsBody3D = owner_actor as PhysicsBody3D
	add_collision_exception_with(owner_body)
	owner_body.add_collision_exception_with(self)


func _physics_process(delta: float) -> void:
	if not initialized or dismissal_in_progress:
		velocity = Vector3.ZERO
		return
	if defeated:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	if owner_actor == null or not is_instance_valid(owner_actor):
		request_dismissal("owner_missing")
		return
	if global_position.distance_to(owner_actor.global_position) > hard_recall_distance:
		recall_to_owner("separation")

	var intent: AvatarActionIntent = active_control_driver.sample_intent(delta)
	last_intent.copy_from(intent)
	if intent.recall_requested:
		recall_to_owner(intent.action_reason if intent.action_reason != "" else "driver_recall")
		return
	lock_on_target = intent.target if _valid_target(intent.target) else null
	dodge_controller.set_external_steering_direction(intent.movement_direction)
	combat_footwork_controller.set_external_steering_direction(intent.facing_direction)
	_execute_action_request(intent)
	_apply_facing(intent.facing_direction, delta)

	var before_position: Vector3 = global_position
	_process_motion(intent, delta)
	last_physics_displacement = global_position - before_position
	_update_stuck_recall(intent, delta)


func _process_motion(intent: AvatarActionIntent, delta: float) -> void:
	if status_receiver.blocks_actions():
		combat_motion_timer = 0.0
		combat_motion_velocity = Vector3.ZERO
		velocity.x = move_toward(velocity.x, 0.0, 28.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 28.0 * delta)
		_move_and_settle(delta, Vector3(velocity.x, 0.0, velocity.z))
		return

	if combat_footwork_controller.is_root_motion_active():
		var footwork_velocity: Vector3 = combat_footwork_controller.sample_root_velocity(delta)
		velocity.x = footwork_velocity.x
		velocity.z = footwork_velocity.z
		ground_motion_motor.capture_external_velocity(footwork_velocity, "manifestation_footwork")
		var before_footwork: Vector3 = global_position
		_move_and_settle(delta, footwork_velocity)
		combat_footwork_controller.record_post_move(before_footwork, global_position, delta)
		return

	if dodge_controller.is_dodge_active():
		var dodge_velocity: Vector3 = dodge_controller.get_dodge_velocity()
		velocity.x = dodge_velocity.x
		velocity.z = dodge_velocity.z
		ground_motion_motor.capture_external_velocity(dodge_velocity, "manifestation_dodge")
		_move_and_settle(delta, dodge_velocity)
		return

	if combat_motion_timer > 0.0:
		combat_motion_timer = maxf(combat_motion_timer - delta, 0.0)
		velocity.x = combat_motion_velocity.x
		velocity.z = combat_motion_velocity.z
		ground_motion_motor.capture_external_velocity(combat_motion_velocity, "manifestation_attack")
		_move_and_settle(delta, combat_motion_velocity)
		if combat_motion_timer <= 0.0:
			combat_motion_velocity = Vector3.ZERO
		return

	var requested_velocity: Vector3 = _get_requested_velocity(intent)
	var current_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var resolved: Vector3 = ground_motion_motor.resolve_planar_velocity(
		current_velocity,
		requested_velocity,
		is_on_floor(),
		delta
	)
	velocity.x = resolved.x
	velocity.z = resolved.z
	_move_and_settle(delta, resolved)


func _move_and_settle(delta: float, planar_velocity: Vector3) -> void:
	var was_grounded: bool = is_on_floor()
	vertical_motion_controller.prepare_frame(delta, was_grounded, false)
	if not was_grounded:
		vertical_motion_controller.apply_gravity(delta, gravity)
	elif velocity.y < 0.0:
		velocity.y = -0.1
	vertical_motion_controller.note_pre_move_velocity()
	var stepped: bool = _try_step_up(planar_velocity, delta)
	move_and_slide()
	_finish_step_up(stepped)
	vertical_motion_controller.record_post_move(was_grounded)
	ground_motion_motor.record_post_move(Vector3(velocity.x, 0.0, velocity.z))


func _try_step_up(planar_velocity: Vector3, delta: float) -> bool:
	restore_step_velocity_after_move = false
	preserved_step_velocity = Vector3.ZERO
	var actual: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	if actual.length_squared() <= 0.0001:
		actual = planar_velocity
		actual.y = 0.0
	if not step_up_controller.try_step_up(actual, delta):
		return false
	preserved_step_velocity = actual
	velocity.x = 0.0
	velocity.z = 0.0
	restore_step_velocity_after_move = true
	return true


func _finish_step_up(stepped: bool) -> void:
	if stepped:
		step_up_controller.finish_step()
	if not restore_step_velocity_after_move:
		return
	velocity.x = preserved_step_velocity.x
	velocity.z = preserved_step_velocity.z
	preserved_step_velocity = Vector3.ZERO
	restore_step_velocity_after_move = false


func _get_requested_velocity(intent: AvatarActionIntent) -> Vector3:
	if intent == null or intent.movement_direction.length_squared() <= 0.0001:
		return Vector3.ZERO
	var maximum_speed: float = ground_motion_motor.get_configured_maximum_speed(5.0)
	return (
		intent.movement_direction.normalized()
		* maximum_speed
		* clampf(intent.movement_strength, 0.0, 1.0)
		* clampf(status_receiver.get_movement_multiplier(), 0.0, 1.0)
	)


func _execute_action_request(intent: AvatarActionIntent) -> void:
	if intent == null or not intent.has_action_request():
		return
	if intent.dodge_requested:
		var dodge_direction: Vector3 = intent.dodge_direction
		if dodge_direction.length_squared() <= 0.001:
			dodge_direction = -global_transform.basis.z
		_report_action_result(
			"dodge",
			intent.dodge_kind,
			dodge_controller.begin_dodge_in_direction(dodge_direction, intent.dodge_kind, false)
		)
		return
	if intent.spell_id != "":
		var ability: AbilityDefinition = _find_ability(intent.spell_id)
		_report_action_result(
			"spell",
			intent.spell_id,
			authority_controller.begin_ability_channel(self, ability) if ability != null else false
		)
		return
	if intent.attack_id != "":
		var attack: WeaponAttackDefinition = _find_attack(intent.attack_id)
		_report_action_result(
			"attack",
			intent.attack_id,
			weapon_controller.start_attack(attack) if attack != null else false
		)
		return
	if intent.guard_requested:
		_report_action_result("guard", "guard", false)


func _report_action_result(action_kind: String, action_id: String, success: bool) -> void:
	last_control_action_kind = action_kind
	last_control_action_id = action_id
	last_control_action_success = success
	active_control_driver.notify_action_result(action_kind, action_id, success)
	control_action_executed.emit(action_kind, action_id, success)


func _find_attack(attack_id: String) -> WeaponAttackDefinition:
	var moveset: WeaponMovesetDefinition = weapon_controller.get_moveset()
	return moveset.get_attack(attack_id) if moveset != null and attack_id != "" else null


func _find_ability(spell_id: String) -> AbilityDefinition:
	if avatar_definition == null or avatar_definition.ability_loadout == null:
		return null
	for ability_index: int in range(avatar_definition.ability_loadout.get_equipped_ability_count()):
		var ability: AbilityDefinition = avatar_definition.ability_loadout.get_equipped_ability(ability_index)
		if ability != null and ability.get_spell_id() == spell_id:
			return ability
	return null


func can_accept_control_action() -> bool:
	if not initialized or defeated or dismissal_in_progress or status_receiver.blocks_actions():
		return false
	if weapon_controller.current_attack != null or dodge_controller.is_dodge_active():
		return false
	return not action_state.is_casting and not action_state.is_staggered and not action_state.is_defeated


func begin_combat_motion(direction: Vector3, distance: float, duration: float) -> void:
	if distance <= 0.0 or duration <= 0.0:
		return
	var planar: Vector3 = direction
	planar.y = 0.0
	if planar.length_squared() <= 0.001:
		return
	planar = planar.normalized()
	if (
		is_on_floor()
		and weapon_controller.current_attack != null
		and combat_footwork_controller.can_handle_attack(weapon_controller.current_attack)
		and combat_footwork_controller.begin_attack(
			weapon_controller.current_attack,
			planar,
			weapon_controller.get_attack_speed(),
			Vector3(velocity.x, 0.0, velocity.z),
			duration
		)
	):
		combat_motion_timer = 0.0
		combat_motion_velocity = Vector3.ZERO
		return
	combat_motion_timer = duration
	combat_motion_velocity = planar * (distance / duration)


func cancel_combat_motion(reason: String = "cancelled") -> void:
	combat_motion_timer = 0.0
	combat_motion_velocity = Vector3.ZERO
	combat_footwork_controller.cancel_footwork(reason)


func get_combat_aim_direction(origin: Vector3 = Vector3.ZERO, _allow_soft_target: bool = true) -> Vector3:
	if has_lock_on_target():
		var target_direction: Vector3 = _get_target_position(lock_on_target) - origin
		target_direction.y = 0.0
		if target_direction.length_squared() > 0.001:
			return target_direction.normalized()
	if last_intent.facing_direction.length_squared() > 0.001:
		return last_intent.facing_direction.normalized()
	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.001 else Vector3.FORWARD


func get_lock_on_cast_direction(origin: Vector3 = Vector3.ZERO) -> Vector3:
	return get_combat_aim_direction(origin, true)


func has_lock_on_target() -> bool:
	return _valid_target(lock_on_target)


func clear_lock_on() -> void:
	lock_on_target = null


func _apply_facing(direction: Vector3, delta: float) -> void:
	if direction.length_squared() <= 0.001:
		return
	if weapon_controller.current_attack != null or dodge_controller.is_dodge_active():
		return
	var planar: Vector3 = direction
	planar.y = 0.0
	if planar.length_squared() <= 0.001:
		return
	var target_yaw: float = atan2(-planar.normalized().x, -planar.normalized().z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * facing_response, 0.0, 1.0))


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if payload == null or defeated:
		return {}
	var resolved_payload: DamagePayload = payload
	var authority_result: Dictionary = authority_controller.resolve_incoming_payload(payload)
	if bool(authority_result.get("immune", false)):
		return {
			"outcome": "elemental_authority",
			"message": avatar_definition.display_name + " ignores " + payload.source_name + ".",
			"damage": 0,
			"stance_damage": 0,
			"objective": "",
		}
	var payload_value: Variant = authority_result.get("payload", payload)
	if payload_value is DamagePayload:
		resolved_payload = payload_value as DamagePayload
	var damage: int = maxi(resolved_payload.amount, 0)
	current_health = maxi(current_health - damage, 0)
	if resolved_payload.status_effect != "" and resolved_payload.status_duration > 0.0:
		status_receiver.apply_status(
			resolved_payload.status_effect,
			resolved_payload.status_duration,
			resolved_payload.status_strength,
			resolved_payload.source_name
		)
	health_changed.emit(current_health, maximum_health)
	if current_health <= 0:
		_defeat()
	return {
		"outcome": "hit",
		"message": avatar_definition.display_name + " takes " + str(damage) + " damage.",
		"damage": damage,
		"health_damage": damage,
		"objective": "",
	}


func heal_full() -> void:
	current_health = maximum_health
	health_changed.emit(current_health, maximum_health)


func is_target_defeated() -> bool:
	return defeated or current_health <= 0


func get_targeting_aim_point() -> Vector3:
	return global_position + Vector3.UP * 1.25


func request_dismissal(reason: String = "requested") -> void:
	if not dismissal_in_progress:
		dismissal_requested.emit(self, reason)


func recall_to_owner(reason: String = "recall") -> bool:
	if owner_actor == null or not is_instance_valid(owner_actor):
		return false
	var target_transform: Transform3D = global_transform
	var resolved: bool = false
	if manifestation_manager != null and manifestation_manager.has_method("get_safe_manifestation_transform"):
		var transform_value: Variant = manifestation_manager.call("get_safe_manifestation_transform", self)
		if transform_value is Transform3D:
			target_transform = transform_value as Transform3D
			resolved = true
	if not resolved:
		var offset: Vector3 = (
			owner_actor.global_transform.basis.x * 2.1
			+ owner_actor.global_transform.basis.z * 1.1
		)
		target_transform.origin = owner_actor.global_position + offset
	global_transform = target_transform
	velocity = Vector3.ZERO
	combat_motion_timer = 0.0
	combat_motion_velocity = Vector3.ZERO
	ground_motion_motor.reset_motion()
	vertical_motion_controller.reset_motion()
	if dodge_controller.is_dodge_active():
		dodge_controller.cancel_dodge("recall")
	combat_footwork_controller.cancel_footwork("recall")
	stuck_timer = 0.0
	recall_count += 1
	last_recall_reason = reason
	recalled.emit(self, reason)
	return true


func prepare_for_dismissal(reason: String = "dismissed") -> void:
	if dismissal_in_progress:
		return
	dismissal_in_progress = true
	active_control_driver.set_driver_enabled(false)
	if weapon_controller.current_attack != null:
		weapon_controller.cancel_current_attack(reason)
	if dodge_controller.is_dodge_active():
		dodge_controller.cancel_dodge(reason)
	combat_footwork_controller.cancel_footwork(reason)
	_cleanup_owned_fields()
	clear_lock_on()
	velocity = Vector3.ZERO


func _cleanup_owned_fields() -> int:
	var removed: int = 0
	for field: Node in authority_controller.get_owned_fields():
		if field != null and is_instance_valid(field):
			field.queue_free()
			removed += 1
	authority_controller.owned_fields.clear()
	authority_controller.last_owned_field = null
	return removed


func _defeat() -> void:
	if defeated:
		return
	defeated = true
	action_state.set_defeated(true)
	manifestation_defeated.emit(self)


func _update_stuck_recall(intent: AvatarActionIntent, delta: float) -> void:
	if intent.movement_direction.length_squared() <= 0.001:
		stuck_timer = maxf(stuck_timer - delta * 2.0, 0.0)
		return
	var planar_displacement: Vector3 = last_physics_displacement
	planar_displacement.y = 0.0
	var owner_distance: float = global_position.distance_to(owner_actor.global_position)
	if planar_displacement.length() <= stuck_distance_epsilon and owner_distance > 4.5:
		stuck_timer += maxf(delta, 0.0)
	else:
		stuck_timer = maxf(stuck_timer - delta * 2.0, 0.0)
	if stuck_timer >= stuck_recall_seconds:
		recall_to_owner("stuck_recovery")


func _has_required_components() -> bool:
	return (
		visual != null
		and wire_renderer != null
		and step_up_controller != null
		and ground_motion_motor != null
		and vertical_motion_controller != null
		and combat_footwork_controller != null
		and authority_controller != null
		and status_receiver != null
		and weapon_controller != null
		and weapon_animator != null
		and action_state != null
		and dodge_controller != null
		and companion_driver != null
	)


func _valid_target(target: Node3D) -> bool:
	return (
		target != null
		and is_instance_valid(target)
		and not target.is_queued_for_deletion()
		and target != self
		and target != owner_actor
		and not target.is_in_group("friendly_actor")
		and not target.is_in_group("player")
		and (
			not target.has_method("is_target_defeated")
			or not bool(target.call("is_target_defeated"))
		)
	)


func _get_target_position(target: Node) -> Vector3:
	if target is Node3D:
		if target.has_method("get_targeting_aim_point"):
			var aim_value: Variant = target.call("get_targeting_aim_point")
			if aim_value is Vector3:
				return aim_value as Vector3
		return (target as Node3D).global_position
	return global_position


func get_debug_data() -> Dictionary:
	var driver_data: Dictionary = active_control_driver.get_debug_data() if active_control_driver != null else {}
	var authority_data: Dictionary = authority_controller.get_debug_data() if authority_controller != null else {}
	return {
		"initialized": initialized,
		"avatar_id": avatar_definition.avatar_id if avatar_definition != null else "none",
		"avatar_name": avatar_definition.display_name if avatar_definition != null else "none",
		"owner": owner_actor.name if owner_actor != null and is_instance_valid(owner_actor) else "none",
		"owner_distance": (
			snappedf(global_position.distance_to(owner_actor.global_position), 0.1)
			if owner_actor != null and is_instance_valid(owner_actor)
			else -1.0
		),
		"health": current_health,
		"maximum_health": maximum_health,
		"defeated": defeated,
		"driver_id": str(driver_data.get("driver_id", "none")),
		"driver": driver_data,
		"target": lock_on_target.name if has_lock_on_target() else "none",
		"intent": last_intent.get_debug_data(),
		"last_action_kind": last_control_action_kind,
		"last_action_id": last_control_action_id,
		"last_action_success": last_control_action_success,
		"weapon": (
			weapon_controller.equipped_weapon.display_name
			if weapon_controller != null and weapon_controller.equipped_weapon != null
			else "none"
		),
		"attack": (
			weapon_controller.current_attack.attack_id
			if weapon_controller != null and weapon_controller.current_attack != null
			else "none"
		),
		"authority_id": str(authority_data.get("authority_id", "none")),
		"owned_fields": int(authority_data.get("owned_fields", 0)),
		"stuck_timer": snappedf(stuck_timer, 0.01),
		"recall_count": recall_count,
		"last_recall_reason": last_recall_reason,
		"combat_motion": snappedf(combat_motion_timer, 0.01),
		"wire_avatar": wire_renderer.active_avatar_id if wire_renderer != null else "none",
		"finite_pose": wire_renderer.has_finite_pose() if wire_renderer != null else false,
	}
