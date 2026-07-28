extends Node

const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")
const CombatFootworkCatalogScript = preload(
	"res://scripts/weapons/combat_footwork_catalog.gd"
)
const GraceFootworkProfile: CombatFootworkProfile = preload(
	"res://data/player/grace_combat_footwork_profile.tres"
)


func _ready() -> void:
	GameState.set_stat("max_stamina", 100)
	GameState.set_stat("stamina", 100)

	var floor: StaticBody3D = _make_floor()
	add_child(floor)
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	var footwork: PlayerCombatFootworkController = (
		player.get_node_or_null("CombatFootworkController") as PlayerCombatFootworkController
	)
	var weapon: WeaponController = player.get_node_or_null("WeaponController") as WeaponController
	var action_state: PlayerActionState = (
		player.get_node_or_null("PlayerActionState") as PlayerActionState
	)
	var visual: GraceWireMotionVisual = (
		player.get_node_or_null("GraceVisualV1") as GraceWireMotionVisual
	)
	var wire: GraceWireSkeletonRenderer = (
		player.get_node_or_null("GraceVisualV1/WireSkeletonRenderer") as GraceWireSkeletonRenderer
	)

	assert(player.is_on_floor())
	assert(footwork != null)
	assert(weapon != null)
	assert(action_state != null)
	assert(visual != null)
	assert(wire != null)
	assert(footwork.profile == GraceFootworkProfile)
	assert(footwork.is_in_group("player_combat_footwork_controller"))
	assert(GraceFootworkProfile.validate_profile().is_empty())
	for catalog_error: String in CombatFootworkCatalogScript.validate_catalog():
		assert(false, catalog_error)

	var moveset: WeaponMovesetDefinition = weapon.get_moveset()
	assert(moveset != null)
	assert(moveset.attacks.size() == 10)
	for attack_row: WeaponAttackDefinition in moveset.attacks:
		assert(attack_row != null)
		assert(attack_row.footwork_profile_id != "")
		assert(CombatFootworkCatalogScript.has_profile(attack_row.footwork_profile_id))
		assert(footwork.can_handle_attack(attack_row))

	player.set_physics_process(false)
	weapon.set_process(false)
	visual.set_process(false)
	wire.set_process(false)

	var opening_cut: WeaponAttackDefinition = moveset.get_attack("sword_l1")
	assert(opening_cut != null)
	assert(weapon.start_attack(opening_cut))
	assert(action_state.is_attacking)
	assert(footwork.is_root_motion_active())
	assert(footwork.is_visual_footwork_active())
	assert(footwork.active_profile_id == "sword_cut_right")
	assert(footwork.motion_phase == "plant")

	var plant_speed: float = CombatFootworkCatalogScript.sample_speed_multiplier(
		opening_cut.footwork_profile_id,
		0.02
	)
	var drive_speed: float = CombatFootworkCatalogScript.sample_speed_multiplier(
		opening_cut.footwork_profile_id,
		0.28
	)
	var settle_speed: float = CombatFootworkCatalogScript.sample_speed_multiplier(
		opening_cut.footwork_profile_id,
		0.96
	)
	assert(drive_speed > plant_speed)
	assert(drive_speed > settle_speed)

	var simulated_position: Vector3 = Vector3.ZERO
	var sample_count: int = 240
	var sample_delta: float = footwork.motion_duration / float(sample_count)
	for _index: int in range(sample_count):
		var before: Vector3 = simulated_position
		var sampled_velocity: Vector3 = footwork.sample_root_velocity(sample_delta)
		simulated_position += sampled_velocity * sample_delta
		footwork.record_post_move(before, simulated_position, sample_delta)

	assert(not footwork.is_root_motion_active())
	assert(absf(simulated_position.length() - opening_cut.movement_distance) < 0.04)
	assert(absf(footwork.actual_distance - opening_cut.movement_distance) < 0.04)
	assert(not footwork.blocked)
	assert(footwork.motion_phase == "settle")

	var attack_speed: float = weapon.get_attack_speed()
	var startup: float = opening_cut.get_startup_duration(attack_speed)
	var active: float = opening_cut.get_active_duration(attack_speed)
	var windup_pose: Dictionary = CombatFootworkCatalogScript.sample_attack_pose(
		opening_cut.footwork_profile_id,
		opening_cut,
		startup * 0.86,
		attack_speed
	)
	var strike_pose: Dictionary = CombatFootworkCatalogScript.sample_attack_pose(
		opening_cut.footwork_profile_id,
		opening_cut,
		startup + active * 0.82,
		attack_speed
	)
	assert(str(windup_pose.get("phase", "")) == "startup")
	assert(str(strike_pose.get("phase", "")) == "active")
	assert(
		(windup_pose.get("left_leg_rotation", Vector3.ZERO) as Vector3).distance_to(
			strike_pose.get("left_leg_rotation", Vector3.ZERO) as Vector3
		) > 0.08
	)
	assert(
		(windup_pose.get("root_position", Vector3.ZERO) as Vector3).distance_to(
			strike_pose.get("root_position", Vector3.ZERO) as Vector3
		) > 0.03
	)

	weapon.current_attack_elapsed = startup * 0.86
	visual.sample_animation_pose(1.0)
	wire.sample_now(1.0)
	var windup_left_leg: Vector3 = visual.left_leg.rotation
	var windup_right_leg: Vector3 = visual.right_leg.rotation
	weapon.current_attack_elapsed = startup + active * 0.82
	visual.sample_animation_pose(1.0)
	wire.sample_now(1.0)
	assert(visual.left_leg.rotation.distance_to(windup_left_leg) > 0.06)
	assert(visual.right_leg.rotation.distance_to(windup_right_leg) > 0.06)
	assert(wire.has_finite_pose())
	var visual_debug: Dictionary = visual.get_animation_debug_data()
	assert(str(visual_debug.get("footwork_profile_id", "")) == "sword_cut_right")
	assert(str(visual_debug.get("footwork_plant_foot", "")) == "right")
	assert(visual_debug.has("footwork_requested_distance"))
	assert(visual_debug.has("footwork_actual_distance"))

	weapon.cancel_current_attack("steering test reset")
	GameState.set_stat("stamina", 100)
	assert(weapon.start_attack(opening_cut))
	footwork.motion_elapsed = footwork.motion_duration * 0.62
	footwork.motion_progress = 0.62
	var before_steering: Vector3 = footwork.motion_direction
	footwork.apply_debug_steering(Vector3.RIGHT, 0.12)
	assert(footwork.motion_direction.x > before_steering.x)
	assert(footwork.steering_angle_degrees > 0.0)
	assert(footwork.steering_angle_degrees <= GraceFootworkProfile.maximum_steering_degrees + 0.1)

	weapon.cancel_current_attack("blocking test reset")
	GameState.set_stat("stamina", 100)
	assert(weapon.start_attack(opening_cut))
	var blocked_delta: float = footwork.motion_duration / 24.0
	for _blocked_frame: int in range(GraceFootworkProfile.blocked_frames_to_stop):
		footwork.sample_root_velocity(blocked_delta)
		footwork.record_post_move(Vector3.ZERO, Vector3.ZERO, blocked_delta)
	assert(footwork.blocked)
	assert(not footwork.is_root_motion_active())
	assert(footwork.is_visual_footwork_active())

	var controller_debug: Dictionary = player.call("get_combat_motion_debug_data") as Dictionary
	assert(controller_debug.has("combat_footwork"))
	var footwork_debug: Dictionary = controller_debug.get("combat_footwork", {}) as Dictionary
	for key: String in [
		"profile_id",
		"phase",
		"progress",
		"requested_distance",
		"actual_distance",
		"blocked",
		"plant_foot",
	]:
		assert(footwork_debug.has(key))

	weapon.cancel_current_attack("combat footwork smoke test complete")
	assert(not footwork.is_visual_footwork_active())
	assert(not action_state.is_attacking)

	print("COMBAT_FOOTWORK_SMOKE_TEST: PASS")
	get_tree().quit(0)


func _make_floor() -> StaticBody3D:
	var floor: StaticBody3D = StaticBody3D.new()
	floor.name = "FootworkFloor"
	floor.position = Vector3(0.0, -0.1, 0.0)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(12.0, 0.2, 12.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor
